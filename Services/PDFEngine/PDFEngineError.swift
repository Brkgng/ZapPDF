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
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF(let url):
            return "'\(url.lastPathComponent)' is not a valid PDF file."
        case .passwordProtected(let url):
            return "'\(url.lastPathComponent)' is password protected."
        case .corruptedFile(let url):
            return "'\(url.lastPathComponent)' appears to be corrupted."
        case .insufficientDiskSpace:
            return "Not enough storage space to complete this operation."
        case .writeFailed(let url):
            return "Failed to save '\(url.lastPathComponent)'."
        case .cancelled:
            return "Operation was cancelled."
        case .invalidPageRange(let range, let totalPages):
            return "Page range \(range.lowerBound)-\(range.upperBound) is invalid. Document has \(totalPages) pages."
        case .emptyInput:
            return "No files provided for this operation."
        case .fileNotFound(let url):
            return "File not found: '\(url.lastPathComponent)'."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidPDF:
            return "Please select a valid PDF file."
        case .passwordProtected:
            return "Please unlock the PDF using another application first."
        case .corruptedFile:
            return "Try obtaining a fresh copy of this file."
        case .insufficientDiskSpace:
            return "Free up some storage space and try again."
        case .writeFailed:
            return "Check that you have write permission to the destination."
        case .cancelled:
            return nil
        case .invalidPageRange:
            return "Please select a valid page range within the document."
        case .emptyInput:
            return "Please select at least one PDF file."
        case .fileNotFound:
            return "The file may have been moved or deleted."
        }
    }
}
