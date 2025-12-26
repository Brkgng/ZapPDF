//
//  PDFThumbnailViewTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFThumbnailView component.
//

import XCTest
import SwiftUI
@testable import ZapPDF

final class PDFThumbnailViewTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a mock PDFFile for testing.
    private func createMockPDFFile(
        fileName: String = "test.pdf",
        pageCount: Int = 5,
        fileSize: Int64 = 1024
    ) -> PDFFile {
        return PDFFile(
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileName: fileName,
            pageCount: pageCount,
            fileSize: fileSize
        )
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultProperties() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile)
        
        // Then
        // Default size is 120x160
        XCTAssertEqual(view.size.width, 120)
        XCTAssertEqual(view.size.height, 160)
        XCTAssertTrue(view.showPageCount)
        XCTAssertEqual(view.cornerRadius, 8)
    }
    
    func testCustomProperties() {
        // Given
        let pdfFile = createMockPDFFile()
        let customSize = CGSize(width: 200, height: 280)
        
        // When
        let view = PDFThumbnailView(
            pdfFile: pdfFile,
            size: customSize,
            showPageCount: false,
            cornerRadius: 12
        )
        
        // Then
        XCTAssertEqual(view.size, customSize)
        XCTAssertFalse(view.showPageCount)
        XCTAssertEqual(view.cornerRadius, 12)
    }
    
    // MARK: - PDFFile Integration Tests
    
    func testUsesCorrectPDFFile() {
        // Given
        let pdfFile = createMockPDFFile(fileName: "document.pdf", pageCount: 10)
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(view.pdfFile.fileName, "document.pdf")
        XCTAssertEqual(view.pdfFile.pageCount, 10)
    }
    
    func testDifferentPDFFilesProduceDifferentViews() {
        // Given
        let file1 = createMockPDFFile(fileName: "doc1.pdf")
        let file2 = createMockPDFFile(fileName: "doc2.pdf")
        
        // When
        let view1 = PDFThumbnailView(pdfFile: file1)
        let view2 = PDFThumbnailView(pdfFile: file2)
        
        // Then
        XCTAssertNotEqual(view1.pdfFile.id, view2.pdfFile.id)
    }
    
    // MARK: - Size Variation Tests
    
    func testSmallSize() {
        // Given
        let pdfFile = createMockPDFFile()
        let smallSize = CGSize(width: 60, height: 80)
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile, size: smallSize)
        
        // Then
        XCTAssertEqual(view.size, smallSize)
    }
    
    func testLargeSize() {
        // Given
        let pdfFile = createMockPDFFile()
        let largeSize = CGSize(width: 300, height: 400)
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile, size: largeSize)
        
        // Then
        XCTAssertEqual(view.size, largeSize)
    }
    
    // MARK: - Page Count Display Tests
    
    func testPageCountShownByDefault() {
        // Given
        let pdfFile = createMockPDFFile(pageCount: 15)
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile)
        
        // Then
        XCTAssertTrue(view.showPageCount)
        XCTAssertEqual(view.pdfFile.pageCount, 15)
    }
    
    func testPageCountCanBeHidden() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let view = PDFThumbnailView(pdfFile: pdfFile, showPageCount: false)
        
        // Then
        XCTAssertFalse(view.showPageCount)
    }
}

// MARK: - PDFRenderer Tests (for thumbnail view)

final class PDFThumbnailRendererTests: XCTestCase {
    
    private var renderer: PDFRenderer!
    
    override func setUp() async throws {
        renderer = PDFRenderer()
    }
    
    override func tearDown() async throws {
        await renderer.clearCache()
        renderer = nil
    }
    
    func testCacheStartsEmpty() async {
        // When
        let count = await renderer.cacheCount
        
        // Then
        XCTAssertEqual(count, 0)
    }
    
    func testClearCache() async {
        // This test just verifies clearCache doesn't crash
        await renderer.clearCache()
        let count = await renderer.cacheCount
        XCTAssertEqual(count, 0)
    }
    
    func testThumbnailReturnsNilForInvalidURL() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        
        // When
        let thumbnail = await renderer.thumbnail(
            for: invalidURL,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )
        
        // Then
        XCTAssertNil(thumbnail)
    }
    
    func testThumbnailReturnsNilForNonPDFFile() async {
        // Given
        let textFileURL = URL(fileURLWithPath: "/tmp/test.txt")
        
        // When
        let thumbnail = await renderer.thumbnail(
            for: textFileURL,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )
        
        // Then
        XCTAssertNil(thumbnail)
    }
}
