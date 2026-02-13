//
//  ProcessingViewModel.swift
//  ZapPDF
//
//  ViewModel managing PDF operation execution with progress tracking.
//

import Foundation
import Combine

// MARK: - Processing Options

/// Options for PDF processing operations.
struct ProcessingOptions: Sendable {
    /// Options for merge operations.
    var mergeOptions: PDFMerger.MergeOptions?
    
    /// Split mode for split operations.
    var splitMode: PDFSplitter.SplitMode?
    
    /// Options for flatten operations.
    var flattenOptions: PDFFlattener.FlattenOptions?
    
    /// Creates default processing options.
    init(
        mergeOptions: PDFMerger.MergeOptions? = nil,
        splitMode: PDFSplitter.SplitMode? = nil,
        flattenOptions: PDFFlattener.FlattenOptions? = nil
    ) {
        self.mergeOptions = mergeOptions
        self.splitMode = splitMode
        self.flattenOptions = flattenOptions
    }
    
    /// Creates options for a merge operation.
    static func merge(outputFileName: String = "merged") -> ProcessingOptions {
        ProcessingOptions(mergeOptions: .init(outputFileName: outputFileName))
    }
    
    /// Creates options for a split operation.
    static func split(mode: PDFSplitter.SplitMode) -> ProcessingOptions {
        ProcessingOptions(splitMode: mode)
    }
    
    /// Creates options for a flatten operation.
    static func flatten(outputFileName: String = "flattened") -> ProcessingOptions {
        ProcessingOptions(flattenOptions: .init(outputFileName: outputFileName))
    }
}

// MARK: - Processing State

/// State machine for PDF processing operations.
enum ProcessingState: Equatable {
    /// No operation in progress.
    case idle
    
    /// Operation in progress with current progress and message.
    case processing(progress: Double, message: String)
    
    /// Operation completed successfully with result URLs.
    case completed(resultURLs: [URL])
    
    /// Operation failed with error message.
    case failed(message: String)
    
    /// Operation was cancelled by user.
    case cancelled
    
    // MARK: - Equatable
    
    static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.processing(let p1, let m1), .processing(let p2, let m2)):
            return p1 == p2 && m1 == m2
        case (.completed(let u1), .completed(let u2)):
            return u1 == u2
        case (.failed(let m1), .failed(let m2)):
            return m1 == m2
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

// MARK: - ProcessingViewModel

