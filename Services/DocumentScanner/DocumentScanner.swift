//
//  DocumentScanner.swift
//  ZapPDF
//
//  Service for scanning documents and converting images to PDF.
//

#if os(iOS)
import Foundation
@preconcurrency import VisionKit
import PDFKit
import UIKit
import os.log

/// Protocol for document scan operations to enable testing.
protocol DocumentScanning {
    var pageCount: Int { get }
    @MainActor func imageOfPage(at index: Int) -> UIImage
}

/// Make VNDocumentCameraScan conform to DocumentScanning protocol.
extension VNDocumentCameraScan: DocumentScanning {}

/// Result of a scan-to-PDF conversion operation.
struct ScanConversionResult: Sendable {
    /// URL of the generated PDF file.
    let pdfURL: URL
    /// Total number of pages that were successfully converted.
    let successfulPages: Int
    /// Page indices that failed to convert (0-indexed).
    let failedPageIndices: [Int]

    /// Whether all pages were converted successfully.
    var isComplete: Bool { failedPageIndices.isEmpty }
}

/// Service for scanning documents and converting images to PDF.
///
/// iOS/iPadOS only. Uses VNDocumentCameraViewController for camera scanning
/// and supports importing images from Photo Library.
@available(iOS 17.0, *)
final class DocumentScanner: Sendable {

    // MARK: - Singleton

    static let shared = DocumentScanner()

    private init() {}

    // MARK: - Logger

    nonisolated(unsafe) private static let logger = Logger(subsystem: "com.zappdf", category: "DocumentScanner")

    // MARK: - Availability

    /// Check if document scanning is supported on this device.
    @MainActor
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    // MARK: - PDF Conversion

