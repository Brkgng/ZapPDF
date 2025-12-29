//
//  PDFReorderer.swift
//  ZapPDF
//
//  Actor that reorders pages within a PDF document.
//

import Foundation
import PDFKit

/// Actor responsible for reordering pages within a PDF document.
///
/// `PDFReorderer` creates a new PDF with pages arranged according to
/// the specified order. It supports progress reporting and cancellation.
///
/// Example:
/// ```swift
/// let reorderer = PDFReorderer()
/// // Move page 3 to the first position: [2, 0, 1, 3, 4]
/// let outputURL = try await reorderer.reorder(
///     file: pdfFile,
///     newOrder: [2, 0, 1, 3, 4],
///     progress: { print("Progress: \($0 * 100)%") }
/// )
/// ```
actor PDFReorderer {
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    
    // MARK: - Public Methods
    
    /// Reorder pages in a PDF according to the specified order.
    ///
    /// Creates a new PDF document with pages arranged in the order specified
    /// by `newOrder`. Each element in `newOrder` is a 0-based index referring
    /// to a page in the source document.
    ///
    /// - Parameters:
    ///   - file: The source PDF file to reorder
    ///   - newOrder: Array of 0-based page indices in the desired output order
    ///   - outputFileName: Optional custom output filename (without extension)
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: URL to the reordered PDF in the temporary directory
    /// - Throws: `PDFEngineError` if reordering fails
    ///
    /// Example:
    /// ```swift
    /// // Original 4-page document, swap pages 2 and 3
    /// let newOrder = [0, 2, 1, 3]  // 0-based indices
    /// let url = try await reorderer.reorder(file: pdf, newOrder: newOrder, progress: { _ in })
    /// ```
    func reorder(
        file: PDFFile,
        newOrder: [Int],
        outputFileName: String? = nil,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Reset cancellation state
        isCancelled = false
        
        // Validate input
        guard !newOrder.isEmpty else {
            throw PDFEngineError.emptyInput
        }
        
        // Validate order
        guard Self.validateOrder(newOrder, pageCount: file.pageCount) else {
            throw PDFEngineError.invalidPageRange(
                range: 0...file.pageCount - 1,
                totalPages: file.pageCount
            )
        }
        
        // Access file with security scope
        return try await file.url.withSecurityScopeAsync { [self] in
            try self.checkCancellationSync()
            
            guard let sourceDocument = PDFDocument(url: file.url) else {
                throw PDFEngineError.invalidPDF(file.url)
            }
            
            // Check if password protected
            if sourceDocument.isLocked {
                throw PDFEngineError.passwordProtected(file.url)
            }
            
            // Create output document
            let outputDocument = PDFDocument()
            let totalPages = newOrder.count
            
            // Copy pages in new order
            for (newIndex, originalIndex) in newOrder.enumerated() {
                try await self.checkCancellation()
                
                autoreleasepool {
                    if let page = sourceDocument.page(at: originalIndex) {
                        outputDocument.insert(page, at: newIndex)
                    }
                }
                
                let currentProgress = Double(newIndex + 1) / Double(totalPages)
                
                // Report progress on main actor
                await MainActor.run {
                    progress(currentProgress)
                }
            }
            
            try await self.checkCancellation()
            
            // Generate output filename
            let baseName = file.url.deletingPathExtension().lastPathComponent
            let finalOutputName = outputFileName ?? "\(baseName)_reordered"
            
            // Generate output URL
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(finalOutputName)
                .appendingPathExtension("pdf")
            
            // Write output file
            guard outputDocument.write(to: outputURL) else {
                throw PDFEngineError.writeFailed(outputURL)
            }
            
            return outputURL
        }
    }
    
    /// Cancel the current reorder operation.
    ///
    /// The operation will throw `PDFEngineError.cancelled` at the next checkpoint.
    func cancel() {
        isCancelled = true
    }
    
    // MARK: - Static Validation
    
    /// Validate that a new order array is valid for the given page count.
    ///
    /// A valid order must:
    /// - Have the same number of elements as `pageCount`
    /// - Contain each index from 0 to (pageCount - 1) exactly once
    ///
    /// - Parameters:
    ///   - order: Array of 0-based page indices
    ///   - pageCount: Total number of pages in the source document
    /// - Returns: `true` if the order is valid
    static func validateOrder(_ order: [Int], pageCount: Int) -> Bool {
        // Must have same number of elements as pages
        guard order.count == pageCount else { return false }
        
        // Empty is valid only for empty document
        guard !order.isEmpty else { return pageCount == 0 }
        
        // All indices must be in range
        let validRange = 0..<pageCount
        guard order.allSatisfy({ validRange.contains($0) }) else { return false }
        
        // Each index must appear exactly once
        let uniqueIndices = Set(order)
        guard uniqueIndices.count == pageCount else { return false }
        
        return true
    }
    
    /// Check if an order represents any actual change from the original.
    ///
    /// - Parameter order: Array of 0-based page indices
    /// - Returns: `true` if the order differs from sequential (0, 1, 2, ...)
    static func hasOrderChanged(_ order: [Int]) -> Bool {
        for (index, pageIndex) in order.enumerated() {
            if index != pageIndex {
                return true
            }
        }
        return false
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