/// ViewModel managing PDF operation execution with progress tracking.
///
/// `ProcessingViewModel` executes PDF operations (merge, split) and
/// reports progress through a state machine. It supports cancellation
/// and records successful actions for usage tracking.
///
/// Example:
/// ```swift
/// @StateObject private var viewModel = ProcessingViewModel()
///
/// await viewModel.execute(
///     action: .merge,
///     files: selectedFiles,
///     options: .merge(outputFileName: "combined")
/// )
///
/// switch viewModel.state {
/// case .completed(let urls):
///     // Show save dialog
/// case .failed(let message):
///     // Show error
/// }
/// ```
@MainActor
final class ProcessingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Current processing state.
    @Published private(set) var state: ProcessingState = .idle
    
    // MARK: - Private Properties
    
    private var processingTask: Task<Void, Never>?
    private let merger: PDFMerger
    private let splitter: PDFSplitter
    private let flattener: PDFFlattener
    private let usageManager: any UsageManaging
    
    /// Last time progress was updated (for throttling)
    private var lastProgressUpdate: Date = .distantPast
    
    /// Minimum interval between progress updates (50ms = ~20 updates/second)
    private let progressThrottleInterval: TimeInterval = 0.05
    
    // MARK: - Initialization
    
    /// Creates a ProcessingViewModel with default services.
    init() {
        self.merger = PDFMerger()
        self.splitter = PDFSplitter()
        self.flattener = PDFFlattener()
        self.usageManager = UsageManager.shared
    }
    
    /// Creates a ProcessingViewModel with custom services (for testing).
    init(
        merger: PDFMerger = PDFMerger(),
        splitter: PDFSplitter = PDFSplitter(),
        flattener: PDFFlattener = PDFFlattener(),
        usageManager: any UsageManaging
    ) {
        self.merger = merger
        self.splitter = splitter
        self.flattener = flattener
        self.usageManager = usageManager
    }
    
    // MARK: - Public Methods
    
    /// Execute a PDF operation.
    ///
    /// This method runs the operation asynchronously, reports progress,
    /// and transitions through states appropriately.
    ///
    /// - Parameters:
    ///   - action: The action to perform
    ///   - files: PDF files to process
    ///   - options: Operation-specific options
    func execute(
        action: UserAction,
        files: [PDFFile],
        options: ProcessingOptions
    ) async {
        // Cancel any existing operation
        processingTask?.cancel()
        
        // Reset throttle timer for new operation
        lastProgressUpdate = .distantPast
        
        // Reset state
        state = .processing(progress: 0.0, message: progressMessage(for: action))
        
        processingTask = Task {
            do {
                let resultURLs = try await performAction(action, files: files, options: options)
                
                // Check if cancelled during operation
                if Task.isCancelled {
                    state = .cancelled
                    return
                }
                
                // Record action for usage tracking
                try await usageManager.recordAction()
                
                if Task.isCancelled {
                    state = .cancelled
                    return
                }
                
                state = .completed(resultURLs: resultURLs)
                
            } catch is CancellationError {
                state = .cancelled
            } catch PDFEngineError.cancelled {
                state = .cancelled
            } catch {
                state = .failed(message: errorMessage(for: error))
            }
        }
        
        await processingTask?.value
    }
    
    /// Cancel the current operation.
    func cancel() {
        processingTask?.cancel()
        Task {
            await merger.cancel()
            await splitter.cancel()
            await flattener.cancel()
        }
        state = .cancelled
    }
    
    /// Reset to idle state.
    func reset() {
        processingTask?.cancel()
        processingTask = nil
        state = .idle
    }
    
    // MARK: - Private Methods
    
    private func performAction(
        _ action: UserAction,
        files: [PDFFile],
        options: ProcessingOptions
    ) async throws -> [URL] {
        switch action {
        case .merge:
            let mergeOptions = options.mergeOptions ?? PDFMerger.MergeOptions()
            let outputURL = try await merger.merge(
                files: files,
                options: mergeOptions,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateProgress(progress, action: action)
                    }
                }
            )
            return [outputURL]
            
        case .split:
            guard let firstFile = files.first else {
                throw PDFEngineError.emptyInput
            }
            guard let splitMode = options.splitMode else {
                throw PDFEngineError.emptyInput
            }
            let outputURLs = try await splitter.split(
                file: firstFile,
                mode: splitMode,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateProgress(progress, action: action)
                    }
                }
            )
            return outputURLs
            
        case .flatten:
            guard let firstFile = files.first else {
                throw PDFEngineError.emptyInput
            }
            let flattenOptions = options.flattenOptions ?? PDFFlattener.FlattenOptions()
            let outputURL = try await flattener.flatten(
                file: firstFile,
                options: flattenOptions,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.updateProgress(progress, action: action)
                    }
                }
            )
            return [outputURL]
            
        case .editPages:
            // Edit Pages is handled by PageReorderView, not ProcessingView
            throw PDFEngineError.emptyInput
        }
    }
    
    private func updateProgress(_ progress: Double, action: UserAction) {
        guard case .processing = state else { return }
        
        // Throttle progress updates to avoid rapid state changes that trigger
        // SwiftUI's "onChange tried to update multiple times per frame" warning.
        // Always allow 100% progress through to ensure completion is displayed.
        let now = Date()
        let isFinalizing = shouldUseFinalizingMessage(for: action) && PDFProgressPolicy.isFinalizing(progress)
        guard progress >= 1.0 || isFinalizing || now.timeIntervalSince(lastProgressUpdate) >= progressThrottleInterval else {
            return
        }
        lastProgressUpdate = now
        
        state = .processing(progress: progress, message: progressMessage(for: action, progress: progress))
    }
    
    func progressMessage(for action: UserAction, progress: Double = 0) -> String {
        if shouldUseFinalizingMessage(for: action),
           PDFProgressPolicy.isFinalizing(progress) {
            return L10n.Processing.finalizingFile
        }
        
        switch action {
        case .merge:
            return L10n.Processing.mergingProgress(progress)
        case .split:
            return L10n.Processing.splittingProgress(progress)
        case .editPages:
            return L10n.Processing.reorderingProgress(progress)
        case .flatten:
            return L10n.Processing.flatteningProgress(progress)
        }
    }
    
    private func shouldUseFinalizingMessage(for action: UserAction) -> Bool {
        switch action {
        case .merge, .editPages, .flatten:
            return true
        case .split:
            return false
        }
    }
    
    private func errorMessage(for error: Error) -> String {
        if let pdfError = error as? PDFEngineError {
            return pdfError.errorDescription ?? L10n.Processing.pdfOperationFailed
        }
        if let usageError = error as? UsageError {
            return usageError.errorDescription ?? L10n.Processing.usageLimitReached
        }
        return L10n.Processing.unexpectedError
    }
}
