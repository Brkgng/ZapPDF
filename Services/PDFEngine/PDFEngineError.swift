//
//  PDFEngineError.swift
//  ZapPDF
//
//  Common error types for all PDF engine operations.
//

import Foundation

/// Errors that can occur during PDF engine operations.
///
/// These errors cover all failure modes for merge, split, and render operations.
/// Each error provides a user-friendly description and recovery suggestion.
enum PDFEngineError: Error, LocalizedError, Sendable {
    /// The file is not a valid PDF document
    case invalidPDF(URL)
    
    /// The PDF is password protected and cannot be processed
    case passwordProtected(URL)
    
    /// The PDF file appears to be corrupted
    case corruptedFile(URL)
    
    /// Not enough disk space to complete the operation
    case insufficientDiskSpace
    
    /// Failed to write output file
    case writeFailed(URL)
    
    /// Operation was cancelled by user
    case cancelled
    
    /// Requested page range is invalid for the document
    case invalidPageRange(range: ClosedRange<Int>, totalPages: Int)
    
    /// No input files provided
    case emptyInput
    
    /// File not found at the specified URL
    case fileNotFound(URL)

    /// A page could not be loaded from the source document
    case pageLoadFailed(URL, pageIndex: Int)

    /// Failed to merge document outlines/bookmarks
    case outlineMergeFailed(URL)

    /// The merge exceeds the safe preflight limits (page count or input bytes).
    case mergeTooLarge(pageCount: Int, inputBytes: Int64)
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF(let url):
            return L10n.Error.invalidPDF(filename: url.lastPathComponent)
        case .passwordProtected(let url):
            return L10n.Error.passwordProtected(filename: url.lastPathComponent)
        case .corruptedFile(let url):
            return L10n.Error.corruptedFile(filename: url.lastPathComponent)
        case .insufficientDiskSpace:
            return L10n.Error.insufficientDiskSpace
        case .writeFailed(let url):
            return L10n.Error.writeFailed(filename: url.lastPathComponent)
        case .cancelled:
            return L10n.Error.cancelled
        case .invalidPageRange(let range, let totalPages):
            return L10n.Error.invalidPageRange(start: range.lowerBound, end: range.upperBound, total: totalPages)
        case .emptyInput:
            return L10n.Error.emptyInput
        case .fileNotFound(let url):
            return L10n.Error.fileNotFound(filename: url.lastPathComponent)
        case .pageLoadFailed(let url, let pageIndex):
            return L10n.Error.pageLoadFailed(filename: url.lastPathComponent, pageIndex: pageIndex + 1)
        case .outlineMergeFailed(let url):
            return L10n.Error.outlineMergeFailed(filename: url.lastPathComponent)
        case .mergeTooLarge(let pageCount, let inputBytes):
            return L10n.Error.mergeTooLarge(pageCount: pageCount, inputBytes: inputBytes)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidPDF:
            return L10n.Error.selectValidPDF
        case .passwordProtected:
            return L10n.Error.unlockPDF
        case .corruptedFile:
            return L10n.Error.getFreshCopy
        case .insufficientDiskSpace:
            return L10n.Error.freeUpSpace
        case .writeFailed:
            return L10n.Error.checkPermissions
        case .cancelled:
            return nil
        case .invalidPageRange:
            return L10n.Error.selectValidRange
        case .emptyInput:
            return L10n.Error.selectAtLeastOne
        case .fileNotFound:
            return L10n.Error.fileMovedOrDeleted
        case .pageLoadFailed:
            return L10n.Error.tryAnotherPDF
        case .outlineMergeFailed:
            return L10n.Error.tryDisablingBookmarks
        case .mergeTooLarge:
            return L10n.Error.mergeFewerFiles
        }
    }
}
