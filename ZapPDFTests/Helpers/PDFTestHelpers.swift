//
//  PDFTestHelpers.swift
//  ZapPDFTests
//
//  Utility functions for creating test PDFs programmatically.
//

import Foundation
import PDFKit

/// Utility functions for creating test PDFs in unit tests.
enum PDFTestHelpers {
    
    /// Create a PDF with the specified number of pages in the temp directory.
    ///
    /// Each page contains text indicating the page number for verification.
    ///
    /// - Parameters:
    ///   - pageCount: Number of pages to create
    ///   - identifier: Unique identifier for the filename
    /// - Returns: URL to the created PDF
    /// - Throws: Error if PDF creation fails
    static func createTestPDF(pageCount: Int, identifier: String = UUID().uuidString) throws -> URL {
        let pdfDocument = PDFDocument()
        
        for pageNum in 1...pageCount {
            if let page = createPage(number: pageNum) {
                pdfDocument.insert(page, at: pdfDocument.pageCount)
            }
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(identifier)")
            .appendingPathExtension("pdf")
        
        guard pdfDocument.write(to: url) else {
            throw TestHelperError.pdfCreationFailed
        }
        
        return url
    }
    
    /// Create multiple test PDFs with specified page counts.
    ///
    /// - Parameter counts: Array of page counts for each PDF
    /// - Returns: Array of URLs to created PDFs
    /// - Throws: Error if any PDF creation fails
    static func createTestPDFs(counts: [Int]) throws -> [URL] {
        var urls: [URL] = []
        let runID = UUID().uuidString
        for (index, count) in counts.enumerated() {
            let url = try createTestPDF(pageCount: count, identifier: "multi_\(runID)_\(index)")
            urls.append(url)
        }
        return urls
    }
    
    /// Clean up test PDFs.
    ///
    /// - Parameter urls: URLs of files to delete
    static func cleanup(urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Clean up a single test PDF.
    static func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Create a PDF with annotations for testing flattening.
    ///
    /// Each page will have a text annotation added to it.
    ///
    /// - Parameters:
    ///   - pageCount: Number of pages to create
    ///   - identifier: Unique identifier for the filename
    /// - Returns: URL to the created PDF with annotations
    /// - Throws: Error if PDF creation fails
    static func createTestPDFWithAnnotations(pageCount: Int, identifier: String) throws -> URL {
        let url = try createTestPDF(pageCount: pageCount, identifier: identifier)
        guard let document = PDFDocument(url: url) else {
            throw TestHelperError.pdfCreationFailed
        }
        
        // Add a text annotation to each page
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let annotation = PDFAnnotation(
                bounds: CGRect(x: 50, y: 50, width: 200, height: 50),
                forType: .text,
                withProperties: nil
            )
            annotation.contents = "Test annotation on page \(i + 1)"
            page.addAnnotation(annotation)
        }
        
        // Save with annotations
        guard document.write(to: url) else {
            throw TestHelperError.pdfCreationFailed
        }
        
        return url
    }
    
    private static func createPage(number: Int) -> PDFPage? {
        // Create a simple page with text
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        
        let renderer = CGContext(
            data: nil,
            width: Int(pageRect.width),
            height: Int(pageRect.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        guard let context = renderer else { return nil }
        
        // Fill with white
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(pageRect)
        
        // Draw page number text
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        
        // Create a PDF page from the data
        let pdfData = NSMutableData()
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            return nil
        }
        
        var mediaBox = pageRect
        pdfContext.beginPage(mediaBox: &mediaBox)
        
        // Draw white background
        pdfContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        pdfContext.fill(pageRect)
        
        // Draw page number as text (centered)
        let text = "Page \(number)" as CFString
        let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        
        let attributedString = NSAttributedString(string: text as String, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let x = (pageRect.width - textBounds.width) / 2
        let y = (pageRect.height - textBounds.height) / 2
        
        pdfContext.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, pdfContext)
        
        pdfContext.endPage()
        pdfContext.closePDF()
        
        // Create PDFDocument from data and get the page
        guard let pdfDocument = PDFDocument(data: pdfData as Data),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }
        
        return page
    }
    
    enum TestHelperError: Error {
        case pdfCreationFailed
    }
}
