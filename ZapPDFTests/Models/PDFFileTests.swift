//
//  PDFFileTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFFile model.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("PDFFile Tests")
struct PDFFileTests {
    
    // MARK: - PDFFileError Tests
    
    @Test("PDFFileError has localized descriptions")
    func pdfFileErrorHasLocalizedDescriptions() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        
        let errors: [PDFFileError] = [
            .fileNotFound(testURL),
            .invalidPDF(testURL),
            .passwordProtected(testURL),
            .accessDenied(testURL)
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("PDFFileError has recovery suggestions")
    func pdfFileErrorHasRecoverySuggestions() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        
        let errors: [PDFFileError] = [
            .fileNotFound(testURL),
            .invalidPDF(testURL),
            .passwordProtected(testURL),
            .accessDenied(testURL)
        ]
        
        for error in errors {
            #expect(error.recoverySuggestion != nil)
            #expect(!error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - PDFFile Initialization Tests
    
    @Test("PDFFile internal initializer sets all properties")
    func internalInitializerSetsAllProperties() {
        let testURL = URL(fileURLWithPath: "/test/file.pdf")
        let testID = UUID()
        let testDate = Date()
        let testBookmark = Data([0x01, 0x02, 0x03])
        
        let pdfFile = PDFFile(
            id: testID,
            url: testURL,
            fileName: "file.pdf",
            pageCount: 10,
            fileSize: 1024,
            bookmarkData: testBookmark,
            modificationDate: testDate
        )
        
        #expect(pdfFile.id == testID)
        #expect(pdfFile.url == testURL)
        #expect(pdfFile.fileName == "file.pdf")
        #expect(pdfFile.pageCount == 10)
        #expect(pdfFile.fileSize == 1024)
        #expect(pdfFile.bookmarkData == testBookmark)
        #expect(pdfFile.modificationDate == testDate)
    }
    
    @Test("formattedFileSize formats bytes correctly")
    func formattedFileSizeFormatsCorrectly() {
        let smallFile = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 500
        )
        
        let mediumFile = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 1024 * 1024  // 1 MB
        )
        
        #expect(smallFile.formattedFileSize.contains("bytes") || smallFile.formattedFileSize.contains("KB"))
        #expect(mediumFile.formattedFileSize.contains("MB"))
    }
    
    @Test("hasValidBookmark returns correct value")
    func hasValidBookmarkReturnsCorrectValue() {
        let withBookmark = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 1024,
            bookmarkData: Data([0x01])
        )
        
        let withoutBookmark = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 1024,
            bookmarkData: nil
        )
        
        #expect(withBookmark.hasValidBookmark == true)
        #expect(withoutBookmark.hasValidBookmark == false)
    }
    
    // MARK: - Hashable & Equatable Tests
    
    @Test("PDFFiles with same ID are equal")
    func pdfFilesWithSameIDAreEqual() {
        let sharedID = UUID()
        
        let file1 = PDFFile(
            id: sharedID,
            url: URL(fileURLWithPath: "/file1.pdf"),
            fileName: "file1.pdf",
            pageCount: 5,
            fileSize: 100
        )
        
        let file2 = PDFFile(
            id: sharedID,
            url: URL(fileURLWithPath: "/file2.pdf"),
            fileName: "file2.pdf",
            pageCount: 10,
            fileSize: 200
        )
        
        #expect(file1 == file2)
        #expect(file1.hashValue == file2.hashValue)
    }
    
    @Test("PDFFiles with different IDs are not equal")
    func pdfFilesWithDifferentIDsAreNotEqual() {
        let file1 = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 100
        )
        
        let file2 = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 1,
            fileSize: 100
        )
        
        #expect(file1 != file2)  // Different IDs despite same content
    }
    
    // MARK: - Collection Extension Tests
    
    @Test("Array extension calculates total page count")
    func arrayExtensionCalculatesTotalPageCount() {
        let files = [
            PDFFile(url: URL(fileURLWithPath: "/1.pdf"), fileName: "1.pdf", pageCount: 5, fileSize: 100),
            PDFFile(url: URL(fileURLWithPath: "/2.pdf"), fileName: "2.pdf", pageCount: 10, fileSize: 200),
            PDFFile(url: URL(fileURLWithPath: "/3.pdf"), fileName: "3.pdf", pageCount: 3, fileSize: 50)
        ]
        
        #expect(files.totalPageCount == 18)
    }
    
    @Test("Array extension calculates total file size")
    func arrayExtensionCalculatesTotalFileSize() {
        let files = [
            PDFFile(url: URL(fileURLWithPath: "/1.pdf"), fileName: "1.pdf", pageCount: 1, fileSize: 100),
            PDFFile(url: URL(fileURLWithPath: "/2.pdf"), fileName: "2.pdf", pageCount: 1, fileSize: 200),
            PDFFile(url: URL(fileURLWithPath: "/3.pdf"), fileName: "3.pdf", pageCount: 1, fileSize: 300)
        ]
        
        #expect(files.totalFileSize == 600)
    }
    
    @Test("Empty array has zero total page count")
    func emptyArrayHasZeroTotalPageCount() {
        let files: [PDFFile] = []
        #expect(files.totalPageCount == 0)
        #expect(files.totalFileSize == 0)
    }
    
    @Test("formattedTotalSize returns human readable string")
    func formattedTotalSizeReturnsHumanReadableString() {
        let files = [
            PDFFile(url: URL(fileURLWithPath: "/1.pdf"), fileName: "1.pdf", pageCount: 1, fileSize: 1024 * 1024)  // 1 MB
        ]
        
        #expect(files.formattedTotalSize.contains("MB"))
    }
}
