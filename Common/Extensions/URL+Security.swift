//
//  URL+Security.swift
//  ZapPDF
//
//  Security-scoped resource access wrappers for sandboxed file operations.
//

import Foundation

// MARK: - File Access Errors

/// Errors that can occur when accessing files in a sandboxed environment.
enum FileAccessError: Error, LocalizedError, Sendable {
    case securityScopeAccessDenied(URL)
    case bookmarkResolutionFailed
    case fileNotFound(URL)
    case permissionDenied(URL)
    case bookmarkCreationFailed(URL)
    
    var errorDescription: String? {
        switch self {
        case .securityScopeAccessDenied(let url):
            return "Unable to access '\(url.lastPathComponent)'. Please re-select the file."
        case .bookmarkResolutionFailed:
            return "Could not restore access to a previously used file."
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            return "Permission denied for '\(url.lastPathComponent)'"
        case .bookmarkCreationFailed(let url):
            return "Could not save reference to '\(url.lastPathComponent)'"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .securityScopeAccessDenied, .bookmarkResolutionFailed, .permissionDenied:
            return "Please select the file again using the file picker."
        case .fileNotFound:
            return "The file may have been moved or deleted."
        case .bookmarkCreationFailed:
            return "Try selecting the file again."
        }
    }
}

// MARK: - URL Extension for Security-Scoped Access

extension URL {
    
    // MARK: - Security Scoped Access
    
    /// Execute a closure with security-scoped resource access.
    /// Automatically starts and stops access, ensuring proper cleanup.
    ///
    /// - Parameter body: The closure to execute with file access
    /// - Returns: The result of the closure
    /// - Throws: Any error thrown by the closure
    ///
    /// Example:
    /// ```swift
    /// let data = try url.withSecurityScope {
    ///     try Data(contentsOf: url)
    /// }
    /// ```
    func withSecurityScope<T>(_ body: () throws -> T) rethrows -> T {
        let didStartAccessing = self.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
    
    /// Async version of security-scoped access for PDF operations that may take time.
    ///
    /// - Parameter body: The async closure to execute with file access
    /// - Returns: The result of the closure
    /// - Throws: Any error thrown by the closure
    ///
    /// Example:
    /// ```swift
    /// let document = try await url.withSecurityScopeAsync {
    ///     PDFDocument(url: url)
    /// }
    /// ```
    func withSecurityScopeAsync<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        let didStartAccessing = self.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try await body()
    }
    
    /// Check if this URL requires security-scoped access.
    /// Returns true for user-selected files outside the sandbox.
    var requiresSecurityScope: Bool {
        // Files in the app's container don't require security scope
        guard let containerURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return true
        }
        
        // Also check temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        
        let isInContainer = self.path.hasPrefix(containerURL.path)
        let isInTemp = self.path.hasPrefix(tempDir.path)
        
        return !isInContainer && !isInTemp
    }
    
    // MARK: - Bookmark Data
    
    /// Create bookmark data for persisting file access across app launches.
    ///
    /// - Parameter isSecurityScoped: Whether to include security scope in bookmark (macOS only)
    /// - Returns: Bookmark data that can be stored and later resolved
    /// - Throws: `FileAccessError.bookmarkCreationFailed` if bookmark creation fails
    ///
    /// Example:
    /// ```swift
    /// let bookmarkData = try url.createBookmarkData()
    /// UserDefaults.standard.set(bookmarkData, forKey: "lastUsedFile")
    /// ```
    func createBookmarkData(isSecurityScoped: Bool = true) throws -> Data {
        var options: URL.BookmarkCreationOptions = []
        
        #if os(macOS)
        if isSecurityScoped {
            options.insert(.withSecurityScope)
        }
        #endif
        
        do {
            return try self.bookmarkData(
                options: options,
                includingResourceValuesForKeys: [.nameKey, .fileSizeKey],
                relativeTo: nil
            )
        } catch {
            throw FileAccessError.bookmarkCreationFailed(self)
        }
    }
    
    /// Resolve a URL from previously stored bookmark data.
    ///
    /// - Parameters:
    ///   - bookmarkData: Bookmark data created by `createBookmarkData()`
    ///   - isSecurityScoped: Whether the bookmark was created with security scope
    /// - Returns: Tuple containing resolved URL and whether the bookmark was stale
    /// - Throws: `FileAccessError.bookmarkResolutionFailed` if resolution fails
    ///
    /// Example:
    /// ```swift
    /// if let data = UserDefaults.standard.data(forKey: "lastUsedFile") {
    ///     let (url, isStale) = try URL.resolve(from: data)
    ///     if isStale {
    ///         // Re-create bookmark with new data
    ///     }
    /// }
    /// ```
    static func resolve(from bookmarkData: Data, isSecurityScoped: Bool = true) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = isSecurityScoped ? [.withSecurityScope] : []
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            return (url, isStale)
        } catch {
            throw FileAccessError.bookmarkResolutionFailed
        }
    }
    
    // MARK: - File Validation
    
    /// Check if the file at this URL exists and is accessible.
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: self.path)
    }
    
    /// Get the file size in bytes, or nil if the file doesn't exist.
    var fileSizeBytes: Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: self.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }
}
