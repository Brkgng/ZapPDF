//
//  PDFFile.swift
//  ZapPDF
//
//  Identifiable wrapper for PDF files with metadata extraction.
//

import Foundation
import PDFKit

/// Represents a PDF file with its metadata for use throughout the app.
///
/// `PDFFile` is an immutable struct that wraps a PDF URL along with extracted
/// metadata like page count and file size. It supports bookmark data for
/// persisting file access across app launches.
///
/// Example:
/// ```swift
/// let pdfFile = try await PDFFile(url: selectedURL)
/// print("File: \(pdfFile.fileName), Pages: \(pdfFile.pageCount)")
/// ```
struct PDFFile: Identifiable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier for this PDF file instance.
    let id: UUID
    
    /// The file URL of the PDF document.
    let url: URL
    
    /// The display name of the file (without path).
    let fileName: String
    
    /// Number of pages in the PDF document.
    let pageCount: Int
    
    /// File size in bytes.
    let fileSize: Int64
    
    /// Bookmark data for persisting access across app launches.
    /// May be nil if bookmark creation failed.
    let bookmarkData: Data?
    
    /// Date when the file was last modified.
    let modificationDate: Date?
    
    // MARK: - Initialization
    
    /// Create a PDFFile by loading metadata from the given URL.
    ///
    /// This initializer is async because it needs to access the file system
    /// and extract PDF metadata, which may take time for large files.
    ///
    /// - Parameter url: The URL of the PDF file to load
    /// - Throws: `PDFFileError` if the file cannot be loaded or is invalid
    init(url: URL) async throws {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        
        // Extract metadata within security scope
        let metadata = try await url.withSecurityScopeAsync {
            try PDFFile.extractMetadata(from: url)
        }
        
        self.pageCount = metadata.pageCount
        self.fileSize = metadata.fileSize
        self.modificationDate = metadata.modificationDate
        
        // Create bookmark data for persistence (may fail, that's OK)
        self.bookmarkData = try? url.createBookmarkData()
    }
    
    /// Internal initializer for creating PDFFile with known values (used in tests).
    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String,
        pageCount: Int,
        fileSize: Int64,
        bookmarkData: Data? = nil,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.bookmarkData = bookmarkData
        self.modificationDate = modificationDate
    }
    
    // MARK: - Metadata Extraction
    
    private struct PDFMetadata {
        let pageCount: Int
        let fileSize: Int64
        let modificationDate: Date?
    }
    
    private static func extractMetadata(from url: URL) throws -> PDFMetadata {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFFileError.fileNotFound(url)
        }
        
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0
        let modDate = attributes[.modificationDate] as? Date
        
        // Load PDF document to get page count
        guard let document = PDFDocument(url: url) else {
            throw PDFFileError.invalidPDF(url)
        }
        
        // Check if password protected
        if document.isLocked {
            throw PDFFileError.passwordProtected(url)
        }
        
        return PDFMetadata(
            pageCount: document.pageCount,
            fileSize: fileSize,
            modificationDate: modDate
        )
    }
    
    // MARK: - Computed Properties
    
    /// Human-readable file size string.
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Whether this file has valid bookmark data for re-access.
    var hasValidBookmark: Bool {
        bookmarkData != nil
    }
    
    // MARK: - Security-Scoped Access
    
    /// Resolves the bookmark to get a fresh, valid security-scoped URL.
    ///
    /// External files (opened via Share Sheet or "Open In") have ephemeral URLs that
    /// may become invalid after the app backgrounds. This method resolves the stored
    /// bookmark to obtain a URL with a valid sandbox extension.
    ///
    /// - Returns: A resolved URL if bookmark exists, otherwise the original URL
    func resolvedURL() throws -> URL {
        // If no bookmark, return original URL (user-selected files work this way)
        guard let bookmarkData = self.bookmarkData else {
            return url
        }
        
        do {
            let (resolvedURL, isStale) = try URL.resolve(from: bookmarkData)
            
            if isStale {
                #if DEBUG
                print("⚠️ Bookmark is stale for: \(fileName)")
                #endif
            }
            
            return resolvedURL
        } catch {
            #if DEBUG
            print("❌ Bookmark resolution failed for: \(fileName), error: \(error)")
            #endif
            // Fallback to original URL — may still work if accessed immediately
            return url
        }
    }
    
    /// Executes a closure with guaranteed security-scoped access to the file.
    ///
    /// This is the **preferred way** to access file contents for external files.
    /// It handles bookmark resolution and security scope management automatically.
    ///
    /// - Parameter operation: The operation to perform with file access
    /// - Returns: The result of the operation
    /// - Throws: Any error from bookmark resolution or the operation
    func withResolvedAccess<T>(_ operation: (URL) throws -> T) throws -> T {
        let accessURL = try resolvedURL()
        return try accessURL.withSecurityScope {
            try operation(accessURL)
        }
    }
    
    /// Async version of withResolvedAccess for async operations.
    func withResolvedAccessAsync<T>(_ operation: (URL) async throws -> T) async throws -> T {
        let accessURL = try resolvedURL()
        return try await accessURL.withSecurityScopeAsync {
            try await operation(accessURL)
        }
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PDFFile, rhs: PDFFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PDFFile Errors

/// Errors that can occur when creating a PDFFile.
enum PDFFileError: Error, LocalizedError, Sendable {
    case fileNotFound(URL)
    case invalidPDF(URL)
    case passwordProtected(URL)
    case accessDenied(URL)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return L10n.Error.fileNotFound(filename: url.lastPathComponent)
        case .invalidPDF(let url):
            return L10n.Error.invalidPDF(filename: url.lastPathComponent)
        case .passwordProtected(let url):
            return L10n.Error.passwordProtected(filename: url.lastPathComponent)
        case .accessDenied(let url):
            return L10n.Error.accessDenied(filename: url.lastPathComponent)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return L10n.Error.fileMovedOrDeleted
        case .invalidPDF:
            return L10n.Error.selectValidPDF
        case .passwordProtected:
            return L10n.Error.unlockPDF
        case .accessDenied:
            return L10n.Error.reselectFile
        }
    }
}

// MARK: - PDFFile Collection Extension

extension Array where Element == PDFFile {
    /// Total page count across all PDFs in the collection.
    var totalPageCount: Int {
        reduce(0) { $0 + $1.pageCount }
    }
    
    /// Total file size across all PDFs in the collection.
    var totalFileSize: Int64 {
        reduce(0) { $0 + $1.fileSize }
    }
    
    /// Human-readable total file size.
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalFileSize, countStyle: .file)
    }
}
