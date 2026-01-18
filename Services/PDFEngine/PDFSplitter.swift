//
//  PDFSplitter.swift
//  ZapPDF
//
//  Actor that splits a PDF file into multiple output files.
//

import Foundation
import PDFKit

/// Actor responsible for splitting a PDF into multiple files.
///
/// `PDFSplitter` supports three modes of splitting:
/// - By page ranges: Extract specific ranges like pages 1-5, 10-15
/// - Extract pages: Pull out specific individual pages
/// - Split every N pages: Divide into chunks of N pages each
///
/// Example:
/// ```swift
/// let splitter = PDFSplitter()
/// let outputURLs = try await splitter.split(
///     file: pdfFile,
///     mode: .splitEvery(n: 5),
///     progress: { print("Progress: \($0 * 100)%") }
/// )
/// ```
actor PDFSplitter {
    
    // MARK: - Types
    
    /// Defines how the PDF should be split.
    enum SplitMode: Sendable {
        /// Extract specific page ranges (1-indexed, inclusive)
        case byPageRange(ranges: [ClosedRange<Int>])
        
        /// Extract specific individual pages (1-indexed)
        case extractPages(indices: [Int])
        
        /// Split into chunks of N pages each
        case splitEvery(n: Int)
    }
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    
    // MARK: - Public Methods
    
    /// Split a PDF file into multiple output files.
    ///
    /// - Parameters:
    ///   - file: The source `PDFFile` to split
    ///   - mode: How to split the PDF
    ///   - includeTimestamp: Whether to append a timestamp suffix for uniqueness (default: true)
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: Array of URLs to the output PDF files
    /// - Throws: `PDFEngineError` if split fails
    func split(
        file: PDFFile,
        mode: SplitMode,
        includeTimestamp: Bool = true,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [URL] {
        // Reset cancellation state
        isCancelled = false
        
        // Access file with security scope and bookmark resolution
        return try await file.withResolvedAccessAsync { resolvedURL in
            guard let sourceDocument = PDFDocument(url: resolvedURL) else {
                throw PDFEngineError.invalidPDF(resolvedURL)
            }
            
            if sourceDocument.isLocked {
                throw PDFEngineError.passwordProtected(file.url)
            }
            
            let totalPages = sourceDocument.pageCount
            
            // Determine segments based on mode
            let segments = try self.calculateSegmentsSync(mode: mode, totalPages: totalPages)
            
            guard !segments.isEmpty else {
                throw PDFEngineError.emptyInput
            }
            
            var outputURLs: [URL] = []
            let baseName = file.url.deletingPathExtension().lastPathComponent
            
            for (index, segment) in segments.enumerated() {
                try Task.checkCancellation()
                
                // Create output document for this segment
                let outputDocument = PDFDocument()
                
                for pageIndex in segment {
                    try Task.checkCancellation()
                    
                    // PDFKit uses 0-indexed pages internally
                    let zeroBasedIndex = pageIndex - 1
                    
                    autoreleasepool {
                        if let page = sourceDocument.page(at: zeroBasedIndex) {
                            outputDocument.insert(page, at: outputDocument.pageCount)
                        }
                    }
                }
                
                // Generate output filename with optional timestamp
                let timestamp = includeTimestamp ? "_\(Date.filenameTimestamp())" : ""
                let outputName: String
                if segments.count == 1 {
                    outputName = "\(baseName)_extracted\(timestamp)"
                } else {
                    outputName = "\(baseName)_part\(index + 1)\(timestamp)"
                }
                
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(outputName)
                    .appendingPathExtension("pdf")
                
                guard outputDocument.write(to: outputURL) else {
                    throw PDFEngineError.writeFailed(outputURL)
                }
                
                outputURLs.append(outputURL)
                
                // Report progress
                let currentProgress = Double(index + 1) / Double(segments.count)
                await MainActor.run {
                    progress(currentProgress)
                }
            }
            
            return outputURLs
        }
    }
    
    /// Cancel the current split operation.
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
    
    /// Calculate page segments based on split mode (nonisolated for use in closures).
    private nonisolated func calculateSegmentsSync(mode: SplitMode, totalPages: Int) throws -> [[Int]] {
        switch mode {
        case .byPageRange(let ranges):
            // Validate all ranges
            for range in ranges {
                guard range.lowerBound >= 1, range.upperBound <= totalPages else {
                    throw PDFEngineError.invalidPageRange(range: range, totalPages: totalPages)
                }
            }
            // Each range becomes a separate output file
            return ranges.map { Array($0) }
            
        case .extractPages(let indices):
            // Validate all indices
            for index in indices {
                guard index >= 1, index <= totalPages else {
                    throw PDFEngineError.invalidPageRange(range: index...index, totalPages: totalPages)
                }
            }
            // All extracted pages go into a single output file
            return [indices.sorted()]
            
        case .splitEvery(let n):
            guard n > 0 else {
                throw PDFEngineError.emptyInput
            }
            
            var segments: [[Int]] = []
            var currentSegment: [Int] = []
            
            for pageNum in 1...totalPages {
                currentSegment.append(pageNum)
                
                if currentSegment.count == n {
                    segments.append(currentSegment)
                    currentSegment = []
                }
            }
            
            // Don't forget the last partial segment
            if !currentSegment.isEmpty {
                segments.append(currentSegment)
            }
            
            return segments
        }
    }
}
