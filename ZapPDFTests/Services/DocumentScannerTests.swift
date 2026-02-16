import Testing
import Foundation
@testable import ZapPDF
#if os(iOS)
import VisionKit
import PDFKit
import UIKit
#endif

@Suite("DocumentScanner Tests")
final class DocumentScannerTests {

    // MARK: - Test Helpers

    #if os(iOS)

    /// Mock implementation of DocumentScanning for testing
    private final class MockScan: DocumentScanning {
        let pageCount: Int
        private let imageSize: CGSize
        private var imageCache: [UIImage] = []

        init(pageCount: Int, imageSize: CGSize = CGSize(width: 595, height: 842)) {
            self.pageCount = pageCount
            self.imageSize = imageSize
            // Pre-create images to avoid repeated UIGraphics calls
            imageCache = (0..<pageCount).map { _ in
                MockScan.createTestImage(size: imageSize)
            }
        }

        @MainActor
        func imageOfPage(at index: Int) -> UIImage {
            guard index < pageCount else {
                fatalError("Index \(index) out of bounds for scan with \(pageCount) pages")
            }
            return imageCache[index]
        }

        /// Creates a test UIImage with specified dimensions
        private static func createTestImage(size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
    }

    /// Creates a test UIImage with specified dimensions
    private func createTestImage(size: CGSize = CGSize(width: 595, height: 842)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Single Page Conversion Tests

    @Test("Converts single page scan to PDF successfully")
    func convertsSinglePageToPDF() async throws {
        // Arrange
        let mockScan = MockScan(pageCount: 1)

        // Act
        let result = try await DocumentScanner.shared.convertScanToPDF(
            mockScan,
            progress: nil
        )

        // Assert
        #expect(FileManager.default.fileExists(atPath: result.pdfURL.path))

        // Verify PDF is valid
        guard let document = PDFDocument(url: result.pdfURL) else {
            Issue.record("Generated PDF cannot be opened")
            return
        }
        #expect(document.pageCount == 1, "PDF should have exactly 1 page")
        #expect(result.successfulPages == 1)
        #expect(result.failedPageIndices.isEmpty)
        #expect(result.isComplete)

        // Cleanup
        _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL)
    }

    // MARK: - Multi-Page Conversion Tests

    @Test("Converts multi-page scan to PDF successfully")
    func convertsMultiPageToPDF() async throws {
        // Arrange
        let mockScan = MockScan(pageCount: 5)

        // Act
        let result = try await DocumentScanner.shared.convertScanToPDF(
            mockScan,
            progress: nil
        )

        // Assert
        guard let document = PDFDocument(url: result.pdfURL) else {
            Issue.record("Generated PDF cannot be opened")
            return
        }
        #expect(document.pageCount == 5, "PDF should have all 5 pages")
        #expect(result.successfulPages == 5)
        #expect(result.failedPageIndices.isEmpty)

        // Cleanup
        _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL)
    }

    // MARK: - Error Handling Tests

    @Test("Throws error when scan has no pages")
    func throwsOnEmptyScan() async throws {
        // Arrange
        let mockScan = MockScan(pageCount: 0)

        // Act & Assert
        do {
            _ = try await DocumentScanner.shared.convertScanToPDF(
                mockScan,
                progress: nil
            )
            Issue.record("Expected DocumentScannerError.noImagesProvided to be thrown")
        } catch DocumentScannerError.noImagesProvided {
            // Expected error - test passes
        } catch {
            Issue.record("Expected DocumentScannerError.noImagesProvided, got \(error)")
        }
    }

    // MARK: - Progress Callback Tests

    @Test("Reports progress during conversion")
    func reportsProgressDuringConversion() async throws {
        // Arrange
        let pageCount = 10
        let mockScan = MockScan(pageCount: pageCount)
        var progressUpdates: [Double] = []

        // Act
        let result = try await DocumentScanner.shared.convertScanToPDF(
            mockScan
        ) { progress in
            progressUpdates.append(progress)
        }

        // Assert
        #expect(!progressUpdates.isEmpty, "Should receive progress updates")
        #expect(progressUpdates.last == 1.0, "Final progress should be 100%")

        // Verify monotonically increasing
        for i in 1..<progressUpdates.count {
            #expect(progressUpdates[i] >= progressUpdates[i-1],
                    "Progress should increase monotonically")
        }