    /// Convert a document scan to a PDF file.
    ///
    /// - Parameters:
    ///   - scan: The completed document scan conforming to DocumentScanning protocol
    ///   - fileName: Optional custom filename (without extension)
    ///   - progress: Progress callback (0.0 to 1.0), called on main thread
    /// - Returns: Result containing the PDF URL and any failed page indices
    /// - Throws: DocumentScannerError if conversion fails completely
    func convertScanToPDF<T: DocumentScanning>(
        _ scan: T,
        fileName: String? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ScanConversionResult {
        let pageCount = scan.pageCount

        guard pageCount > 0 else {
            throw DocumentScannerError.noImagesProvided
        }

        return try await convertToPDF(
            pageCount: pageCount,
            fileName: fileName,
            defaultPrefix: "Scanned",
            progress: progress
        ) { pageIndex in
            await scan.imageOfPage(at: pageIndex)
        }
    }

    /// Convert an array of UIImages to a PDF file.
    ///
    /// Compatibility API for preloaded image workflows.
    func convertImagesToPDF(
        _ images: [UIImage],
        fileName: String? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ScanConversionResult {
        guard !images.isEmpty else {
            throw DocumentScannerError.noImagesProvided
        }

        return try await convertToPDF(
            pageCount: images.count,
            fileName: fileName,
            defaultPrefix: "Imported",
            progress: progress
        ) { index in
            images[index]
        }
    }

    /// Convert image item providers to a PDF file using streaming image loading.
    ///
    /// This API avoids preloading all images into memory before conversion.
    func convertImageProvidersToPDF(
        _ providers: [NSItemProvider],
        fileName: String? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ScanConversionResult {
        guard !providers.isEmpty else {
            throw DocumentScannerError.noImagesProvided
        }

        return try await convertToPDF(
            pageCount: providers.count,
            fileName: fileName,
            defaultPrefix: "Imported",
            progress: progress
        ) { index in
            try Task.checkCancellation()
            return await Self.loadImage(from: providers[index])
        }
    }

    private typealias AsyncImageProvider = @Sendable (_ index: Int) async throws -> UIImage?

    private func convertToPDF(
        pageCount: Int,
        fileName: String?,
        defaultPrefix: String,
        progress: (@Sendable (Double) -> Void)?,
        imageProvider: @escaping AsyncImageProvider
    ) async throws -> ScanConversionResult {
        let logger = Self.logger
        let preferredBaseName = Self.normalizedBaseName(fileName) ?? Self.defaultOutputName(prefix: defaultPrefix)

        let conversionTask = Task.detached(priority: .userInitiated) {
            let pdfDocument = PDFDocument()
            var failedIndices: [Int] = []
            var successCount = 0

            for pageIndex in 0..<pageCount {
                try Task.checkCancellation()

                let image = try await imageProvider(pageIndex)

                if let image {
                    autoreleasepool {
                        if let pdfPage = PDFPage(image: image) {
                            pdfDocument.insert(pdfPage, at: successCount)
                            successCount += 1
                        } else {
                            failedIndices.append(pageIndex)
                            logger.warning("Failed to convert page \(pageIndex) to PDF")
                        }
                    }
                } else {
                    failedIndices.append(pageIndex)
                    logger.warning("Failed to load image for page \(pageIndex)")
                }

                if let progress {
                    let currentProgress = Double(pageIndex + 1) / Double(pageCount)
                    await MainActor.run {
                        progress(currentProgress)
                    }
                }
            }

            guard successCount > 0 else {
                throw DocumentScannerError.allPagesFailedToConvert
            }

            try Task.checkCancellation()
            let outputURL = try Self.writePDFAtomically(pdfDocument, preferredBaseName: preferredBaseName)

            logger.info("Created PDF with \(successCount) pages at \(outputURL.lastPathComponent)")

            return ScanConversionResult(
                pdfURL: outputURL,
                successfulPages: successCount,
                failedPageIndices: failedIndices
            )
        }

        return try await withTaskCancellationHandler {
            do {
                return try await conversionTask.value
            } catch is CancellationError {
                throw DocumentScannerError.cancelled
            }
        } onCancel: {
            conversionTask.cancel()
        }
    }

    // MARK: - Helpers

    /// Directory for storing scanned/imported PDFs.
    ///
    /// Creates a "Scans" subdirectory in the app's Application Support directory.
    nonisolated private static var scansDirectory: URL {
        let fileManager = FileManager.default

        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get Application Support directory, falling back to temp directory")
            return fileManager.temporaryDirectory
        }

        let scansURL = appSupportURL.appendingPathComponent("Scans", isDirectory: true)

        if !fileManager.fileExists(atPath: scansURL.path) {
            do {
                try fileManager.createDirectory(at: scansURL, withIntermediateDirectories: true)
                logger.info("Created scans directory at \(scansURL.path)")
            } catch {
                logger.error("Failed to create scans directory: \(error.localizedDescription)")
                return fileManager.temporaryDirectory
            }
        }

        return scansURL
    }

    /// Remove a scanned/imported PDF file from disk.
    ///
    /// - Parameter url: The file URL to delete
    /// - Returns: `true` if the file was deleted, `false` if it didn't exist or deletion failed
    nonisolated static func cleanupScannedFile(at url: URL) -> Bool {
        let fileManager = FileManager.default

        guard isInScansDirectory(url) else {
            logger.warning("Refusing to delete file outside scans directory: \(url.path)")
            return false
        }

        guard fileManager.fileExists(atPath: url.path) else {
            logger.debug("File no longer exists: \(url.lastPathComponent)")
            return false
        }

        do {
            try fileManager.removeItem(at: url)
            logger.info("Deleted scanned file: \(url.lastPathComponent)")
            return true
        } catch {
            logger.error("Failed to delete scanned file \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    nonisolated private static func loadImage(from provider: NSItemProvider) async -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    nonisolated private static func writePDFAtomically(
        _ document: PDFDocument,
        preferredBaseName: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let tempURL = scansDirectory
            .appendingPathComponent("tmp_\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        guard document.write(to: tempURL) else {
            throw DocumentScannerError.pdfWriteFailed
        }

        var attempt = 0
        while attempt < 100 {
            let outputURL = uniqueOutputURL(baseName: preferredBaseName, attempt: attempt)
            do {
                try fileManager.moveItem(at: tempURL, to: outputURL)
                return outputURL
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain,
                   nsError.code == CocoaError.fileWriteFileExists.rawValue {
                    attempt += 1
                    continue
                }

                try? fileManager.removeItem(at: tempURL)
                throw DocumentScannerError.pdfWriteFailed
            }
        }

        try? fileManager.removeItem(at: tempURL)
        throw DocumentScannerError.pdfWriteFailed
    }

    nonisolated private static func uniqueOutputURL(baseName: String, attempt: Int) -> URL {
        let outputName = attempt == 0 ? baseName : "\(baseName)_\(attempt)"
        return scansDirectory
            .appendingPathComponent(outputName)
            .appendingPathExtension("pdf")
    }

    nonisolated private static func defaultOutputName(prefix: String) -> String {
        let milliseconds = Int((Date().timeIntervalSince1970 * 1000.0).rounded())
        let shortID = UUID().uuidString.prefix(8)
        return "\(prefix)_\(milliseconds)_\(shortID)"
    }

    nonisolated private static func normalizedBaseName(_ value: String?) -> String? {
        guard var baseName = value?.trimmingCharacters(in: .whitespacesAndNewlines), !baseName.isEmpty else {
            return nil
        }

        if baseName.lowercased().hasSuffix(".pdf") {
            baseName.removeLast(4)
        }

        return baseName.isEmpty ? nil : baseName
    }

    nonisolated private static func isInScansDirectory(_ url: URL) -> Bool {
        let scansPath = scansDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        let candidatePath = url.standardizedFileURL.resolvingSymlinksInPath().path

        let prefix = scansPath.hasSuffix("/") ? scansPath : scansPath + "/"
        return candidatePath.hasPrefix(prefix)
    }
}
#endif
