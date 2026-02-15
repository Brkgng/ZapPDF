//
//  PDFTestHelpers.swift
//  ZapPDFTests
//
//  Utility functions for creating test PDFs programmatically.
//

import Foundation
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

    /// Create a PDF with a simple outline tree targeting the first page.
    static func createTestPDFWithOutline(pageCount: Int, identifier: String) throws -> URL {
        let url = try createTestPDF(pageCount: pageCount, identifier: identifier)
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw TestHelperError.pdfCreationFailed
        }

        let root = PDFOutline()
        let child = PDFOutline()
        child.label = "Chapter 1"
        child.isOpen = true

        guard let firstPage = document.page(at: 0) else {
            throw TestHelperError.pdfCreationFailed
        }

        child.destination = PDFDestination(page: firstPage, at: CGPoint(x: 20, y: 20))
        root.insertChild(child, at: 0)
        document.outlineRoot = root

        guard document.write(to: url) else {
            throw TestHelperError.pdfCreationFailed
        }

        return url
    }

    /// Create a PDF with an internal GoTo link from page 1 to page 2.
    static func createTestPDFWithInternalLink(identifier: String) throws -> URL {
        let url = try createTestPDF(pageCount: 2, identifier: identifier)
        guard let document = PDFDocument(url: url),
              let page1 = document.page(at: 0),
              let page2 = document.page(at: 1) else {
            throw TestHelperError.pdfCreationFailed
        }

        let link = PDFAnnotation(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 60),
            forType: .link,
            withProperties: nil
        )
        let destination = PDFDestination(page: page2, at: CGPoint(x: 40, y: 40))
        link.action = PDFActionGoTo(destination: destination)
        page1.addAnnotation(link)

        guard document.write(to: url) else {
            throw TestHelperError.pdfCreationFailed
        }

        return url
    }

    /// Create a PDF with an external URL link on page 1.
    static func createTestPDFWithExternalLink(identifier: String, url externalURL: URL) throws -> URL {
        let url = try createTestPDF(pageCount: 1, identifier: identifier)
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            throw TestHelperError.pdfCreationFailed
        }

        let link = PDFAnnotation(
            bounds: CGRect(x: 80, y: 80, width: 260, height: 50),
            forType: .link,
            withProperties: nil
        )
        link.action = PDFActionURL(url: externalURL)
        page.addAnnotation(link)

        guard document.write(to: url) else {
            throw TestHelperError.pdfCreationFailed
        }

        return url
    }

    /// Create an image-heavy PDF for size and compression behavior tests.
    static func createImageHeavyPDF(
        pageCount: Int,
        identifier: String,
        imageWidth: Int = 1400,
        imageHeight: Int = 1800
    ) throws -> URL {
        guard let cgImage = noisyImage(width: imageWidth, height: imageHeight) else {
            throw TestHelperError.pdfCreationFailed
        }

        #if os(macOS)
        let platformImage = NSImage(cgImage: cgImage, size: NSSize(width: imageWidth, height: imageHeight))
        #else
        let platformImage = UIImage(cgImage: cgImage)
        #endif

        let document = PDFDocument()
        for pageIndex in 0..<pageCount {
            guard let page = PDFPage(image: platformImage) else {
                throw TestHelperError.pdfCreationFailed
            }

            // Add a small annotation so pages are not byte-identical.
            let note = PDFAnnotation(
                bounds: CGRect(x: 30, y: 30, width: 200, height: 40),
                forType: .freeText,
                withProperties: nil
            )
            note.contents = "Image page \(pageIndex + 1)"
            page.addAnnotation(note)

            document.insert(page, at: document.pageCount)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("image_heavy_\(identifier)")
            .appendingPathExtension("pdf")

        guard document.write(to: outputURL) else {
            throw TestHelperError.pdfCreationFailed
        }

        return outputURL
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

    private static func noisyImage(width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let byteCount = height * bytesPerRow

        var data = [UInt8](repeating: 0, count: byteCount)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * bytesPerRow) + (x * bytesPerPixel)
                let value = UInt8((x &* 37 &+ y &* 17) & 0xFF)
                data[index] = value
                data[index + 1] = UInt8((Int(value) &+ x) & 0xFF)
                data[index + 2] = UInt8((Int(value) &+ y) & 0xFF)
                data[index + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
    
    enum TestHelperError: Error {
        case pdfCreationFailed
    }
}
