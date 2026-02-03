//
//  DocumentScanner.swift
//  ZapPDF
//
//  Service for scanning documents and converting images to PDF.
//

#if os(iOS)
import Foundation
import VisionKit
import PDFKit
import UIKit
import os.log

/// Protocol for document scan operations to enable testing
protocol DocumentScanning {
    var pageCount: Int { get }
    func imageOfPage(at index: Int) -> UIImage
}

/// Make VNDocumentCameraScan conform to DocumentScanning protocol
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
///
/// **Threading**: PDF conversion runs off the main thread via `Task.detached`.
/// **Memory**: Uses process-and-release pattern to avoid holding all images in memory.
@available(iOS 17.0, *)
final class DocumentScanner: Sendable {
    
    // MARK: - Singleton
    
    static let shared = DocumentScanner()
    
    private init() {}
    
    // MARK: - Logger
    
    private static let logger = Logger(subsystem: "com.zappdf", category: "DocumentScanner")
    
    // MARK: - Availability
    
    /// Check if document scanning is supported on this device.
    @MainActor
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
    
    // MARK: - PDF Conversion
    
    /// Convert a document scan to a PDF file.
    ///
    /// This method runs the CPU-intensive PDF conversion off the main thread
    /// and uses a process-and-release pattern to minimize memory usage.
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
        
        // Run conversion off main thread
        return try await Task.detached(priority: .userInitiated) {
            let pdfDocument = PDFDocument()
            var failedIndices: [Int] = []
            var successCount = 0
            
            for pageIndex in 0..<pageCount {
                // Use autoreleasepool to ensure UIImage objects are released promptly
                // This is critical for large page counts (50+) to avoid memory pressure
                autoreleasepool {
                    // Get image (VisionKit manages its own memory)
                    let image = scan.imageOfPage(at: pageIndex)

                    // Convert to PDF page
                    if let pdfPage = PDFPage(image: image) {
                        pdfDocument.insert(pdfPage, at: successCount)
                        successCount += 1
                    } else {
                        Self.logger.warning("Failed to convert page \(pageIndex) to PDF")
                        failedIndices.append(pageIndex)
                    }
                }

                // Report progress on main thread (outside autoreleasepool)
                if let progress {
                    let currentProgress = Double(pageIndex + 1) / Double(pageCount)
                    await MainActor.run {
                        progress(currentProgress)
                    }
                }
            }
            
            // Require at least one successful page
            guard successCount > 0 else {
                throw DocumentScannerError.allPagesFailedToConvert
            }
            
            // Generate output filename
            let outputName = fileName ?? "Scanned_\(Self.dateFormatter.string(from: Date()))"
            let outputURL = Self.scansDirectory
                .appendingPathComponent(outputName)
                .appendingPathExtension("pdf")
            
            // Write PDF
            guard pdfDocument.write(to: outputURL) else {
                throw DocumentScannerError.pdfWriteFailed
            }
            
            Self.logger.info("Created PDF with \(successCount) pages at \(outputURL.lastPathComponent)")
            
            return ScanConversionResult(
                pdfURL: outputURL,
                successfulPages: successCount,
                failedPageIndices: failedIndices
            )
        }.value
    }
    
    /// Convert an array of UIImages to a PDF file.
    ///
    /// Used for Photo Library imports. Uses the same off-main-thread,
    /// process-and-release pattern as scan conversion.
    ///
    /// - Parameters:
    ///   - images: Array of images to convert
    ///   - fileName: Optional custom filename (without extension)
    ///   - progress: Progress callback (0.0 to 1.0), called on main thread
    /// - Returns: Result containing the PDF URL and any failed page indices
    /// - Throws: DocumentScannerError if conversion fails completely
    func convertImagesToPDF(
        _ images: [UIImage],
        fileName: String? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ScanConversionResult {
        guard !images.isEmpty else {
            throw DocumentScannerError.noImagesProvided
        }
        
        let imageCount = images.count
        
        // Run conversion off main thread
        return try await Task.detached(priority: .userInitiated) {
            let pdfDocument = PDFDocument()
            var failedIndices: [Int] = []
            var successCount = 0
            
            for (index, image) in images.enumerated() {
                // Use autoreleasepool to ensure UIImage objects are released promptly
                // This is critical for large image counts (50+) to avoid memory pressure
                autoreleasepool {
                    if let pdfPage = PDFPage(image: image) {
                        pdfDocument.insert(pdfPage, at: successCount)
                        successCount += 1
                    } else {
                        Self.logger.warning("Failed to convert image \(index) to PDF")
                        failedIndices.append(index)
                    }
                }

                // Report progress on main thread (outside autoreleasepool)
                if let progress {
                    let currentProgress = Double(index + 1) / Double(imageCount)
                    await MainActor.run {
                        progress(currentProgress)
                    }
                }
            }
            
            // Require at least one successful page
            guard successCount > 0 else {
                throw DocumentScannerError.allPagesFailedToConvert
            }
            
            // Generate output filename
            let outputName = fileName ?? "Imported_\(Self.dateFormatter.string(from: Date()))"
            let outputURL = Self.scansDirectory
                .appendingPathComponent(outputName)
                .appendingPathExtension("pdf")
            
            // Write PDF
            guard pdfDocument.write(to: outputURL) else {
                throw DocumentScannerError.pdfWriteFailed
            }
            
            Self.logger.info("Created PDF with \(successCount) pages from \(imageCount) images")
            
            return ScanConversionResult(
                pdfURL: outputURL,
                successfulPages: successCount,
                failedPageIndices: failedIndices
            )
        }.value
    }
    
    // MARK: - Helpers

    /// Directory for storing scanned/imported PDFs.
    ///
    /// Creates a "Scans" subdirectory in the app's Application Support directory.
    /// This provides persistent storage that survives app restarts and allows
    /// proper cleanup when files are removed from the dashboard.
    private static var scansDirectory: URL {
        let fileManager = FileManager.default

        // Get Application Support directory
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get Application Support directory, falling back to temp directory")
            return fileManager.temporaryDirectory
        }

        // Create Scans subdirectory
        let scansURL = appSupportURL.appendingPathComponent("Scans", isDirectory: true)

        // Create directory if it doesn't exist
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

    /// Remove a scanned PDF file from disk.
    ///
    /// Call this when a file is permanently removed from the dashboard
    /// to free up storage space.
    ///
    /// - Parameter url: The file URL to delete
    /// - Returns: `true` if the file was deleted, `false` if it didn't exist or deletion failed
    static func cleanupScannedFile(at url: URL) -> Bool {
        let fileManager = FileManager.default

        // Only delete files from our scans directory
        guard url.path.contains(scansDirectory.path) else {
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}
#endif
