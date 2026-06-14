//
//  PDFFlattenerTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFFlattener.
//

import Testing
import Foundation
import PDFKit
@testable import ZapPDF

@Suite("PDFFlattener Tests")
struct PDFFlattenerTests {
    
    // MARK: - Flatten Tests
    
    @Test("Flattens PDF successfully")
    func flattensPDFSuccessfully() async throws {
        // Create test PDF
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "flatten_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        // Create PDFFile instance
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        
        // Flatten
        let flattener = PDFFlattener()
        var progressValues: [Double] = []
        
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(outputFileName: "flattened_test"),
            progress: { progress in
                progressValues.append(progress)
            }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify output exists
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        
        // Verify page count preserved
        let document = PDFDocument(url: outputURL)
        #expect(document?.pageCount == 3)
    }
    
    @Test("Reports progress during flatten")
    func reportsProgressDuringFlatten() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "flatten_progress_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        
        let flattener = PDFFlattener()
        var progressValues: [Double] = []
        
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(outputFileName: "flattened_progress"),
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
        
        // Should include a finalizing-stage progress update before completion.
        #expect(progressValues.contains { $0 >= PDFProgressPolicy.finalizingStart && $0 < 1.0 })
        
        // Final progress should be 1.0
        #expect(progressValues.last == 1.0)
    }
    
    @Test("Generates output filename with timestamp")
    func generatesOutputFilenameWithTimestamp() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "flatten_filename_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 1, fileSize: 1000)
        
        let flattener = PDFFlattener()
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(includeTimestamp: true),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Filename should contain "flattened" and a timestamp
        let filename = outputURL.deletingPathExtension().lastPathComponent
        #expect(filename.contains("flattened"))
    }
    
    @Test("Uses custom output filename")
    func usesCustomOutputFilename() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "flatten_custom_name_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 1, fileSize: 1000)
        
        let flattener = PDFFlattener()
        let customName = "my_custom_flattened_document"
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(outputFileName: customName, includeTimestamp: false),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Filename should be the custom name
        let filename = outputURL.deletingPathExtension().lastPathComponent
        #expect(filename == customName)
    }
    
    @Test("Invalid file throws error")
    func invalidFileThrowsError() async {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        let file = PDFFile(url: nonExistentURL, fileName: "fake.pdf", pageCount: 1, fileSize: 1000)
        
        let flattener = PDFFlattener()

        do {
            _ = try await flattener.flatten(file: file, options: .init(), progress: { _ in })
            Issue.record("Should have thrown invalidPDF")
        } catch PDFEngineError.invalidPDF {
            // Expected
        } catch {
            Issue.record("Expected .invalidPDF but got: \(error)")
        }
    }
    
    @Test("Cancellation stops flatten")
    @MainActor
    func cancellationStopsFlatten() async throws {
        // Create a multi-page PDF
        let url = try PDFTestHelpers.createTestPDF(pageCount: 100, identifier: "flatten_cancel_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 100, fileSize: 1000)
        
        let flattener = PDFFlattener()
        var hasStarted = false
        
        // Clean any stale partial outputs from prior runs before asserting cleanup later
        Self.removeLeftoverOutputs(matching: "flattened_cancel_test")
        
        // Start flatten in background
        let task = Task {
            try await flattener.flatten(
                file: file,
                options: .init(outputFileName: "flattened_cancel_test"),
                progress: { _ in
                    hasStarted = true
                }
            )
        }
        
        // Wait for flatten to start (progress callback triggered)
        // Timeout after 5 seconds to prevent hang
        let timeout = Date().addingTimeInterval(5)
        while !hasStarted && Date() < timeout {
            try await Task.sleep(nanoseconds: 10 * 1_000_000) // 10ms poll
        }
        
        // Cancel
        await flattener.cancel()
        
        // Expect PDFEngineError.cancelled
        do {
            _ = try await task.value
            Issue.record("Should have thrown error")
        } catch PDFEngineError.cancelled {
            // Partial output must be cleaned up; no file should linger in temp dir
            let leftovers = Self.leftoverOutputs(matching: "flattened_cancel_test")
            #expect(leftovers.isEmpty, "Partial output should be cleaned up after cancellation, found: \(leftovers)")
            return
        } catch {
            Issue.record("Threw unexpected error: \(error)")
        }
    }
    
    @Test("Preserves page dimensions")
    func preservesPageDimensions() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "flatten_dimensions_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        // Get original dimensions
        guard let originalDoc = PDFDocument(url: url),
              let originalPage = originalDoc.page(at: 0) else {
            Issue.record("Failed to load original PDF")
            return
        }
        let originalBounds = originalPage.bounds(for: .mediaBox)
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 2, fileSize: 1000)
        
        let flattener = PDFFlattener()
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(outputFileName: "flattened_dimensions"),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify dimensions preserved
        guard let flattenedDoc = PDFDocument(url: outputURL),
              let flattenedPage = flattenedDoc.page(at: 0) else {
            Issue.record("Failed to load flattened PDF")
            return
        }
        let flattenedBounds = flattenedPage.bounds(for: .mediaBox)
        
        // Dimensions should match (with some tolerance for rounding)
        #expect(abs(originalBounds.width - flattenedBounds.width) < 1.0)
        #expect(abs(originalBounds.height - flattenedBounds.height) < 1.0)
    }
    
    @Test("Removes annotations after flattening")
    func removesAnnotationsAfterFlattening() async throws {
        // Create PDF with annotations
        let url = try PDFTestHelpers.createTestPDFWithAnnotations(
            pageCount: 2,
            identifier: "flatten_annotations_test"
        )
        defer { PDFTestHelpers.cleanup(url: url) }
        
        // Verify source has annotations
        guard let sourceDoc = PDFDocument(url: url) else {
            Issue.record("Failed to load source PDF")
            return
        }
        let sourceAnnotationCount = (0..<sourceDoc.pageCount).reduce(0) { count, i in
            count + (sourceDoc.page(at: i)?.annotations.count ?? 0)
        }
        #expect(sourceAnnotationCount > 0, "Source should have annotations")
        
        // Flatten
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 2, fileSize: 1000)
        let flattener = PDFFlattener()
        let outputURL = try await flattener.flatten(
            file: file,
            options: .init(outputFileName: "flattened_no_annotations"),
            progress: { _ in }
        )
        defer { PDFTestHelpers.cleanup(url: outputURL) }
        
        // Verify output has NO annotations (they were baked in)
        guard let flattenedDoc = PDFDocument(url: outputURL) else {
            Issue.record("Failed to load flattened PDF")
            return
        }
        let flattenedAnnotationCount = (0..<flattenedDoc.pageCount).reduce(0) { count, i in
            count + (flattenedDoc.page(at: i)?.annotations.count ?? 0)
        }
        #expect(flattenedAnnotationCount == 0, "Flattened PDF should have no annotations")
    }
    
    // MARK: - Helpers
    
    /// Returns any leftover flatten output files in the temp directory whose name
    /// starts with the given prefix (excluding the `.pdf` extension).
    private static func leftoverOutputs(matching prefix: String) -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents.filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(prefix) }
    }
    
    /// Removes any stale flatten output files matching the prefix so a later
    /// cleanup assertion is not polluted by a prior crashed run.
    private static func removeLeftoverOutputs(matching prefix: String) {
        for url in leftoverOutputs(matching: prefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Corrupt / Locked File Tests

    @Test("Corrupt and empty files throw error")
    func corruptFilesThrowError() async throws {
        let id = UUID().uuidString
        let fixtures: [(label: String, url: URL)] = try [
            ("garbage",   PDFTestHelpers.createGarbagePDF(identifier: "flatten_garbage_\(id)")),
            ("empty",     PDFTestHelpers.createEmptyPDF(identifier: "flatten_empty_\(id)")),
            ("truncated", PDFTestHelpers.createTruncatedPDF(identifier: "flatten_trunc_\(id)"))
        ]
        defer { fixtures.forEach { PDFTestHelpers.cleanup(url: $0.url) } }

        let flattener = PDFFlattener()

        for fixture in fixtures {
            let file = PDFFile(url: fixture.url, fileName: "\(fixture.label).pdf", pageCount: 1, fileSize: 100)
            await #expect(throws: PDFEngineError.self) {
                _ = try await flattener.flatten(file: file, options: .init(), progress: { _ in })
            }
        }
    }

    @Test("Password-protected PDF throws passwordProtected")
    func lockedPDFThrowsPasswordProtected() async throws {
        let id = UUID().uuidString
        let url = try PDFTestHelpers.createLockedPDF(identifier: "flatten_locked_\(id)")
        defer { PDFTestHelpers.cleanup(url: url) }

        let file = PDFFile(url: url, fileName: "locked.pdf", pageCount: 3, fileSize: 1000)
        let flattener = PDFFlattener()

        do {
            _ = try await flattener.flatten(file: file, options: .init(), progress: { _ in })
            Issue.record("Should have thrown passwordProtected")
        } catch PDFEngineError.passwordProtected {
            // Expected
        } catch {
            Issue.record("Expected .passwordProtected but got: \(error)")
        }
    }
}
