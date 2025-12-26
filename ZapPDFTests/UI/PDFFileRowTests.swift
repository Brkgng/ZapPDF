//
//  PDFFileRowTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFFileRow component.
//

import XCTest
import SwiftUI
@testable import ZapPDF

final class PDFFileRowTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a mock PDFFile for testing.
    private func createMockPDFFile(
        fileName: String = "test.pdf",
        pageCount: Int = 5,
        fileSize: Int64 = 1_048_576 // 1 MB
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
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(row.pdfFile.fileName, "test.pdf")
        XCTAssertFalse(row.showDragHandle)
        XCTAssertTrue(row.showDeleteButton)
        XCTAssertNil(row.onDelete)
    }
    
    func testCustomProperties() {
        // Given
        let pdfFile = createMockPDFFile()
        var deleteWasCalled = false
        
        // When
        let row = PDFFileRow(
            pdfFile: pdfFile,
            showDragHandle: true,
            showDeleteButton: true,
            onDelete: { deleteWasCalled = true }
        )
        
        // Then
        XCTAssertTrue(row.showDragHandle)
        XCTAssertTrue(row.showDeleteButton)
        XCTAssertNotNil(row.onDelete)
    }
    
    // MARK: - PDFFile Data Display Tests
    
    func testDisplaysCorrectFileName() {
        // Given
        let pdfFile = createMockPDFFile(fileName: "Annual Report 2024.pdf")
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(row.pdfFile.fileName, "Annual Report 2024.pdf")
    }
    
    func testDisplaysCorrectPageCount() {
        // Given
        let pdfFile = createMockPDFFile(pageCount: 42)
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(row.pdfFile.pageCount, 42)
    }
    
    func testDisplaysCorrectFileSize() {
        // Given
        let pdfFile = createMockPDFFile(fileSize: 5_242_880) // 5 MB
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(row.pdfFile.fileSize, 5_242_880)
        XCTAssertTrue(row.pdfFile.formattedFileSize.contains("MB"))
    }
    
    // MARK: - Drag Handle Tests
    
    func testDragHandleHiddenByDefault() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertFalse(row.showDragHandle)
    }
    
    func testDragHandleCanBeShown() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile, showDragHandle: true)
        
        // Then
        XCTAssertTrue(row.showDragHandle)
    }
    
    // MARK: - Delete Callback Tests
    
    func testDeleteCallbackIsOptional() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile)
        
        // Then
        XCTAssertNil(row.onDelete)
    }
    
    func testDeleteCallbackCanBeProvided() {
        // Given
        let pdfFile = createMockPDFFile()
        var wasDeleted = false
        
        // When
        let row = PDFFileRow(pdfFile: pdfFile, onDelete: { wasDeleted = true })
        
        // Then
        XCTAssertNotNil(row.onDelete)
        
        // Simulate delete
        row.onDelete?()
        XCTAssertTrue(wasDeleted)
    }
    
    // MARK: - Formatted File Size Tests
    
    func testFormattedFileSizeKB() {
        // Given
        let pdfFile = createMockPDFFile(fileSize: 512_000) // ~500 KB
        
        // Then
        let formatted = pdfFile.formattedFileSize
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("kB"))
    }
    
    func testFormattedFileSizeMB() {
        // Given
        let pdfFile = createMockPDFFile(fileSize: 2_621_440) // 2.5 MB
        
        // Then
        let formatted = pdfFile.formattedFileSize
        XCTAssertTrue(formatted.contains("MB"))
    }
    
    func testFormattedFileSizeGB() {
        // Given
        let pdfFile = createMockPDFFile(fileSize: 1_610_612_736) // 1.5 GB
        
        // Then
        let formatted = pdfFile.formattedFileSize
        XCTAssertTrue(formatted.contains("GB"))
    }
}

// MARK: - PDFFileRowCompact Tests

final class PDFFileRowCompactTests: XCTestCase {
    
    private func createMockPDFFile() -> PDFFile {
        return PDFFile(
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            fileName: "test.pdf",
            pageCount: 5,
            fileSize: 1_048_576
        )
    }
    
    func testCompactRowProperties() {
        // Given
        let pdfFile = createMockPDFFile()
        
        // When
        let row = PDFFileRowCompact(pdfFile: pdfFile)
        
        // Then
        XCTAssertEqual(row.pdfFile.fileName, "test.pdf")
        XCTAssertNil(row.onDelete)
    }
    
    func testCompactRowWithDeleteCallback() {
        // Given
        let pdfFile = createMockPDFFile()
        var wasDeleted = false
        
        // When
        let row = PDFFileRowCompact(pdfFile: pdfFile, onDelete: { wasDeleted = true })
        
        // Then
        XCTAssertNotNil(row.onDelete)
        
        row.onDelete?()
        XCTAssertTrue(wasDeleted)
    }
}
