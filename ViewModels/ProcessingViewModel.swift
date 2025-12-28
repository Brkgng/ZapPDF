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
    
    /// Creates default processing options.
    init(
        mergeOptions: PDFMerger.MergeOptions? = nil,
        splitMode: PDFSplitter.SplitMode? = nil
    ) {
        self.mergeOptions = mergeOptions
        self.splitMode = splitMode
    }
    
    /// Creates options for a merge operation.
    static func merge(outputFileName: String = "merged") -> ProcessingOptions {
        ProcessingOptions(mergeOptions: .init(outputFileName: outputFileName))
    }
    
    /// Creates options for a split operation.
    static func split(mode: PDFSplitter.SplitMode) -> ProcessingOptions {
        ProcessingOptions(splitMode: mode)
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
    private let usageManager: any UsageManaging
    
    // MARK: - Initialization
    
    /// Creates a ProcessingViewModel with default services.
    init() {
        self.merger = PDFMerger()
        self.splitter = PDFSplitter()
        self.usageManager = UsageManager.shared
    }
    
    /// Creates a ProcessingViewModel with custom services (for testing).
    init(
        merger: PDFMerger = PDFMerger(),
        splitter: PDFSplitter = PDFSplitter(),
        usageManager: any UsageManaging
    ) {
        self.merger = merger
        self.splitter = splitter
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
            
        case .convert:
            // TODO: Implement in future phase
            throw PDFEngineError.emptyInput
        }
    }
    
    private func updateProgress(_ progress: Double, action: UserAction) {
        guard case .processing = state else { return }
        state = .processing(progress: progress, message: progressMessage(for: action, progress: progress))
    }
    
    private func progressMessage(for action: UserAction, progress: Double = 0) -> String {
        let percentage = Int(progress * 100)
        switch action {
        case .merge:
            return percentage > 0 ? "Merging PDFs... \(percentage)%" : "Merging PDFs..."
        case .split:
            return percentage > 0 ? "Splitting PDF... \(percentage)%" : "Splitting PDF..."
        case .convert:
            return percentage > 0 ? "Converting PDF... \(percentage)%" : "Converting PDF..."
        }
    }
    
    private func errorMessage(for error: Error) -> String {
        if let pdfError = error as? PDFEngineError {
            return pdfError.errorDescription ?? "PDF operation failed."
        }
        if let usageError = error as? UsageError {
            return usageError.errorDescription ?? "Usage limit reached."
        }
        return "An unexpected error occurred."
    }
}
