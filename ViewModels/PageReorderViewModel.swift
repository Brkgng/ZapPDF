//
//  PageReorderViewModel.swift
//  ZapPDF
//
//  ViewModel managing page reorder state with undo/redo support.
//

import Foundation
import SwiftUI
import PDFKit
import Combine

/// ViewModel managing page editing state and operations.
///
/// `PageReorderViewModel` coordinates page loading, reordering, rotation,
/// deletion, undo/redo, and saving. It tracks changes and provides
/// state for enabling/disabling UI elements.
///
/// Example:
/// ```swift
/// @StateObject private var viewModel = PageReorderViewModel(file: selectedPDF)
///
/// // Load pages when view appears
/// await viewModel.loadPages()
///
/// // User rotates and reorders pages
/// viewModel.rotateSelectedPageClockwise()
/// viewModel.movePages(from: IndexSet(integer: 0), to: 3)
///
/// // Save edited PDF
/// try await viewModel.save(to: destinationURL)
/// ```
@MainActor
final class PageReorderViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Pages in their current order (may differ from original).
    @Published private(set) var pages: [PageItem] = []
    
    /// Currently selected page index (for preview).
    @Published var selectedPageIndex: Int?
    
    /// Loading state for initial page load.
    @Published private(set) var isLoadingPages: Bool = false
    
    /// Saving state for export operation.
    @Published private(set) var isSaving: Bool = false
    
    /// Save progress (0.0 to 1.0).
    @Published private(set) var saveProgress: Double = 0.0
    
    /// Save status text shown in the overlay.
    @Published private(set) var saveStatusMessage: String = L10n.PageReorder.savingProgress(0.0)
    
    /// Error message if any.
    @Published var errorMessage: String?
    
    // MARK: - Source Data
    
    /// The source PDF file being reordered.
    let sourceFile: PDFFile
    
    // MARK: - Private Properties
    
    /// Undo stack containing previous page states.
    private var undoStack: [[PageItem]] = []
    
    /// Redo stack containing states that can be redone.
    private var redoStack: [[PageItem]] = []
    
    /// Maximum number of undo states to keep.
    private let maxUndoLevels = 50
    
    /// The reorderer service.
    private let reorderer = PDFReorderer()
    
    /// The usage manager for tracking free tier usage.
    private let usageManager: any UsageManaging
    
    /// Current save task for cancellation.
    private var saveTask: Task<URL, Error>?
    
    // MARK: - Initialization
    
    /// Creates a PageReorderViewModel for the given PDF file.
    ///
    /// - Parameter file: The PDF file to reorder
    init(file: PDFFile) {
        self.sourceFile = file
        self.usageManager = UsageManager.shared
    }
    
    /// Creates a PageReorderViewModel with custom dependencies (for testing).
    ///
    /// - Parameters:
    ///   - file: The PDF file to reorder
    ///   - usageManager: Custom usage manager for testing
    init(file: PDFFile, usageManager: any UsageManaging) {
        self.sourceFile = file
        self.usageManager = usageManager
    }
    
    // MARK: - Computed Properties
    
    /// Whether changes have been made from the original order.
    var hasChanges: Bool {
        pages.hasChanges
    }
    
    /// Whether undo is available.
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    /// Whether redo is available.
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    /// Total number of pages.
    var pageCount: Int {
        pages.count
    }
    
    /// The currently selected page, if any.
    var selectedPage: PageItem? {
        guard let index = selectedPageIndex, index >= 0, index < pages.count else {
            return nil
        }
        return pages[index]
    }
    
    /// Whether the selected page can be deleted.
    /// Requires a selection and more than 1 page.
    var canDeleteSelectedPage: Bool {
        selectedPageIndex != nil && pages.count > 1
    }
    
    /// Whether rotation actions are available.
    /// Requires a page to be selected.
    var canRotateSelectedPage: Bool {
        selectedPageIndex != nil
    }
    
    // MARK: - Public Methods
    
    /// Load pages from the source PDF.
    ///
    /// This creates PageItem instances for each page in the PDF.
    /// Thumbnails are loaded lazily by the UI components.
    func loadPages() async {
        guard pages.isEmpty else { return }
        
        isLoadingPages = true
        errorMessage = nil
        
        do {
            // Access file with security scope to verify it's readable
            try await sourceFile.url.withSecurityScopeAsync {
                guard let document = PDFDocument(url: self.sourceFile.url) else {
                    throw PDFFileError.invalidPDF(self.sourceFile.url)
                }
                
                if document.isLocked {
                    throw PDFFileError.passwordProtected(self.sourceFile.url)
                }
            }
            
            // Create page items
            pages = [PageItem].create(pageCount: sourceFile.pageCount)
            
            // Clear undo/redo stacks
            undoStack.removeAll()
            redoStack.removeAll()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingPages = false
    }
    
    /// Move pages from source indices to destination index.
    ///
    /// This method supports SwiftUI's `onMove` modifier pattern.
    ///
    /// - Parameters:
    ///   - source: Set of indices to move
    ///   - destination: Target index to move to
    func movePages(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else { return }
        
        // Save current state for undo
        pushUndoState()
        
        // Clear redo stack on new action
        redoStack.removeAll()
        
        // Perform the move
        pages.move(fromOffsets: source, toOffset: destination)
        
        // Update selection if needed
        if let selectedIndex = selectedPageIndex {
            // Recalculate selection after move
            if source.contains(selectedIndex) {
                // The selected item was moved
                var newIndex = destination
                let offset = source.filter { $0 < destination }.count
                newIndex -= offset
                if let firstSource = source.first {
                    if firstSource < destination {
                        // Find position of selected in source array
                        let sortedSource = source.sorted()
                        if let posInSource = sortedSource.firstIndex(of: selectedIndex) {
                            newIndex += posInSource
                        }
                    } else {
                        let sortedSource = source.sorted()
                        if let posInSource = sortedSource.firstIndex(of: selectedIndex) {
                            newIndex = destination + posInSource
                        }
                    }
                }
                selectedPageIndex = min(max(0, newIndex), pages.count - 1)
            }
        }
    }
    

    
    /// Delete page at the specified index.
    ///
    /// - Parameter index: Index of the page to delete
    /// - Note: Cannot delete the last remaining page
    func deletePage(at index: Int) {
        guard pages.count > 1 else {
            errorMessage = L10n.PageReorder.cannotDeleteLastPage
            return
        }
        guard index >= 0 && index < pages.count else { return }
        
        // Save current state for undo
        pushUndoState()
        
        // Clear redo stack on new action
        redoStack.removeAll()
        
        // Remove the page
        pages.remove(at: index)
        
        // Adjust selection
        if let selected = selectedPageIndex {
            if selected == index {
                // Select previous page, or first if deleted was first
                selectedPageIndex = max(0, selected - 1)
            } else if selected > index {
                // Selection was after deleted page, shift down
                selectedPageIndex = selected - 1
            }
        }
    }
    
    /// Delete the currently selected page.
    func deleteSelectedPage() {
        guard let index = selectedPageIndex else { return }
        deletePage(at: index)
    }
    
    // MARK: - Rotation Methods
    
    /// Rotate the selected page 90° clockwise.
    func rotateSelectedPageClockwise() {
        guard let index = selectedPageIndex else { return }
        rotatePage(at: index, clockwise: true)
    }
    
    /// Rotate the selected page 90° counter-clockwise.
    func rotateSelectedPageCounterClockwise() {
        guard let index = selectedPageIndex else { return }
        rotatePage(at: index, clockwise: false)
    }
    
    /// Rotate page at the specified index.
    ///
    /// - Parameters:
    ///   - index: Index of the page to rotate
    ///   - clockwise: If true, rotate 90° clockwise; otherwise counter-clockwise
    func rotatePage(at index: Int, clockwise: Bool) {
        guard index >= 0 && index < pages.count else { return }
        
        // Save current state for undo
        pushUndoState()
        
        // Clear redo stack on new action
        redoStack.removeAll()
        
        // Apply rotation
        if clockwise {
            pages[index].rotation.rotateClockwise()
        } else {
            pages[index].rotation.rotateCounterClockwise()
        }
    }
    
    /// Undo the last reorder action.
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        
        // Save current state to redo
        redoStack.append(pages)
        
        // Restore previous state
        pages = previousState
    }
    
    /// Redo the last undone action.
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        
        // Save current state to undo
        undoStack.append(pages)
        
        // Restore next state
        pages = nextState
    }
    
    /// Save the reordered PDF to the specified destination.
    ///
    /// - Parameter destinationURL: Where to save the reordered PDF
    /// - Returns: URL to the saved PDF
    /// - Throws: Error if save fails
    @discardableResult
    func save(to destinationURL: URL) async throws -> URL {
        guard hasChanges else {
            throw PageReorderError.noChanges
        }
        
        isSaving = true
        updateSaveProgress(0.0)
        errorMessage = nil
        
        do {
            // Get the new order and rotations
            let newOrder = pages.reorderedIndices
            let rotations = pages.rotationsMap
            
            // Generate output filename from destination
            let outputFileName = destinationURL.deletingPathExtension().lastPathComponent
            
            // Process the PDF (reorder and/or rotate)
            let tempURL = try await reorderer.reorder(
                file: sourceFile,
                newOrder: newOrder,
                rotations: rotations,
                outputFileName: outputFileName,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateSaveProgress(progress)
                    }
                }
            )
            
            // Move to destination
            let fileManager = FileManager.default
            
            // Remove existing file at destination if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            
            // Record usage
            try await usageManager.recordAction()
            
            updateSaveProgress(1.0)
            isSaving = false
            
            return destinationURL
            
        } catch {
            isSaving = false
            updateSaveProgress(0.0)
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Save the reordered PDF to a temporary location.
    ///
    /// Use this for iOS share sheet where the final destination is unknown.
    ///
    /// - Returns: URL to the temporary reordered PDF
    /// - Throws: Error if save fails
    func saveToTemporary() async throws -> URL {
        guard hasChanges else {
            throw PageReorderError.noChanges
        }
        
        isSaving = true
        updateSaveProgress(0.0)
        errorMessage = nil
        
        do {
            let newOrder = pages.reorderedIndices
            let rotations = pages.rotationsMap
            
            let tempURL = try await reorderer.reorder(
                file: sourceFile,
                newOrder: newOrder,
                rotations: rotations,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateSaveProgress(progress)
                    }
                }
            )
            
            // Record usage
            try await usageManager.recordAction()
            
            updateSaveProgress(1.0)
            isSaving = false
            
            return tempURL
            
        } catch {
            isSaving = false
            updateSaveProgress(0.0)
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Cancel any ongoing save operation.
    func cancel() {
        saveTask?.cancel()
        saveTask = nil
        Task {
            await reorderer.cancel()
        }
        isSaving = false
        updateSaveProgress(0.0)
    }
    
    // MARK: - Private Methods
    
    func updateSaveProgress(_ progress: Double) {
        saveProgress = progress
        
        if PDFProgressPolicy.isFinalizing(progress) {
            saveStatusMessage = L10n.PageReorder.finalizing
        } else {
            saveStatusMessage = L10n.PageReorder.savingProgress(progress)
        }
    }
    
    /// Push current state to undo stack.
    private func pushUndoState() {
        undoStack.append(pages)
        
        // Limit undo history
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }
}

// MARK: - PageReorder Errors

/// Errors specific to page reordering.
enum PageReorderError: Error, LocalizedError {
    case noChanges
    case invalidPageOrder
    case saveFailed(URL)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noChanges:
            return L10n.PageReorder.noChangesToSave
        case .invalidPageOrder:
            return L10n.PageReorder.invalidPageOrder
        case .saveFailed(let url):
            return L10n.PageReorder.saveFailedTo(url.lastPathComponent)
        case .cancelled:
            return L10n.Error.cancelled
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noChanges:
            return L10n.Error.reorderSomePages
        case .invalidPageOrder:
            return L10n.Error.tryReorderingAgain
        case .saveFailed:
            return L10n.Error.trySavingElsewhere
        case .cancelled:
            return nil
        }
    }
}
