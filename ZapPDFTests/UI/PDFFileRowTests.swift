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

    private func createMockPDFFile(
        fileName: String = "test.pdf",
        pageCount: Int = 5,
        fileSize: Int64 = 1_048_576
    ) -> PDFFile {
        return PDFFile(
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileName: fileName,
            pageCount: pageCount,
            fileSize: fileSize
        )
    }

    func testInitializerStoresDefaultsAndOverrides() {
        let pdfFile = createMockPDFFile()

        let row = PDFFileRow(pdfFile: pdfFile)
        XCTAssertEqual(row.pdfFile.fileName, "test.pdf")
        XCTAssertFalse(row.showDragHandle)
        XCTAssertTrue(row.showDeleteButton)
        XCTAssertNil(row.onDelete)

        let rowWithOverrides = PDFFileRow(
            pdfFile: pdfFile,
            showDragHandle: true,
            showDeleteButton: false
        )
        XCTAssertTrue(rowWithOverrides.showDragHandle)
        XCTAssertFalse(rowWithOverrides.showDeleteButton)
    }

    func testDeleteCallbackInvokedWhenProvided() {
        let pdfFile = createMockPDFFile()
        var wasDeleted = false

        let row = PDFFileRow(pdfFile: pdfFile, onDelete: { wasDeleted = true })

        XCTAssertNotNil(row.onDelete)

        row.onDelete?()
        XCTAssertTrue(wasDeleted)
    }

    func testDeleteButtonCanBeHiddenWhileDeleteCallbackExists() {
        let pdfFile = createMockPDFFile()
        var wasDeleted = false

        let row = PDFFileRow(
            pdfFile: pdfFile,
            showDeleteButton: false,
            onDelete: { wasDeleted = true }
        )

        XCTAssertFalse(row.showDeleteButton)
        XCTAssertNotNil(row.onDelete)

        row.onDelete?()
        XCTAssertTrue(wasDeleted)
    }

    func testFormattedFileSizeKB() {
        let pdfFile = createMockPDFFile(fileSize: 512_000)

        XCTAssertTrue(pdfFile.formattedFileSize.contains("KB") || pdfFile.formattedFileSize.contains("kB"))
    }

    func testFormattedFileSizeMB() {
        let pdfFile = createMockPDFFile(fileSize: 2_621_440)

        XCTAssertTrue(pdfFile.formattedFileSize.contains("MB"))
    }

    func testFormattedFileSizeGB() {
        let pdfFile = createMockPDFFile(fileSize: 1_610_612_736)

        XCTAssertTrue(pdfFile.formattedFileSize.contains("GB"))
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

    func testCompactRowDeleteCallbackInvokedWhenProvided() {
        let pdfFile = createMockPDFFile()
        var wasDeleted = false

        let row = PDFFileRowCompact(pdfFile: pdfFile, onDelete: { wasDeleted = true })

        XCTAssertNotNil(row.onDelete)

        row.onDelete?()
        XCTAssertTrue(wasDeleted)
    }
}
