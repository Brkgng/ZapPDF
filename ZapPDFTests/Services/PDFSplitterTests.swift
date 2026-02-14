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

    @Test("Uses page-aware names for split every N")
    func usesPageAwareNamesForSplitEveryN() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 10, identifier: "naming_split_every")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: url.lastPathComponent, pageCount: 10, fileSize: 1000)

        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .splitEvery(n: 3),
            includeTimestamp: false,
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }

        let stems = outputURLs.map { $0.deletingPathExtension().lastPathComponent }
        let baseName = url.deletingPathExtension().lastPathComponent

        #expect(stems.count == 4)
        #expect(stems[0] == "\(baseName)_p1-3")
        #expect(stems[1] == "\(baseName)_p4-6")
        #expect(stems[2] == "\(baseName)_p7-9")
        #expect(stems[3] == "\(baseName)_p10")
    }

    @Test("Uses a shared timestamp across outputs")
    func usesSharedTimestampAcrossOutputs() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 8, identifier: "naming_shared_timestamp")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: url.lastPathComponent, pageCount: 8, fileSize: 1000)

        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .splitEvery(n: 2),
            includeTimestamp: true,
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }

        var timestamps = Set<String>()
        for url in outputURLs {
            let stem = url.deletingPathExtension().lastPathComponent
            guard let match = stem.range(of: "\\d{6}_\\d{6}$", options: .regularExpression) else {
                Issue.record("Expected timestamp at end of filename stem: \(stem)")
                continue
            }
            timestamps.insert(String(stem[match]))
        }

        #expect(timestamps.count == 1)
    }

    @Test("Appends duplicate suffix for repeated page tokens")
    func appendsDuplicateSuffixForRepeatedPageTokens() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 6, identifier: "naming_duplicates")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: url.lastPathComponent, pageCount: 6, fileSize: 1000)

        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .byPageRange(ranges: [1...3, 1...3]),
            includeTimestamp: false,
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }

        let stems = outputURLs.map { $0.deletingPathExtension().lastPathComponent }
        let baseName = url.deletingPathExtension().lastPathComponent
        #expect(stems == ["\(baseName)_p1-3", "\(baseName)_p1-3_2"])
    }

    @Test("Uses compressed token when extracting specific pages")
    func usesCompressedTokenForExtractedPages() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 9, identifier: "naming_extract_pages")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: url.lastPathComponent, pageCount: 9, fileSize: 1000)

        let splitter = PDFSplitter()
        let outputURLs = try await splitter.split(
            file: file,
            mode: .extractPages(indices: [1, 3, 5, 9]),
            includeTimestamp: false,
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(urls: outputURLs) }

        let stem = outputURLs[0].deletingPathExtension().lastPathComponent
        let baseName = url.deletingPathExtension().lastPathComponent
        #expect(stem == "\(baseName)_p1_3_5_9")
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
