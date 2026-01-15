//
//  PDFReorderer.swift
//  ZapPDF
//
//  Actor that reorders pages within a PDF document.
//

import Foundation
import PDFKit

/// Actor responsible for reordering and rotating pages within a PDF document.
///
/// `PDFReorderer` creates a new PDF with pages arranged according to
/// the specified order, with optional rotation applied to individual pages.
/// It supports progress reporting and cancellation.
///
/// Example:
/// ```swift
/// let reorderer = PDFReorderer()
/// // Move page 3 to first position and rotate it 90° clockwise
/// let outputURL = try await reorderer.reorder(
///     file: pdfFile,
///     newOrder: [2, 0, 1, 3, 4],
///     rotations: [2: .clockwise90],
///     progress: { print("Progress: \($0 * 100)%") }
/// )
/// ```
actor PDFReorderer {
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    
    // MARK: - Public Methods
    
    /// Reorder and optionally rotate pages in a PDF.
    ///
    /// Creates a new PDF document with pages arranged in the order specified
    /// by `newOrder`, with optional rotations applied. Each element in `newOrder`
    /// is a 0-based index referring to a page in the source document.
    ///
    /// - Parameters:
    ///   - file: The source PDF file to process
    ///   - newOrder: Array of 0-based page indices in the desired output order
    ///   - rotations: Dictionary mapping original page indices to rotation values (default: empty)
    ///   - outputFileName: Optional custom output filename (without extension)
    ///   - includeTimestamp: Whether to append a timestamp suffix for uniqueness (default: true, only applies when outputFileName is nil)
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: URL to the processed PDF in the temporary directory
    /// - Throws: `PDFEngineError` if processing fails
    ///
    /// Example:
    /// ```swift
    /// // Swap pages 2 and 3, rotate page 1 by 90°
    /// let newOrder = [0, 2, 1, 3]
    /// let rotations = [0: PageRotation.clockwise90]
    /// let url = try await reorderer.reorder(
    ///     file: pdf,
    ///     newOrder: newOrder,
    ///     rotations: rotations,
    ///     progress: { _ in }
    /// )
    /// ```
    func reorder(
        file: PDFFile,
        newOrder: [Int],
        rotations: [Int: PageRotation] = [:],
        outputFileName: String? = nil,
        includeTimestamp: Bool = true,
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
            
            // Copy pages in new order with optional rotation
            for (newIndex, originalIndex) in newOrder.enumerated() {
                try await self.checkCancellation()
                
                autoreleasepool {
                    if let page = sourceDocument.page(at: originalIndex) {
                        // Apply rotation if specified for this page
                        if let rotation = rotations[originalIndex] {
                            // PDFKit rotation is cumulative, so add to existing
                            page.rotation += rotation.degrees
                        }
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
            
            // Generate output filename with optional timestamp
            let baseName = file.url.deletingPathExtension().lastPathComponent
            var finalOutputName: String
            if let customName = outputFileName {
                // User provided custom name, use it as-is
                finalOutputName = customName
            } else {
                // Default name with optional timestamp
                // Use "edited" suffix since we now support more than just reordering
                finalOutputName = "\(baseName)_edited"
                if includeTimestamp {
                    finalOutputName += "_\(Date.filenameTimestamp())"
                }
            }
            
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
    /// - Have at least one element
    /// - Have at most `pageCount` elements
    /// - Contain only valid indices (0 to pageCount-1)
    /// - Contain each index at most once (no duplicates)
    ///
    /// Note: Order can have fewer elements than pageCount to support page deletion.
    ///
    /// - Parameters:
    ///   - order: Array of 0-based page indices
    ///   - pageCount: Total number of pages in the source document
    /// - Returns: `true` if the order is valid
    static func validateOrder(_ order: [Int], pageCount: Int) -> Bool {
        // Must have at least one element and at most pageCount elements
        guard !order.isEmpty && order.count <= pageCount else { return false }
        
        // All indices must be in valid range
        let validRange = 0..<pageCount
        guard order.allSatisfy({ validRange.contains($0) }) else { return false }
        
        // Each index must appear at most once (no duplicates)
        let uniqueIndices = Set(order)
        guard uniqueIndices.count == order.count else { return false }
        
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
