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
    private let monetizationStateProvider: () -> MonetizationAvailability.State
    
    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    #if os(iOS)
    /// Delayed cleanup tasks for internally generated scan files (undo support).
    private var pendingScannedFileCleanupTasks: [UUID: Task<Void, Never>] = [:]
    private let scannedFileCleanupDelay: Duration
    #endif
    
    // MARK: - Initialization
    
    /// Creates a DashboardViewModel with the default UsageManager.
    init() {
        self.usageManager = UsageManager.shared
        self.monetizationStateProvider = { MonetizationAvailability.state }
        #if os(iOS)
        self.scannedFileCleanupDelay = .seconds(6)
        #endif
        setupNotificationObserver()
    }
    
    /// Creates a DashboardViewModel with a custom UsageManager (for testing).
    init(
        usageManager: any UsageManaging,
        monetizationStateProvider: (() -> MonetizationAvailability.State)? = nil
    ) {
        self.usageManager = usageManager
        self.monetizationStateProvider = monetizationStateProvider ?? { MonetizationAvailability.state }
        #if os(iOS)
        self.scannedFileCleanupDelay = .seconds(6)
        #endif
        setupNotificationObserver()
    }

    #if os(iOS)
    /// Creates a DashboardViewModel with custom scan cleanup delay (for iOS tests).
    init(
        usageManager: any UsageManaging,
        scannedFileCleanupDelay: Duration,
        monetizationStateProvider: (() -> MonetizationAvailability.State)? = nil
    ) {
        self.usageManager = usageManager
        self.monetizationStateProvider = monetizationStateProvider ?? { MonetizationAvailability.state }
        self.scannedFileCleanupDelay = scannedFileCleanupDelay
        setupNotificationObserver()
    }
    #endif
    
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
    /// Note: Files are auto-selected only when adding exactly 1 file to an empty dashboard.
    /// In all other cases, files are not selected by default.
    ///
    /// - Parameters:
    ///   - urls: Array of file URLs to add
    ///   - origin: Origin category for lifecycle policy decisions
    func addFiles(urls: [URL], origin: PDFFileOrigin = .external) async {
        guard !urls.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Track if dashboard was empty to determine auto-selection
        let wasEmpty = files.isEmpty
        
        var addedFiles: [PDFFile] = []
        var errorURLs: [URL] = []
        
        for url in urls {
            do {
                let pdfFile = try await PDFFile(url: url, origin: origin)
                addedFiles.append(pdfFile)
            } catch {
                errorURLs.append(url)
                // Continue with other files
            }
        }
        
        // Add successfully loaded files
        files.append(contentsOf: addedFiles)
        
        // Auto-select ONLY when adding exactly 1 file to an empty dashboard
        if wasEmpty && addedFiles.count == 1, let firstFile = addedFiles.first {
            selectedFileIDs.insert(firstFile.id)
        }
        
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
        let removedFile = files.first { $0.id == file.id }

        files.removeAll { $0.id == file.id }
        // Also remove from selection if selected
        selectedFileIDs.remove(file.id)

        if let removedFile {
            cancelPendingScannedFileCleanup(for: removedFile)
            cleanupScannedFileIfNeeded(removedFile)
        }
    }
    
    /// Remove files at specified indices.
    ///
    /// - Parameter indexSet: Indices of files to remove
    func removeFiles(at indexSet: IndexSet) {
        let removedFiles = indexSet.map { files[$0] }

        // Remove from selection first
        let removedIDs = indexSet.map { files[$0].id }
        removedIDs.forEach { selectedFileIDs.remove($0) }
        // Then remove from files
        files.remove(atOffsets: indexSet)

        for file in removedFiles {
            cancelPendingScannedFileCleanup(for: file)
            cleanupScannedFileIfNeeded(file)
        }
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

        scheduleDeferredScannedFileCleanup(for: previousFiles)
        
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
        for file in restoredFiles {
            cancelPendingScannedFileCleanup(for: file)
        }

        files = restoredFiles
        selectedFileIDs = restoredSelection
    }

    #if os(iOS)
    private func cleanupScannedFileIfNeeded(_ file: PDFFile) {
        guard file.origin == .internalScan else { return }
        _ = DocumentScanner.cleanupScannedFile(at: file.url)
    }

    private func scheduleDeferredScannedFileCleanup(for files: [PDFFile]) {
        let cleanupDelay = scannedFileCleanupDelay

        for file in files where file.origin == .internalScan {
            pendingScannedFileCleanupTasks[file.id]?.cancel()

            pendingScannedFileCleanupTasks[file.id] = Task { [weak self] in
                try? await Task.sleep(for: cleanupDelay)
                guard !Task.isCancelled else { return }

                _ = DocumentScanner.cleanupScannedFile(at: file.url)
                self?.pendingScannedFileCleanupTasks[file.id] = nil
            }
        }
    }

    private func cancelPendingScannedFileCleanup(for file: PDFFile) {
        pendingScannedFileCleanupTasks[file.id]?.cancel()
        pendingScannedFileCleanupTasks[file.id] = nil
    }
    #else
    private func cleanupScannedFileIfNeeded(_ file: PDFFile) {}
    private func scheduleDeferredScannedFileCleanup(for files: [PDFFile]) {}
    private func cancelPendingScannedFileCleanup(for file: PDFFile) {}
    #endif
    
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

    /// Compute a pure, I/O-free preflight estimate for a merge.
    ///
    /// Uses the already-known `pageCount`/`fileSize` metadata on the candidate
    /// files so the UI can warn about unusually large merges before opening the
    /// processing view. The engine re-checks the hard cap against actual file
    /// I/O, so this is an estimate for UX, not the safety net.
    ///
    /// - Returns: A `MergePreflightSummary`, or `nil` if no merge files are selected.
    func mergePreflightSummary() -> MergePreflightSummary? {
        let mergeFiles = filesForAction(.merge)
        guard !mergeFiles.isEmpty else { return nil }

        return MergePreflightSummary.evaluate(
            totalPages: mergeFiles.totalPageCount,
            totalBytes: mergeFiles.totalFileSize
        )
    }


    /// Check if the user should see the paywall before performing an action.
    ///
    /// - Returns: true if paywall should be shown (no free actions remaining)
    func shouldShowPaywall() async -> Bool {
        let canPerform = await usageManager.canPerformAction()
        return !canPerform
    }

    /// Handles manual upgrade taps from the toolbar/badge.
    func handleUpgradeTap() {
        _ = presentPaywallOrSetUnavailableError()
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
            _ = presentPaywallOrSetUnavailableError()
            return false
        }
        
        return true
    }

    @discardableResult
    private func presentPaywallOrSetUnavailableError() -> Bool {
        switch monetizationStateProvider() {
        case .enabled:
            showPaywall = true
            return true
        case .disabled(let message):
            errorMessage = message
            return false
        }
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
