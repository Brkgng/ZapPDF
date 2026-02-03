//
//  DocumentScannerError.swift
//  ZapPDF
//
//  Error types for document scanning operations.
//

#if os(iOS)
import Foundation

/// Errors that can occur during document scanning.
enum DocumentScannerError: Error, LocalizedError, Equatable {
    case notSupported
    case cancelled
    case cameraError(String)
    case noImagesProvided
    case imageConversionFailed(Int)
    case allPagesFailedToConvert
    case pdfWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return L10n.Scanner.errorNotSupported
        case .cancelled:
            return nil // User-initiated, no error message needed
        case .cameraError(let detail):
            return L10n.Scanner.errorCamera(detail)
        case .noImagesProvided:
            return L10n.Scanner.errorNoImages
        case .imageConversionFailed(let pageIndex):
            return L10n.Scanner.errorConversionFailed(pageIndex + 1)
        case .allPagesFailedToConvert:
            return L10n.Scanner.errorAllPagesFailed
        case .pdfWriteFailed:
            return L10n.Scanner.errorPDFWriteFailed
        }
    }
    
    // Equatable for error comparison (e.g., checking if cancelled)
    static func == (lhs: DocumentScannerError, rhs: DocumentScannerError) -> Bool {
        switch (lhs, rhs) {
        case (.notSupported, .notSupported),
             (.cancelled, .cancelled),
             (.noImagesProvided, .noImagesProvided),
             (.allPagesFailedToConvert, .allPagesFailedToConvert),
             (.pdfWriteFailed, .pdfWriteFailed):
            return true
        case (.cameraError(let a), .cameraError(let b)):
            return a == b
        case (.imageConversionFailed(let a), .imageConversionFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}
#endif
