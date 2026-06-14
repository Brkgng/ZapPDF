//
//  PDFReordererTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFReorderer.
//

import Testing
import Foundation
import PDFKit
@testable import ZapPDF

@Suite("PDFReorderer Tests")
struct PDFReordererTests {
    
    // MARK: - Validation Tests
    
    @Test("validateOrder returns true for valid order")
    func validateOrderReturnsTrueForValidOrder() {
        #expect(PDFReorderer.validateOrder([0, 1, 2, 3], pageCount: 4) == true)
        #expect(PDFReorderer.validateOrder([3, 2, 1, 0], pageCount: 4) == true)
        #expect(PDFReorderer.validateOrder([2, 0, 3, 1], pageCount: 4) == true)
    }
    
    @Test("validateOrder handles page deletion (fewer pages)")
    func validateOrderHandlesPageDeletion() {
        // Fewer pages than total is VALID (deletion)
        #expect(PDFReorderer.validateOrder([0, 1, 2], pageCount: 4) == true)
        
        // More pages than total is INVALID
        #expect(PDFReorderer.validateOrder([0, 1, 2, 3, 4], pageCount: 4) == false)
    }
    
    @Test("validateOrder returns false for out of range indices")
    func validateOrderReturnsFalseForOutOfRangeIndices() {
        #expect(PDFReorderer.validateOrder([0, 1, 5], pageCount: 3) == false)
        #expect(PDFReorderer.validateOrder([-1, 0, 1], pageCount: 3) == false)
    }
    
    @Test("validateOrder returns false for duplicate indices")
    func validateOrderReturnsFalseForDuplicateIndices() {
        #expect(PDFReorderer.validateOrder([0, 1, 1, 3], pageCount: 4) == false)
        #expect(PDFReorderer.validateOrder([0, 0, 0, 0], pageCount: 4) == false)
    }
    
    @Test("validateOrder handles empty arrays")
    func validateOrderHandlesEmptyArrays() {
        // Empty order is always invalid, even for empty document
        #expect(PDFReorderer.validateOrder([], pageCount: 0) == false)
        #expect(PDFReorderer.validateOrder([], pageCount: 5) == false)
    }
    
    @Test("validateOrder handles single page")
    func validateOrderHandlesSinglePage() {
        #expect(PDFReorderer.validateOrder([0], pageCount: 1) == true)
        #expect(PDFReorderer.validateOrder([1], pageCount: 1) == false)
    }
    
    // MARK: - hasOrderChanged Tests
    
    @Test("hasOrderChanged returns false for sequential order")
    func hasOrderChangedReturnsFalseForSequentialOrder() {
        #expect(PDFReorderer.hasOrderChanged([0, 1, 2, 3]) == false)
        #expect(PDFReorderer.hasOrderChanged([0]) == false)
        #expect(PDFReorderer.hasOrderChanged([]) == false)
    }
    
    @Test("hasOrderChanged returns true for non-sequential order")
    func hasOrderChangedReturnsTrueForNonSequentialOrder() {
        #expect(PDFReorderer.hasOrderChanged([1, 0, 2, 3]) == true)
        #expect(PDFReorderer.hasOrderChanged([3, 2, 1, 0]) == true)
        #expect(PDFReorderer.hasOrderChanged([0, 1, 3, 2]) == true)
    }
    
    // MARK: - Reorder Operation Tests
    
