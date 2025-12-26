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
    
    /// Currently selected PDF files.
    @Published private(set) var selectedFiles: [PDFFile] = []
    
    /// Whether files are currently being loaded.
    @Published private(set) var isLoading: Bool = false
    
    /// User-facing error message, if any.
    @Published var errorMessage: String?
    
    /// Whether to show the paywall.
    @Published var showPaywall: Bool = false
    
    // MARK: - Dependencies
    
    private let usageManager: any UsageManaging
    
    // MARK: - Initialization
    
    /// Creates a DashboardViewModel with the default UsageManager.
    init() {
        self.usageManager = UsageManager.shared
    }
    
    /// Creates a DashboardViewModel with a custom UsageManager (for testing).
    init(usageManager: any UsageManaging) {
        self.usageManager = usageManager
    }
    
    // MARK: - File Management
    
    /// Add PDF files from URLs.
    ///
    /// This method loads metadata from each URL and creates PDFFile instances.
    /// Invalid URLs or non-PDF files will set an error message.
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
        
        // Add successfully loaded files
        selectedFiles.append(contentsOf: addedFiles)
        
        // Set error message if any files failed
        if !errorURLs.isEmpty {
            let names = errorURLs.map { $0.lastPathComponent }.joined(separator: ", ")
            if errorURLs.count == 1 {
                errorMessage = "Could not load '\(names)'. Please select a valid PDF file."
            } else {
                errorMessage = "Could not load \(errorURLs.count) files: \(names)"
            }
        }
        
        isLoading = false
    }
    
    /// Remove a file from the selection.
    ///
    /// - Parameter file: The PDFFile to remove
    func removeFile(_ file: PDFFile) {
        selectedFiles.removeAll { $0.id == file.id }
    }
    
    /// Remove files at specified indices.
    ///
    /// - Parameter indexSet: Indices of files to remove
    func removeFiles(at indexSet: IndexSet) {
        selectedFiles.remove(atOffsets: indexSet)
    }
    
    /// Reorder files (for drag and drop in merge operations).
    ///
    /// - Parameters:
    ///   - source: Source indices
    ///   - destination: Destination index
    func reorderFiles(from source: IndexSet, to destination: Int) {
        selectedFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Clear all selected files.
    func clearAll() {
        selectedFiles.removeAll()
        errorMessage = nil
    }
    
    // MARK: - Action Validation
    
    /// Check if an action can be performed with current file selection.
    ///
    /// - Parameter action: The action to validate
    /// - Returns: true if the action can be performed
    func canPerform(action: UserAction) -> Bool {
        action.isValidFileCount(selectedFiles.count)
    }
    
    /// Get the validation error message for an action.
    ///
    /// - Parameter action: The action to check
    /// - Returns: Error message if validation fails, nil otherwise
    func validationError(for action: UserAction) -> String? {
        action.fileCountError(for: selectedFiles.count)
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
    
    // MARK: - Computed Properties
    
    /// Whether any files are selected.
    var hasFiles: Bool {
        !selectedFiles.isEmpty
    }
    
    /// Total page count across all selected files.
    var totalPageCount: Int {
        selectedFiles.totalPageCount
    }
    
    /// Total file size across all selected files.
    var totalFileSize: Int64 {
        selectedFiles.totalFileSize
    }
    
    /// Formatted total file size.
    var formattedTotalSize: String {
        selectedFiles.formattedTotalSize
    }
}
