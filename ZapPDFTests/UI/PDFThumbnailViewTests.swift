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

    func testInitializerStoresDefaultsAndOverrides() {
        let pdfFile = createMockPDFFile()

        let defaultView = PDFThumbnailView(pdfFile: pdfFile)
        XCTAssertEqual(defaultView.size, CGSize(width: 120, height: 160))
        XCTAssertTrue(defaultView.showPageCount)
        XCTAssertEqual(defaultView.cornerRadius, 8)

        let customSize = CGSize(width: 200, height: 280)
        let customView = PDFThumbnailView(
            pdfFile: pdfFile,
            size: customSize,
            showPageCount: false,
            cornerRadius: 12
        )
        XCTAssertEqual(customView.size, customSize)
        XCTAssertFalse(customView.showPageCount)
        XCTAssertEqual(customView.cornerRadius, 12)
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
        let count = await renderer.cacheCount
        XCTAssertEqual(count, 0)
    }

    func testClearCache() async {
        await renderer.clearCache()
        let count = await renderer.cacheCount
        XCTAssertEqual(count, 0)
    }

    func testThumbnailReturnsNilForInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")

        let thumbnail = await renderer.thumbnail(
            for: invalidURL,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )

        XCTAssertNil(thumbnail)
    }

    func testThumbnailReturnsNilForNonPDFFile() async {
        let textFileURL = URL(fileURLWithPath: "/tmp/test.txt")

        let thumbnail = await renderer.thumbnail(
            for: textFileURL,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )

        XCTAssertNil(thumbnail)
    }
}