        // Cleanup
        _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL)
    }

    // MARK: - Image Array Conversion Tests

    @Test("Converts array of images to PDF successfully")
    func convertsImagesToPDF() async throws {
        // Arrange
        let images = [
            createTestImage(size: CGSize(width: 595, height: 842)),
            createTestImage(size: CGSize(width: 595, height: 842)),
            createTestImage(size: CGSize(width: 595, height: 842))
        ]

        // Act
        let result = try await DocumentScanner.shared.convertImagesToPDF(
            images,
            progress: nil
        )

        // Assert
        guard let document = PDFDocument(url: result.pdfURL) else {
            Issue.record("Generated PDF cannot be opened")
            return
        }
        #expect(document.pageCount == 3, "PDF should have 3 pages")
        #expect(result.successfulPages == 3)

        // Cleanup
        _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL)
    }

    @Test("Throws error when image array is empty")
    func throwsOnEmptyImageArray() async throws {
        // Arrange
        let emptyImages: [UIImage] = []

        // Act & Assert
        do {
            _ = try await DocumentScanner.shared.convertImagesToPDF(
                emptyImages,
                progress: nil
            )
            Issue.record("Expected DocumentScannerError.noImagesProvided to be thrown")
        } catch DocumentScannerError.noImagesProvided {
            // Expected error - test passes
        } catch {
            Issue.record("Expected DocumentScannerError.noImagesProvided, got \(error)")
        }
    }

    // MARK: - Large Page Count Tests

    @Test("Handles large page count without memory issues")
    func handlesLargePageCount() async throws {
        // Arrange
        let largePageCount = 50
        let mockScan = MockScan(pageCount: largePageCount)

        // Act - should not crash or throw memory errors
        let result = try await DocumentScanner.shared.convertScanToPDF(
            mockScan,
            progress: nil
        )

        // Assert
        guard let document = PDFDocument(url: result.pdfURL) else {
            Issue.record("Generated PDF cannot be opened")
            return
        }
        #expect(document.pageCount == largePageCount, "All pages should be converted")
        #expect(result.successfulPages == largePageCount)

        // Cleanup
        _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL)
    }

    @Test("Creates unique output file names for rapid conversions")
    func createsUniqueOutputNamesForRapidConversions() async throws {
        let firstResult = try await DocumentScanner.shared.convertScanToPDF(MockScan(pageCount: 1))
        let secondResult = try await DocumentScanner.shared.convertScanToPDF(MockScan(pageCount: 1))

        #expect(firstResult.pdfURL != secondResult.pdfURL, "Rapid conversions should not overwrite the same file")

        _ = DocumentScanner.cleanupScannedFile(at: firstResult.pdfURL)
        _ = DocumentScanner.cleanupScannedFile(at: secondResult.pdfURL)
    }

    // MARK: - Cleanup Tests

    @Test("Cleanup removes scanned file from disk")
    func cleanupRemovesScannedFile() async throws {
        // Arrange
        let mockScan = MockScan(pageCount: 1)
        let result = try await DocumentScanner.shared.convertScanToPDF(mockScan)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: result.pdfURL.path))

        // Act
        let deleted = DocumentScanner.cleanupScannedFile(at: result.pdfURL)

        // Assert
        #expect(deleted == true, "Cleanup should return true when file is deleted")
        #expect(!FileManager.default.fileExists(atPath: result.pdfURL.path), "File should no longer exist")
    }

    @Test("Cleanup returns false for non-existent file")
    func cleanupReturnsFalseForMissingFile() async throws {
        // Arrange - create a URL that doesn't exist
        let mockScan = MockScan(pageCount: 1)
        let result = try await DocumentScanner.shared.convertScanToPDF(mockScan)

        // Delete the file first
        try? FileManager.default.removeItem(at: result.pdfURL)

        // Act - try to cleanup already-deleted file
        let deleted = DocumentScanner.cleanupScannedFile(at: result.pdfURL)

        // Assert
        #expect(deleted == false, "Cleanup should return false for non-existent file")
    }

    @Test("Cleanup refuses to delete files outside scans directory")
    func cleanupRefusesUnsafeDeletion() {
        // Arrange - create a temp file outside scans directory
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).pdf")

        // Create empty file
        FileManager.default.createFile(atPath: testFile.path, contents: Data())

        // Act
        let deleted = DocumentScanner.cleanupScannedFile(at: testFile)

        // Assert
        #expect(deleted == false, "Cleanup should refuse to delete files outside scans directory")
        #expect(FileManager.default.fileExists(atPath: testFile.path), "File should still exist")

        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Cleanup rejects paths that only partially match scans directory name")
    func cleanupRejectsPathPrefixTricks() async throws {
        let mockScan = MockScan(pageCount: 1)
        let result = try await DocumentScanner.shared.convertScanToPDF(mockScan)
        defer { _ = DocumentScanner.cleanupScannedFile(at: result.pdfURL) }

        let scansDir = result.pdfURL.deletingLastPathComponent()
        let parent = scansDir.deletingLastPathComponent()
        let fakeDir = parent.appendingPathComponent(scansDir.lastPathComponent + "_evil")
        try FileManager.default.createDirectory(at: fakeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fakeDir) }

        let fakeFile = fakeDir.appendingPathComponent("fake.pdf")
        FileManager.default.createFile(atPath: fakeFile.path, contents: Data())

        let deleted = DocumentScanner.cleanupScannedFile(at: fakeFile)
        #expect(deleted == false, "Cleanup should reject lookalike directory prefixes")
        #expect(FileManager.default.fileExists(atPath: fakeFile.path), "Fake file should remain untouched")
    }
    #endif
}
