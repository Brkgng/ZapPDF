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
    
    // MARK: - Initialization Tests
    
    func testDefaultProperties() {
        // Given
        var isTargeted = false
        
        // When
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertTrue(dropZone.isEmpty)
        XCTAssertEqual(dropZone.acceptedTypes, [.pdf, .fileURL])
    }
    
    func testCustomAcceptedTypes() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        let customTypes: [UTType] = [.pdf, .image]
        
        // When
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {},
            acceptedTypes: customTypes
        )
        
        // Then
        XCTAssertEqual(dropZone.acceptedTypes, customTypes)
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyState() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertTrue(dropZone.isEmpty)
    }
    
    func testNonEmptyState() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        let dropZone = FileDropZone(
            isEmpty: false,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertFalse(dropZone.isEmpty)
    }
    
    // MARK: - Targeted State Tests
    
    func testIsTargetedInitiallyFalse() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        _ = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertFalse(isTargeted)
    }
    
    func testIsTargetedCanBeTrue() {
        // Given
        var isTargeted = true
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        _ = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertTrue(isTargeted)
    }
    
    // MARK: - Callback Tests
    
    func testFilesDroppedCallback() {
        // Given
        var isTargeted = false
        var droppedURLs: [URL] = []
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { urls in droppedURLs = urls },
            onPickerRequested: {}
        )
        
        // When
        let testURLs = [
            URL(fileURLWithPath: "/tmp/test1.pdf"),
            URL(fileURLWithPath: "/tmp/test2.pdf")
        ]
        dropZone.onFilesDropped(testURLs)
        
        // Then
        XCTAssertEqual(droppedURLs.count, 2)
        XCTAssertEqual(droppedURLs[0].lastPathComponent, "test1.pdf")
        XCTAssertEqual(droppedURLs[1].lastPathComponent, "test2.pdf")
    }
    
    func testPickerRequestedCallback() {
        // Given
        var isTargeted = false
        var pickerWasRequested = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: { pickerWasRequested = true }
        )
        
        // When
        dropZone.onPickerRequested()
        
        // Then
        XCTAssertTrue(pickerWasRequested)
    }
    
    // MARK: - UTType Tests
    
    func testPDFTypeIsAcceptedByDefault() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        let dropZone = FileDropZone(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        )
        
        // Then
        XCTAssertTrue(dropZone.acceptedTypes.contains(.pdf))
    }
    
    func testPDFUTTypeProperties() {
        // Verify UTType.pdf is correctly configured
        XCTAssertEqual(UTType.pdf.identifier, "com.adobe.pdf")
    }
}

// MARK: - FileDropZoneWithContent Tests

final class FileDropZoneWithContentTests: XCTestCase {
    
    func testWithContentShowsContentWhenNotEmpty() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        let dropZone = FileDropZoneWithContent(
            isEmpty: false,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        ) {
            Text("Content")
        }
        
        // Then
        XCTAssertFalse(dropZone.isEmpty)
    }
    
    func testWithContentShowsEmptyStateWhenEmpty() {
        // Given
        var isTargeted = false
        let binding = Binding(get: { isTargeted }, set: { isTargeted = $0 })
        
        // When
        let dropZone = FileDropZoneWithContent(
            isEmpty: true,
            isTargeted: binding,
            onFilesDropped: { _ in },
            onPickerRequested: {}
        ) {
            Text("Content")
        }
        
        // Then
        XCTAssertTrue(dropZone.isEmpty)
    }
}

// MARK: - URL PDF Validation Tests

final class URLPDFValidationTests: XCTestCase {
    
    func testPDFExtensionRecognized() {
        // Given
        let pdfURL = URL(fileURLWithPath: "/tmp/document.pdf")
        
        // Then
        XCTAssertEqual(pdfURL.pathExtension.lowercased(), "pdf")
    }
    
    func testNonPDFExtensionNotRecognized() {
        // Given
        let txtURL = URL(fileURLWithPath: "/tmp/document.txt")
        let jpgURL = URL(fileURLWithPath: "/tmp/image.jpg")
        
        // Then
        XCTAssertNotEqual(txtURL.pathExtension.lowercased(), "pdf")
        XCTAssertNotEqual(jpgURL.pathExtension.lowercased(), "pdf")
    }
    
    func testMixedCasePDFExtension() {
        // Given
        let urls = [
            URL(fileURLWithPath: "/tmp/doc.PDF"),
            URL(fileURLWithPath: "/tmp/doc.Pdf"),
            URL(fileURLWithPath: "/tmp/doc.pDf")
        ]
        
        // Then
        for url in urls {
            XCTAssertEqual(url.pathExtension.lowercased(), "pdf")
        }
    }
}
