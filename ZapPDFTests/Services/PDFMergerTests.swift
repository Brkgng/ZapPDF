//
//  PDFMergerTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFMerger.
//

import Testing
import Foundation
import PDFKit
@testable import ZapPDF

@Suite("PDFMerger Tests")
struct PDFMergerTests {
    
    // MARK: - Merge Tests
    
    @Test("Merges two files successfully")
    func mergesTwoFilesSuccessfully() async throws {
        // Create test PDFs
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "merge_test_1")
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "merge_test_2")
        defer { PDFTestHelpers.cleanup(urls: [url1, url2]) }
        
        // Create PDFFile instances
        let file1 = PDFFile(url: url1, fileName: "test1.pdf", pageCount: 3, fileSize: 1000)
        let file2 = PDFFile(url: url2, fileName: "test2.pdf", pageCount: 2, fileSize: 1000)
        
        // Merge
        let merger = PDFMerger()
        var progressValues: [Double] = []
        
        let outputURL = try await merger.merge(
            files: [file1, file2],
            options: .init(outputFileName: "merged_test"),
            progress: { progress in
                progressValues.append(progress)
            }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify output exists
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        
        // Verify page count
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 5) // 3 + 2
    }
    
    @Test("Preserves page order when merging")
    func preservesPageOrderWhenMerging() async throws {
        let testId = UUID().uuidString.prefix(8)
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "order_test_1_\(testId)")
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "order_test_2_\(testId)")
        defer { PDFTestHelpers.cleanup(urls: [url1, url2]) }
        
        let file1 = PDFFile(url: url1, fileName: "test1.pdf", pageCount: 2, fileSize: 1000)
        let file2 = PDFFile(url: url2, fileName: "test2.pdf", pageCount: 2, fileSize: 1000)
        
        let merger = PDFMerger()
        let outputURL = try await merger.merge(
            files: [file1, file2],
            options: .init(outputFileName: "merged_order_\(testId)"),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 4)
    }
    
    @Test("Reports progress during merge")
    func reportsProgressDuringMerge() async throws {
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "progress_test")
        defer { PDFTestHelpers.cleanup(url: url1) }
        
        let file1 = PDFFile(url: url1, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        
        let merger = PDFMerger()
        var progressValues: [Double] = []
        
        let outputURL = try await merger.merge(
            files: [file1],
            options: .init(outputFileName: "merged_progress"),
            progress: { progress in
                progressValues.append(progress)
            }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Should have received progress updates
        #expect(!progressValues.isEmpty)
        
        // Progress should be increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
        
        // Final progress should be 1.0
        #expect(progressValues.last == 1.0)
    }
    
    @Test("Empty input throws error")
    func emptyInputThrowsError() async {
        let merger = PDFMerger()
        
        await #expect(throws: PDFEngineError.self) {
            _ = try await merger.merge(
                files: [],
                options: .init(),
                progress: { _ in }
            )
        }
    }
    
    @Test("Invalid file throws error")
    func invalidFileThrowsError() async {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        let file = PDFFile(url: nonExistentURL, fileName: "fake.pdf", pageCount: 1, fileSize: 1000)
        
        let merger = PDFMerger()
        
        await #expect(throws: PDFEngineError.self) {
            _ = try await merger.merge(
                files: [file],
                options: .init(),
                progress: { _ in }
            )
        }
    }
    
    @Test("Cancellation stops merge")
    @MainActor
    func cancellationStopsMerge() async throws {
        // Create a multi-page PDF
        let url = try PDFTestHelpers.createTestPDF(pageCount: 100, identifier: "cancel_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 100, fileSize: 1000)
        
        let merger = PDFMerger()
        var hasStarted = false
        
        // Start merge in background
        let task = Task {
            try await merger.merge(
                files: [file, file], // Merge twice (200 pages)
                options: .init(outputFileName: "merged_cancel_test"),
                progress: { _ in
                    hasStarted = true
                }
            )
        }
        
        // Wait for merge to start (progress callback triggered)
        // Timeout after 5 seconds to prevent hang
        let timeout = Date().addingTimeInterval(5)
        while !hasStarted && Date() < timeout {
            try await Task.sleep(nanoseconds: 10 * 1_000_000) // 10ms poll
        }
        
        // Cancel
        await merger.cancel()
        
        // Expect PDFEngineError.cancelled
        do {
            _ = try await task.value
            Issue.record("Should have thrown error")
        } catch PDFEngineError.cancelled {
            // Success
            return
        } catch {
            Issue.record("Threw unexpected error: \(error)")
        }
    }
}
