//
//  DashboardViewModel.swift
//  ZapPDF
//
//  ViewModel managing file selection state for the dashboard UI.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Usage Managing Protocol

/// Protocol for UsageManager dependency injection (testability).
protocol UsageManaging: Actor {
    func canPerformAction() async -> Bool
    func remainingActions() async -> Int
    func recordAction() async throws
    func getProStatus() async -> Bool
    func setProStatus(_ isPro: Bool) async
}

extension UsageManager: UsageManaging {}

// MARK: - DashboardViewModel

/// ViewModel managing file selection state for the dashboard.
///
/// `DashboardViewModel` coordinates file selection, validation, and
/// action triggering. It runs on the MainActor for UI state updates.
///
/// Example:
/// ```swift
/// @StateObject private var viewModel = DashboardViewModel()
///
/// // Add files from file picker
/// await viewModel.addFiles(urls: selectedURLs)
///
/// // Check if merge is available
/// if viewModel.canPerform(action: .merge) {
///     // Navigate to processing
/// }
/// ```
@MainActor
final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// All PDF files added to the dashboard.
    @Published private(set) var files: [PDFFile] = []
    
    /// IDs of currently selected files for operations.
    /// Files are not selected by default when added.
    @Published private(set) var selectedFileIDs: Set<UUID> = []
    
    /// Whether files are currently being loaded.
    @Published private(set) var isLoading: Bool = false
    
    /// User-facing error message, if any.
    @Published var errorMessage: String?
    
    /// Whether to show the paywall.
    @Published var showPaywall: Bool = false
    
    // MARK: - Subscription State
    
    /// Whether the user has an active Pro subscription.
    @Published private(set) var isPro: Bool = false
    
    /// Number of free actions remaining.
    @Published private(set) var remainingFreeActions: Int = 5
    
    /// The free action limit (for display purposes).
    let freeActionLimit: Int = 5
    
    // MARK: - Dependencies
    
    private let usageManager: any UsageManaging
    
    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a DashboardViewModel with the default UsageManager.
    init() {
        self.usageManager = UsageManager.shared
        setupNotificationObserver()
    }
    
    /// Creates a DashboardViewModel with a custom UsageManager (for testing).
    init(usageManager: any UsageManaging) {
        self.usageManager = usageManager
        setupNotificationObserver()
    }
    
    // MARK: - Private Setup
    
    /// Subscribe to usage state change notifications.
    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: .usageStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadSubscriptionState()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - File Management
    
    /// Add PDF files from URLs.
    ///
    /// This method loads metadata from each URL and creates PDFFile instances.
    /// Invalid URLs or non-PDF files will set an error message.
    /// Note: Newly added files are NOT selected by default (Option B).
    ///
    /// - Parameter urls: Array of file URLs to add
    func addFiles(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        var addedFiles: [PDFFile] = []
        var errorURLs: [URL] = []
        
        for url in urls {
            do {
                let pdfFile = try await PDFFile(url: url)
                addedFiles.append(pdfFile)
            } catch {
                errorURLs.append(url)
                // Continue with other files
            }
        }
        
        // Add successfully loaded files (not selected by default)
        files.append(contentsOf: addedFiles)
        
        // Set error message if any files failed
        if !errorURLs.isEmpty {
            let names = errorURLs.map { $0.lastPathComponent }.joined(separator: ", ")
            if errorURLs.count == 1 {
                errorMessage = L10n.Dashboard.couldNotLoadFile(names)
            } else {
                errorMessage = L10n.Dashboard.couldNotLoadFiles(errorURLs.count, names)
            }
        }
        
        isLoading = false
    }
    
    /// Remove a file from the list.
    ///
    /// - Parameter file: The PDFFile to remove
    func removeFile(_ file: PDFFile) {
        files.removeAll { $0.id == file.id }
        // Also remove from selection if selected
        selectedFileIDs.remove(file.id)
    }
    
    /// Remove files at specified indices.
    ///
    /// - Parameter indexSet: Indices of files to remove
    func removeFiles(at indexSet: IndexSet) {
        // Remove from selection first
        let removedIDs = indexSet.map { files[$0].id }
        removedIDs.forEach { selectedFileIDs.remove($0) }
        // Then remove from files
        files.remove(atOffsets: indexSet)
    }
    
    /// Reorder files (for drag and drop in merge operations).
    ///
    /// - Parameters:
    ///   - source: Source indices
    ///   - destination: Destination index
    func reorderFiles(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Clear all files with undo support.
    ///
    /// This clears all files and selection, while posting a notification
    /// that can be used by the UI to offer an undo option.
    func clearAll() {
        // Store previous state for undo
        let previousFiles = files
        let previousSelection = selectedFileIDs
        
        // Clear everything
        files.removeAll()
        selectedFileIDs.removeAll()
        errorMessage = nil
        
        // Post notification with undo data
        NotificationCenter.default.post(
            name: .filesCleared,
            object: nil,
            userInfo: [
                "previousFiles": previousFiles,
                "previousSelection": previousSelection
            ]
        )
    }
    
    /// Restore files after a clearAll (for undo functionality).
    ///
    /// - Parameters:
    ///   - restoredFiles: The files to restore
    ///   - restoredSelection: The selection state to restore
    func restoreFiles(_ restoredFiles: [PDFFile], selection restoredSelection: Set<UUID>) {
        files = restoredFiles
        selectedFileIDs = restoredSelection
    }
    
    // MARK: - Selection Management
    
    /// Toggle selection state of a file.
    ///
    /// - Parameter file: The file to toggle selection for
    func toggleSelection(for file: PDFFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }
    
    /// Select a file.
    ///
    /// - Parameter file: The file to select
    func selectFile(_ file: PDFFile) {
        selectedFileIDs.insert(file.id)
    }
    
    /// Deselect a file.
    ///
    /// - Parameter file: The file to deselect
    func deselectFile(_ file: PDFFile) {
        selectedFileIDs.remove(file.id)
    }
    
    /// Select all files.
    func selectAll() {
        selectedFileIDs = Set(files.map(\.id))
    }
    
    /// Deselect all files.
    func deselectAll() {
        selectedFileIDs.removeAll()
    }
    
    /// Check if a file is selected.
    ///
    /// - Parameter file: The file to check
    /// - Returns: true if the file is selected
    func isSelected(_ file: PDFFile) -> Bool {
        selectedFileIDs.contains(file.id)
    }
    
    // MARK: - Action Validation
    
    /// Get files to use for the given action.
    ///
    /// For merge: uses selected files, or all files if none selected (backward compatibility).
    /// For other actions: uses selected files only.
    ///
    /// - Parameter action: The action to get files for
    /// - Returns: Array of files to use for the action
    func filesForAction(_ action: UserAction) -> [PDFFile] {
        if action == .merge && selectedFileIDs.isEmpty {
            return files  // Fall back to all files for merge
        }
        return selectedFiles
    }
    
    /// Check if an action can be performed with current file selection.
    ///
    /// - Parameter action: The action to validate
    /// - Returns: true if the action can be performed
    func canPerform(action: UserAction) -> Bool {
        let actionFiles = filesForAction(action)
        return action.isValidFileCount(actionFiles.count)
    }
    
    /// Get the validation error message for an action.
    ///
    /// - Parameter action: The action to check
    /// - Returns: Error message if validation fails, nil otherwise
    func validationError(for action: UserAction) -> String? {
        let actionFiles = filesForAction(action)
        return action.fileCountError(for: actionFiles.count)
    }
    
    /// Check if the user should see the paywall before performing an action.
    ///
    /// - Returns: true if paywall should be shown (no free actions remaining)
    func shouldShowPaywall() async -> Bool {
        let canPerform = await usageManager.canPerformAction()
        return !canPerform
    }
    
    /// Prepare to execute an action, checking usage limits first.
    ///
    /// - Parameter action: The action to prepare
    /// - Returns: true if the action can proceed, false if paywall is needed
    func prepareAction(_ action: UserAction) async -> Bool {
        guard canPerform(action: action) else {
            errorMessage = validationError(for: action)
            return false
        }
        
        if await shouldShowPaywall() {
            showPaywall = true
            return false
        }
        
        return true
    }
    
    // MARK: - Subscription Methods
    
    /// Load the current subscription and usage state.
    ///
    /// This should be called when the Dashboard appears.
    func loadSubscriptionState() async {
        isPro = await usageManager.getProStatus()
        remainingFreeActions = await usageManager.remainingActions()
    }
    
    /// Refresh usage state after an action is recorded.
    ///
    /// Call this after a successful PDF operation to update the UI.
    func refreshUsageState() async {
        remainingFreeActions = await usageManager.remainingActions()
    }
    
    // MARK: - Computed Properties
    
    /// Files that are currently selected.
    var selectedFiles: [PDFFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }
    
    /// Number of selected files.
    var selectedCount: Int {
        selectedFileIDs.count
    }
    
    /// Whether all files are selected.
    var allSelected: Bool {
        selectedFileIDs.count == files.count && !files.isEmpty
    }
    
    /// Whether no files are selected.
    var noneSelected: Bool {
        selectedFileIDs.isEmpty
    }
    
    /// Whether any files are added.
    var hasFiles: Bool {
        !files.isEmpty
    }
    
    /// Total page count across all files.
    var totalPageCount: Int {
        files.totalPageCount
    }
    
    /// Total file size across all files.
    var totalFileSize: Int64 {
        files.totalFileSize
    }
    
    /// Formatted total file size.
    var formattedTotalSize: String {
        files.formattedTotalSize
    }
}
