//
//  PDFMerger.swift
//  ZapPDF
//
//  Actor that merges multiple PDF files into a single output file.
//

import Foundation
import PDFKit

/// Actor responsible for merging multiple PDF files into one.
///
/// `PDFMerger` combines PDFs in the order they are provided, preserving all pages
/// and optionally bookmarks. It supports progress reporting and cancellation.
///
/// Example:
/// ```swift
/// let merger = PDFMerger()
/// let outputURL = try await merger.merge(
///     files: pdfFiles,
///     options: .init(outputFileName: "combined"),
///     progress: { print("Progress: \($0 * 100)%") }
/// )
/// ```
actor PDFMerger {
    
    // MARK: - Types
    
    /// Options for configuring the merge operation.
    struct MergeOptions: Sendable {
        /// Base name for the output file (without extension)
        var outputFileName: String = "merged"
        
        /// Whether to preserve bookmarks from source documents
        var preserveBookmarks: Bool = true
        
        /// Whether to append a timestamp suffix for uniqueness
        var includeTimestamp: Bool = true
        
        /// Creates default merge options
        init(outputFileName: String = "merged", preserveBookmarks: Bool = true, includeTimestamp: Bool = true) {
            self.outputFileName = outputFileName
            self.preserveBookmarks = preserveBookmarks
            self.includeTimestamp = includeTimestamp
        }
    }
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    
    // MARK: - Public Methods
    
    /// Merge multiple PDF files into a single output file.
    ///
    /// - Parameters:
    ///   - files: Array of `PDFFile` objects to merge (in order)
    ///   - options: Configuration options for the merge
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: URL to the merged PDF file in the temporary directory
    /// - Throws: `PDFEngineError` if merge fails
    func merge(
        files: [PDFFile],
        options: MergeOptions = MergeOptions(),
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Reset cancellation state
        isCancelled = false
        
        // Validate input
        guard !files.isEmpty else {
            throw PDFEngineError.emptyInput
        }
        
        // Calculate total pages for progress
        let totalPages = files.reduce(0) { $0 + $1.pageCount }
        var processedPages = 0
        
        // Create output document
        let outputDocument = PDFDocument()
        
        // Process each file
        for file in files {
            try checkCancellation()
            
            // Access file with security scope and bookmark resolution
            try await file.withResolvedAccessAsync { resolvedURL in
                try Task.checkCancellation()
                
                guard let sourceDocument = PDFDocument(url: resolvedURL) else {
                    throw PDFEngineError.invalidPDF(resolvedURL)
                }
                
                // Check if password protected
                if sourceDocument.isLocked {
                    throw PDFEngineError.passwordProtected(file.url)
                }
                
                // Insert each page
                for pageIndex in 0..<sourceDocument.pageCount {
                    try await self.checkCancellation()
                    
                    autoreleasepool {
                        if let page = sourceDocument.page(at: pageIndex) {
                            outputDocument.insert(page, at: outputDocument.pageCount)
                        }
                    }
                    
                    processedPages += 1
                    let rawProgress = Double(processedPages) / Double(totalPages)
                    let currentProgress = PDFProgressPolicy.processingProgress(from: rawProgress)
                    
                    // Report progress on main actor
                    await MainActor.run {
                        progress(currentProgress)
                    }
                }
            }
        }
        
        try checkCancellation()

        // Enter finalization stage before the final disk write.
        await MainActor.run {
            progress(PDFProgressPolicy.finalizingStart)
        }
        
        try checkCancellation()
        
        // Generate output URL with optional timestamp
        var finalOutputName = options.outputFileName
        if options.includeTimestamp {
            finalOutputName += "_\(Date.filenameTimestamp())"
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(finalOutputName)
            .appendingPathExtension("pdf")
        
        // Write output file
        guard outputDocument.write(to: outputURL) else {
            throw PDFEngineError.writeFailed(outputURL)
        }
        
        await MainActor.run {
            progress(1.0)
        }
        
        return outputURL
    }
    
    /// Cancel the current merge operation.
    ///
    /// The operation will throw `PDFEngineError.cancelled` at the next checkpoint.
    func cancel() {
        isCancelled = true
    }
    
    // MARK: - Private Methods
    
    private func checkCancellation() throws {
        if isCancelled {
            throw PDFEngineError.cancelled
        }
        try Task.checkCancellation()
    }
    
    private nonisolated func checkCancellationSync() throws {
        try Task.checkCancellation()
    }
}
