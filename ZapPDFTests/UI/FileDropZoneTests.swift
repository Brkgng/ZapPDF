//
//  FileDropZoneTests.swift
//  ZapPDFTests
//
//  Unit tests for FileDropZone component.
//

import XCTest
import SwiftUI
import UniformTypeIdentifiers
@testable import ZapPDF

final class FileDropZoneTests: XCTestCase {

    func testDefaultProperties() {
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )

        XCTAssertTrue(dropZone.isEmpty)
        XCTAssertEqual(dropZone.acceptedTypes, [.pdf, .fileURL])
    }

    func testCustomAcceptedTypes() {
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        let customTypes: [UTType] = [.pdf, .image]

        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {},
            acceptedTypes: customTypes
        )

        XCTAssertEqual(dropZone.acceptedTypes, customTypes)
    }

    func testFilesDroppedCallback() {
        var isTargeted = false
        var droppedURLs: [URL] = []
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })

        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { urls in droppedURLs = urls },
            onPickerRequested: {}
        )

        let testURLs = [
            URL(fileURLWithPath: "/tmp/test1.pdf"),
            URL(fileURLWithPath: "/tmp/test2.pdf")
        ]
        dropZone.onFilesDropped(testURLs)

        XCTAssertEqual(droppedURLs.count, 2)
        XCTAssertEqual(droppedURLs[0].lastPathComponent, "test1.pdf")
        XCTAssertEqual(droppedURLs[1].lastPathComponent, "test2.pdf")
    }

    func testPickerRequestedCallback() {
        var isTargeted = false
        var pickerWasRequested = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })

        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: { pickerWasRequested = true }
        )

        dropZone.onPickerRequested()

        XCTAssertTrue(pickerWasRequested)
    }
}
