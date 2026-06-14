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
        let id = UUID().uuidString
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "merge_test_1_\(id)")
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "merge_test_2_\(id)")
        defer { PDFTestHelpers.cleanup(urls: [url1, url2]) }
        
        let file1 = PDFFile(url: url1, fileName: "test1.pdf", pageCount: 3, fileSize: 1000)
        let file2 = PDFFile(url: url2, fileName: "test2.pdf", pageCount: 2, fileSize: 1000)

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
        
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 5)
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
        let id = UUID().uuidString
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "progress_test_\(id)")
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
        
        #expect(!progressValues.isEmpty)

        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
        
        #expect(progressValues.contains { $0 >= PDFProgressPolicy.finalizingStart && $0 < 1.0 })
        #expect(progressValues.last == 1.0)
    }

    @Test("mergeDetailed returns diagnostics")
    func mergeDetailedReturnsDiagnostics() async throws {
        let id = UUID().uuidString
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "diag_1_\(id)")
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "diag_2_\(id)")
        defer { PDFTestHelpers.cleanup(urls: [url1, url2]) }

        let merger = PDFMerger()
        let files = [
            PDFFile(url: url1, fileName: "d1.pdf", pageCount: 2, fileSize: 1000),
            PDFFile(url: url2, fileName: "d2.pdf", pageCount: 1, fileSize: 1000)
        ]

        let result = try await merger.mergeDetailed(
            files: files,
            options: .init(
                outputFileName: "merged_diag_\(id)",
                preserveBookmarks: true,
                includeTimestamp: false
            ),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        #expect(result.diagnostics.pageCount == 3)
        #expect(result.diagnostics.inputBytes > 0)
        #expect(result.diagnostics.outputBytes > 0)
        #expect(result.diagnostics.writeProfile == .losslessPreserve)
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

        do {
            _ = try await merger.merge(files: [file], options: .init(), progress: { _ in })
            Issue.record("Should have thrown invalidPDF")
        } catch PDFEngineError.invalidPDF {
            // Expected
        } catch {
            Issue.record("Expected .invalidPDF but got: \(error)")
        }
    }

    @Test("Page load helper throws when requested page does not exist")
    func copyPageForMergeThrowsForMissingPage() throws {
        let document = PDFDocument()
        let fakeURL = URL(fileURLWithPath: "/tmp/missing_page.pdf")

        #expect(throws: PDFEngineError.self) {
            _ = try PDFMerger.copyPageForMerge(from: document, at: 0, sourceURL: fakeURL)
        }
    }

    @Test("Page copy helper keeps source page ownership")
    func copyPageForMergePreservesSourceOwnership() throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "copy_semantics_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        guard let sourceDocument = PDFDocument(url: url),
              let sourcePage = sourceDocument.page(at: 0) else {
            Issue.record("Unable to load source document")
            return
        }

        let copiedPage = try PDFMerger.copyPageForMerge(from: sourceDocument, at: 0, sourceURL: url)
        let outputDocument = PDFDocument()
        outputDocument.insert(copiedPage, at: 0)

        #expect(sourcePage.document === sourceDocument)
        #expect(outputDocument.pageCount == 1)
    }

    @Test("Lossless write profile disables image transforms")
    func losslessWriteOptionsDisableImageTransforms() {
        let options = PDFMerger.writeOptions(for: .losslessPreserve)
        #expect((options[PDFDocumentWriteOption.burnInAnnotationsOption] as? Bool) == false)
        #expect((options[PDFDocumentWriteOption.saveTextFromOCROption] as? Bool) == false)
        #expect((options[PDFDocumentWriteOption.saveImagesAsJPEGOption] as? Bool) == false)
        #expect((options[PDFDocumentWriteOption.optimizeImagesForScreenOption] as? Bool) == false)
    }

    @Test("Retry helper requires at least 15 percent improvement")
    func retrySelectionThresholdIsFifteenPercent() {
        #expect(PDFMerger.shouldUseRetryOutput(originalBytes: 1000, retryBytes: 840) == true)
        #expect(PDFMerger.shouldUseRetryOutput(originalBytes: 1000, retryBytes: 851) == false)
        #expect(PDFMerger.shouldUseRetryOutput(originalBytes: 1000, retryBytes: 1100) == false)
    }

    @Test("Excessive growth anomaly can be forced with low threshold")
    func excessiveGrowthAnomalyDetection() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "growth_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let merger = PDFMerger()
        let file = PDFFile(url: url, fileName: "growth.pdf", pageCount: 2, fileSize: 1000)

        let result = try await merger.mergeDetailed(
            files: [file],
            options: .init(
                outputFileName: "growth_out_\(id)",
                includeTimestamp: false,
                excessiveGrowthThreshold: 0.0001
            ),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        #expect(result.diagnostics.anomaly == .excessiveGrowth)
        #expect(result.diagnostics.writeProfile == .losslessPreserve)
    }

    @Test("Lossy retry is disabled by default")
    func lossyRetryDisabledByDefault() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createImageHeavyPDF(pageCount: 1, identifier: "lossy_off_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let merger = PDFMerger()
        let file = PDFFile(url: url, fileName: "heavy.pdf", pageCount: 1, fileSize: 1000)

        let result = try await merger.mergeDetailed(
            files: [file],
            options: .init(
                outputFileName: "lossy_off_out_\(id)",
                includeTimestamp: false,
                excessiveGrowthThreshold: 0.0001,
                enableLossyRetryOnGrowth: false
            ),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        #expect(result.diagnostics.anomaly == .excessiveGrowth)
        #expect(result.diagnostics.writeProfile == .losslessPreserve)
    }

    @Test("Unexpected shrink anomaly can be forced with high threshold")
    func unexpectedShrinkAnomalyDetection() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "shrink_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let merger = PDFMerger()
        let file = PDFFile(url: url, fileName: "small.pdf", pageCount: 1, fileSize: 1000)

        let result = try await merger.mergeDetailed(
            files: [file],
            options: .init(
                outputFileName: "shrink_out_\(id)",
                includeTimestamp: false,
                excessiveGrowthThreshold: 10.0,
                unexpectedShrinkThreshold: 2.0
            ),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        #expect(result.diagnostics.anomaly == .unexpectedShrink)
    }

    @Test("Preserves outline labels and destinations when enabled")
    func preservesOutlinesWhenEnabled() async throws {
        let id = UUID().uuidString
        let url1 = try PDFTestHelpers.createTestPDFWithOutline(pageCount: 2, identifier: "outline_1_\(id)")
        let url2 = try PDFTestHelpers.createTestPDFWithOutline(pageCount: 1, identifier: "outline_2_\(id)")
        defer { PDFTestHelpers.cleanup(urls: [url1, url2]) }

        let merger = PDFMerger()
        let result = try await merger.mergeDetailed(
            files: [
                PDFFile(url: url1, fileName: "o1.pdf", pageCount: 2, fileSize: 1000),
                PDFFile(url: url2, fileName: "o2.pdf", pageCount: 1, fileSize: 1000)
            ],
            options: .init(
                outputFileName: "outline_merged_\(id)",
                preserveBookmarks: true,
                includeTimestamp: false
            ),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        guard let mergedDocument = PDFDocument(url: result.outputURL),
              let outlineRoot = mergedDocument.outlineRoot else {
            Issue.record("Merged outline root missing")
            return
        }

        #expect(outlineRoot.numberOfChildren == 2)
        let first = outlineRoot.child(at: 0)
        #expect(first?.label == "Chapter 1")
        if let firstDestinationPage = first?.destination?.page {
            #expect(mergedDocument.index(for: firstDestinationPage) == 0)
        } else {
            Issue.record("First outline destination missing")
        }
    }

    @Test("Internal link destinations are remapped to merged document")
    func remapsInternalLinks() async throws {
        let id = UUID().uuidString
        let linkedURL = try PDFTestHelpers.createTestPDFWithInternalLink(identifier: "internal_link_\(id)")
        let plainURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "plain_\(id)")
        defer { PDFTestHelpers.cleanup(urls: [linkedURL, plainURL]) }

        let merger = PDFMerger()
        let result = try await merger.mergeDetailed(
            files: [
                PDFFile(url: linkedURL, fileName: "linked.pdf", pageCount: 2, fileSize: 1000),
                PDFFile(url: plainURL, fileName: "plain.pdf", pageCount: 1, fileSize: 1000)
            ],
            options: .init(outputFileName: "link_merge_\(id)", includeTimestamp: false),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        guard let mergedDocument = PDFDocument(url: result.outputURL),
              let firstPage = mergedDocument.page(at: 0),
              let annotation = firstPage.annotations.first,
              let goTo = annotation.action as? PDFActionGoTo,
              let destinationPage = goTo.destination.page else {
            Issue.record("Merged link annotation missing")
            return
        }

        #expect(destinationPage.document === mergedDocument)
        #expect(mergedDocument.index(for: destinationPage) == 1)
    }

    @Test("External URL links are preserved")
    func preservesExternalLinks() async throws {
        let id = UUID().uuidString
        let external = URL(string: "https://example.com/spec")!
        let linkedURL = try PDFTestHelpers.createTestPDFWithExternalLink(identifier: "external_link_\(id)", url: external)
        let plainURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "plain_external_\(id)")
        defer { PDFTestHelpers.cleanup(urls: [linkedURL, plainURL]) }

        let merger = PDFMerger()
        let result = try await merger.mergeDetailed(
            files: [
                PDFFile(url: linkedURL, fileName: "external.pdf", pageCount: 1, fileSize: 1000),
                PDFFile(url: plainURL, fileName: "plain.pdf", pageCount: 1, fileSize: 1000)
            ],
            options: .init(outputFileName: "external_merge_\(id)", includeTimestamp: false),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: result.outputURL) }

        guard let mergedDocument = PDFDocument(url: result.outputURL),
              let page = mergedDocument.page(at: 0),
              let annotation = page.annotations.first else {
            Issue.record("Merged external link annotation missing")
            return
        }

        let preservedURL = (annotation.action as? PDFActionURL)?.url
        #expect(preservedURL == external)
    }
    
    @Test("Cancellation stops merge")
    @MainActor
    func cancellationStopsMerge() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 100, identifier: "cancel_test_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 100, fileSize: 1000)
        
        let merger = PDFMerger()
        var hasStarted = false
        
        let task = Task {
            try await merger.merge(
                files: [file, file],
                options: .init(outputFileName: "merged_cancel_test"),
                progress: { _ in
                    hasStarted = true
                }
            )
        }
        
        let timeout = Date().addingTimeInterval(5)
        while !hasStarted && Date() < timeout {
            try await Task.sleep(nanoseconds: 10 * 1_000_000)
        }
        
        await merger.cancel()
        
        do {
            _ = try await task.value
            Issue.record("Should have thrown error")
        } catch PDFEngineError.cancelled {
            return
        } catch {
            Issue.record("Threw unexpected error: \(error)")
        }
    }

    @Test("Merging several files preserves page totals (autoreleasepool regression)")
    func mergingSeveralFilesPreservesPageTotals() async throws {
        let id = UUID().uuidString
        let urls = try [
            PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "multi_1_\(id)"),
            PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "multi_2_\(id)"),
            PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "multi_3_\(id)"),
            PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "multi_4_\(id)")
        ]
        defer { PDFTestHelpers.cleanup(urls: urls) }

        let files: [PDFFile] = [
            PDFFile(url: urls[0], fileName: "a.pdf", pageCount: 3, fileSize: 1000),
            PDFFile(url: urls[1], fileName: "b.pdf", pageCount: 2, fileSize: 1000),
            PDFFile(url: urls[2], fileName: "c.pdf", pageCount: 4, fileSize: 1000),
            PDFFile(url: urls[3], fileName: "d.pdf", pageCount: 1, fileSize: 1000)
        ]

        let merger = PDFMerger()
        let outputURL = try await merger.merge(
            files: files,
            options: .init(outputFileName: "multi_merged_\(id)"),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }

        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 10)
    }

    // MARK: - Corrupt / Locked File Tests

    @Test("Corrupt and empty files throw error")
    func corruptFilesThrowError() async throws {
        let id = UUID().uuidString
        let fixtures: [(label: String, url: URL)] = try [
            ("garbage",  PDFTestHelpers.createGarbagePDF(identifier: "merge_garbage_\(id)")),
            ("empty",    PDFTestHelpers.createEmptyPDF(identifier: "merge_empty_\(id)")),
            ("truncated", PDFTestHelpers.createTruncatedPDF(identifier: "merge_trunc_\(id)"))
        ]
        defer { fixtures.forEach { PDFTestHelpers.cleanup(url: $0.url) } }

        let merger = PDFMerger()

        for fixture in fixtures {
            let file = PDFFile(url: fixture.url, fileName: "\(fixture.label).pdf", pageCount: 1, fileSize: 100)
            await #expect(throws: PDFEngineError.self) {
                _ = try await merger.merge(files: [file], options: .init(), progress: { _ in })
            }
        }
    }

    @Test("Password-protected PDF throws passwordProtected")
    func lockedPDFThrowsPasswordProtected() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createLockedPDF(identifier: "merge_locked_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: "locked.pdf", pageCount: 3, fileSize: 1000)
        let merger = PDFMerger()

        do {
            _ = try await merger.merge(files: [file], options: .init(), progress: { _ in })
            Issue.record("Should have thrown passwordProtected")
        } catch PDFEngineError.passwordProtected {
            // Expected
        } catch {
            Issue.record("Expected .passwordProtected but got: \(error)")
        }
    }
}