    @Test("Reorders pages in reverse order")
    func reordersPagesInReverseOrder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "reverse_order_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [3, 2, 1, 0],
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify output exists
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        
        // Verify page count
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 4)
    }
    
    @Test("Reorders pages swapping first two")
    func reordersPagesSwappingFirstTwo() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "swap_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [1, 0, 2],
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify output exists
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        
        // Verify page count preserved
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 3)
    }
    
    @Test("Preserves unchanged order")
    func preservesUnchangedOrder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "unchanged_order_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [0, 1, 2, 3, 4],
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify page count
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 5)
    }
    
    @Test("Reports progress during reorder")
    func reportsProgressDuringReorder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "progress_reorder_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        var progressValues: [Double] = []
        
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [3, 2, 1, 0],
            progress: { progress in
                progressValues.append(progress)
            }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Should have progress updates
        #expect(!progressValues.isEmpty)
        
        // Progress should be increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
        
        // Should include a finalizing-stage progress update before completion.
        #expect(progressValues.contains { $0 >= PDFProgressPolicy.finalizingStart && $0 < 1.0 })
        
        // Final should be 1.0
        #expect(progressValues.last == 1.0)
    }
    
    @Test("Custom output filename is used")
    func customOutputFilenameIsUsed() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "custom_name_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 2, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [1, 0],
            outputFileName: "my_custom_name",
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        #expect(outputURL.lastPathComponent == "my_custom_name.pdf")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Empty order throws error")
    func emptyOrderThrowsError() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "empty_order_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        
        let reorderer = PDFReorderer()
        
        do {
            _ = try await reorderer.reorder(file: file, newOrder: [], progress: { _ in })
            Issue.record("Should have thrown emptyInput")
        } catch PDFEngineError.emptyInput {
            // Expected
        } catch {
            Issue.record("Expected .emptyInput but got: \(error)")
        }
    }
    
    @Test("Invalid order throws error")
    func invalidOrderThrowsError() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "invalid_order_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        
        let reorderer = PDFReorderer()

        let invalidOrders: [[Int]] = [
            [0, 99],    // Out of bounds index
            [0, 0, 1],  // Duplicate index
            [0, 1, 2, 0] // Too many pages
        ]

        for order in invalidOrders {
            do {
                _ = try await reorderer.reorder(file: file, newOrder: order, progress: { _ in })
                Issue.record("Should have thrown invalidPageRange for order \(order)")
            } catch PDFEngineError.invalidPageRange {
                // Expected
            } catch {
                Issue.record("Expected .invalidPageRange but got: \(error)")
            }
        }
    }
    
    // MARK: - Large Document Tests
    
    @Test("Handles large document")
    func handlesLargeDocument() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 50, identifier: "large_doc_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "large.pdf", pageCount: 50, fileSize: 10000)
        
        // Reverse order for 50 pages
        let newOrder = Array((0..<50).reversed())
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: newOrder,
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify page count
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 50)
    }
    
    @Test("Single page document reorder is no-op")
    func singlePageDocumentReorderIsNoOp() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "single_page_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "single.pdf", pageCount: 1, fileSize: 100)
        
        let reorderer = PDFReorderer()
        let outputURL = try await reorderer.reorder(
            file: file,
            newOrder: [0],
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 1)
    }

    // MARK: - Corrupt / Locked File Tests

    @Test("Corrupt and empty files throw error")
    func corruptFilesThrowError() async throws {
        let id = UUID().uuidString
        let fixtures: [(label: String, url: URL)] = try [
            ("garbage",   PDFTestHelpers.createGarbagePDF(identifier: "reorder_garbage_\(id)")),
            ("empty",     PDFTestHelpers.createEmptyPDF(identifier: "reorder_empty_\(id)")),
            ("truncated", PDFTestHelpers.createTruncatedPDF(identifier: "reorder_trunc_\(id)"))
        ]
        defer { fixtures.forEach { PDFTestHelpers.cleanup(url: $0.url) } }

        let reorderer = PDFReorderer()

        for fixture in fixtures {
            // pageCount: 1 + newOrder: [0] passes validation, so the engine
            // reaches the file-open stage where corrupt input is detected.
            let file = PDFFile(url: fixture.url, fileName: "\(fixture.label).pdf", pageCount: 1, fileSize: 100)
            await #expect(throws: PDFEngineError.self) {
                _ = try await reorderer.reorder(file: file, newOrder: [0], progress: { _ in })
            }
        }
    }

    @Test("Password-protected PDF throws passwordProtected")
    func lockedPDFThrowsPasswordProtected() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createLockedPDF(identifier: "reorder_locked_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: "locked.pdf", pageCount: 3, fileSize: 1000)
        let reorderer = PDFReorderer()

        do {
            _ = try await reorderer.reorder(file: file, newOrder: [0, 1, 2], progress: { _ in })
            Issue.record("Should have thrown passwordProtected")
        } catch PDFEngineError.passwordProtected {
            // Expected
        } catch {
            Issue.record("Expected .passwordProtected but got: \(error)")
        }
    }
}
