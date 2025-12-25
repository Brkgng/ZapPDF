//
//  PDFSplitterTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFSplitter.
//

import Testing
import Foundation
import PDFKit
@testable import ZapPDF

@Suite("PDFSplitter Tests")
struct PDFSplitterTests {
    
    // MARK: - Split Mode Tests
    
    @Test("Splits file by page range")
    func splitsFileByPageRange() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "range_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        
        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .byPageRange(ranges: [2...4]),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }
        
        // Should produce one file
        #expect(outputURLs.count == 1)
        
        // Output should have 3 pages (pages 2, 3, 4)
        let document = PDFDocument(url: outputURLs[0])
        #expect(document?.pageCount == 3)
    }
    
    @Test("Splits file every N pages")
    func splitsFileEveryNPages() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 10, identifier: "every_n_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 10, fileSize: 1000)
        
        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .splitEvery(n: 3),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }
        
        // Should produce 4 files: 3+3+3+1
        #expect(outputURLs.count == 4)
        
        // Verify page counts
        let doc1 = PDFDocument(url: outputURLs[0])
        let doc2 = PDFDocument(url: outputURLs[1])
        let doc3 = PDFDocument(url: outputURLs[2])
        let doc4 = PDFDocument(url: outputURLs[3])
        
        #expect(doc1?.pageCount == 3)
        #expect(doc2?.pageCount == 3)
        #expect(doc3?.pageCount == 3)
        #expect(doc4?.pageCount == 1)
    }
    
    @Test("Extracts specific pages")
    func extractsSpecificPages() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "extract_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        
        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .extractPages(indices: [1, 3, 5]),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }
        
        // Should produce one file with 3 pages
        #expect(outputURLs.count == 1)
        
        let document = PDFDocument(url: outputURLs[0])
        #expect(document?.pageCount == 3)
    }
    
    @Test("Invalid range throws error")
    func invalidRangeThrowsError() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "invalid_range_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        
        let splitter = PDFSplitter()
        
        // Request pages beyond document length
        await #expect(throws: PDFEngineError.self) {
            _ = try await splitter.split(
                file: file,
                mode: .byPageRange(ranges: [3...10]),
                progress: { _ in }
            )
        }
    }
    
    @Test("Reports progress during split")
    func reportsProgressDuringSplit() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 9, identifier: "progress_split_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 9, fileSize: 1000)
        
        let splitter = PDFSplitter()
        var progressValues: [Double] = []
        
        let outputURLs = try await splitter.split(
            file: file,
            mode: .splitEvery(n: 3),
            progress: { progress in
                progressValues.append(progress)
            }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }
        
        // Should have progress updates
        #expect(!progressValues.isEmpty)
        
        // Progress should be increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
        
        // Final should be 1.0
        #expect(progressValues.last == 1.0)
    }
}
