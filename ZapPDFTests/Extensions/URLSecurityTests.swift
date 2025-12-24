//
//  URLSecurityTests.swift
//  ZapPDFTests
//
//  Unit tests for URL+Security extension.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("URL+Security Tests")
struct URLSecurityTests {
    
    // MARK: - FileAccessError Tests
    
    @Test("FileAccessError has localized descriptions")
    func fileAccessErrorHasLocalizedDescriptions() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        
        let errors: [FileAccessError] = [
            .securityScopeAccessDenied(testURL),
            .bookmarkResolutionFailed,
            .fileNotFound(testURL),
            .permissionDenied(testURL),
            .bookmarkCreationFailed(testURL)
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("FileAccessError has recovery suggestions")
    func fileAccessErrorHasRecoverySuggestions() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        
        let errors: [FileAccessError] = [
            .securityScopeAccessDenied(testURL),
            .bookmarkResolutionFailed,
            .fileNotFound(testURL),
            .permissionDenied(testURL),
            .bookmarkCreationFailed(testURL)
        ]
        
        for error in errors {
            #expect(error.recoverySuggestion != nil)
            #expect(!error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - Security Scope Tests
    
    @Test("withSecurityScope executes body and returns result")
    func withSecurityScopeExecutesBody() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.txt")
        
        let result = tempURL.withSecurityScope {
            return 42
        }
        
        #expect(result == 42)
    }
    
    @Test("withSecurityScope can throw errors")
    func withSecurityScopeCanThrowErrors() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.txt")
        
        enum TestError: Error { case test }
        
        #expect(throws: TestError.self) {
            try tempURL.withSecurityScope {
                throw TestError.test
            }
        }
    }
    
    @Test("withSecurityScopeAsync executes body and returns result")
    func withSecurityScopeAsyncExecutesBody() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.txt")
        
        let result = await tempURL.withSecurityScopeAsync {
            return "async result"
        }
        
        #expect(result == "async result")
    }
    
    // MARK: - requiresSecurityScope Tests
    
    @Test("Temp directory files don't require security scope")
    func tempFilesDoNotRequireSecurityScope() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.pdf")
        
        #expect(tempURL.requiresSecurityScope == false)
    }
    
    @Test("External files require security scope")
    func externalFilesRequireSecurityScope() {
        let externalURL = URL(fileURLWithPath: "/Users/test/Documents/file.pdf")
        
        #expect(externalURL.requiresSecurityScope == true)
    }
    
    // MARK: - Bookmark Tests
    
    @Test("Can create bookmark data for temp file")
    func canCreateBookmarkDataForTempFile() throws {
        // Create a temporary test file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        
        try "test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Create bookmark
        let bookmarkData = try tempURL.createBookmarkData(isSecurityScoped: false)
        #expect(!bookmarkData.isEmpty)
    }
    
    @Test("Can resolve URL from bookmark data")
    func canResolveURLFromBookmarkData() throws {
        // Create a temporary test file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        
        try "test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Create and resolve bookmark (both without security scope)
        let bookmarkData = try tempURL.createBookmarkData(isSecurityScoped: false)
        let (resolvedURL, isStale) = try URL.resolve(from: bookmarkData, isSecurityScoped: false)
        
        #expect(resolvedURL.path == tempURL.path)
        #expect(isStale == false)
    }
    
    @Test("Bookmark resolution fails for invalid data")
    func bookmarkResolutionFailsForInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        #expect(throws: FileAccessError.self) {
            _ = try URL.resolve(from: invalidData)
        }
    }
    
    // MARK: - File Validation Tests
    
    @Test("fileExists returns false for non-existent file")
    func fileExistsReturnsFalseForNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/file.pdf")
        #expect(nonExistentURL.fileExists == false)
    }
    
    @Test("fileExists returns true for existing file")
    func fileExistsReturnsTrueForExistingFile() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        
        try "test".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        #expect(tempURL.fileExists == true)
    }
    
    @Test("fileSizeBytes returns correct size")
    func fileSizeBytesReturnsCorrectSize() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        
        let content = "Hello, World!"
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let expectedSize = Int64(content.utf8.count)
        #expect(tempURL.fileSizeBytes == expectedSize)
    }
    
    @Test("fileSizeBytes returns nil for non-existent file")
    func fileSizeBytesReturnsNilForNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/file.pdf")
        #expect(nonExistentURL.fileSizeBytes == nil)
    }
}
