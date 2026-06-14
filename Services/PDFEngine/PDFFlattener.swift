//
//  PDFFlattener.swift
//  ZapPDF
//
//  Actor that flattens PDF documents by baking annotations into page content.
//

import Foundation
import PDFKit

/// Actor responsible for flattening PDF documents.
///
/// `PDFFlattener` renders each page with its annotations into a new
/// PDF document, effectively "baking" all interactive elements (annotations,
/// form fields) into static page content.
///
/// Example:
/// ```swift
/// let flattener = PDFFlattener()
/// let outputURL = try await flattener.flatten(
///     file: pdfFile,
///     options: .init(outputFileName: "flattened_doc"),
///     progress: { _ in }
/// )
/// ```
actor PDFFlattener {
    
    // MARK: - Types
    
    /// Options for configuring the flatten operation.
    struct FlattenOptions: Sendable {
        /// Base name for the output file (without extension)
        var outputFileName: String = "flattened"
        
        /// Whether to append a timestamp suffix for uniqueness
        var includeTimestamp: Bool = true
        
        /// Creates default flatten options
        init(outputFileName: String = "flattened", includeTimestamp: Bool = true) {
            self.outputFileName = outputFileName
            self.includeTimestamp = includeTimestamp
        }
    }
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    
    // MARK: - Public Methods
    
    /// Flatten a PDF document, baking annotations into page content.
    ///
    /// This method renders each page with its annotations into a new PDF,
    /// making all interactive elements (highlights, comments, form fields)
    /// part of the static page content.
    ///
    /// - Parameters:
    ///   - file: The source PDF file to process
    ///   - options: Configuration options for the flatten
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: URL to the flattened PDF file in the temporary directory
    /// - Throws: `PDFEngineError` if flatten fails
    func flatten(
        file: PDFFile,
        options: FlattenOptions = FlattenOptions(),
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Reset cancellation state
        isCancelled = false
        
        // Access file with security scope and bookmark resolution
        return try await file.withResolvedAccessAsync { resolvedURL in
            try Task.checkCancellation()
            
            guard let sourceDocument = PDFDocument(url: resolvedURL) else {
                throw PDFEngineError.invalidPDF(resolvedURL)
            }
            
            // Check if password protected
            if sourceDocument.isLocked {
                throw PDFEngineError.passwordProtected(file.url)
            }
            
            let pageCount = sourceDocument.pageCount
            guard pageCount > 0 else {
                throw PDFEngineError.emptyInput
            }
            
            // Generate output URL early for file-based streaming
            let baseName = file.url.deletingPathExtension().lastPathComponent
            var finalOutputName: String
            if options.outputFileName != "flattened" {
                finalOutputName = options.outputFileName
            } else {
                finalOutputName = "\(baseName)_flattened"
            }
            if options.includeTimestamp {
                finalOutputName += "_\(Date.filenameTimestamp())"
            }
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(finalOutputName)
                .appendingPathExtension("pdf")
            
            // Create file-based PDF context (streams to disk, low memory footprint)
            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
                throw PDFEngineError.writeFailed(outputURL)
            }
            
            var didComplete = false
            defer {
                pdfContext.closePDF()
                if !didComplete {
                    try? FileManager.default.removeItem(at: outputURL)
                }
            }
            
            // Process each page
            for pageIndex in 0..<pageCount {
                try await self.checkCancellation()
                
                autoreleasepool {
                    guard let page = sourceDocument.page(at: pageIndex) else { return }
                    
                    // Determine effective bounds (cropBox for WYSIWYG, fallback to mediaBox)
                    let cropBox = page.bounds(for: .cropBox)
                    let mediaBox = page.bounds(for: .mediaBox)
                    let effectiveBounds = cropBox.isEmpty ? mediaBox : cropBox
                    
                    // Output page has origin at (0,0) with effective size
                    var outputMediaBox = CGRect(origin: .zero, size: effectiveBounds.size)
                    
                    // Begin PDF page with correct dimensions
                    pdfContext.beginPDFPage([
                        kCGPDFContextMediaBox: outputMediaBox
                    ] as CFDictionary)
                    
                    // Save graphics state before transformations
                    pdfContext.saveGState()
                    
                    // Translate context to account for page's bounds origin
                    // This ensures content is drawn within visible bounds
                    pdfContext.translateBy(x: -effectiveBounds.minX, y: -effectiveBounds.minY)
                    
                    // Draw the page content including annotations
                    // PDFPage.draw handles rotation automatically
                    page.draw(with: .cropBox, to: pdfContext)
                    
                    // Restore graphics state
                    pdfContext.restoreGState()
                    
                    pdfContext.endPDFPage()
                }
                
                let rawProgress = Double(pageIndex + 1) / Double(pageCount)
                let currentProgress = PDFProgressPolicy.processingProgress(from: rawProgress)
                
                // Report progress on main actor
                await MainActor.run {
                    progress(currentProgress)
                }
            }
            
            try await self.checkCancellation()
            
            await MainActor.run {
                progress(PDFProgressPolicy.finalizingStart)
            }
            
            // Close the PDF context (defer finalizes the file write)
            await MainActor.run {
                progress(1.0)
            }
            
            didComplete = true
            return outputURL
        }
    }
    
    /// Cancel the current flatten operation.
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
}
