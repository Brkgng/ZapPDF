//
//  PDFProgressPolicy.swift
//  ZapPDF
//
//  Shared progress policy for multi-stage PDF operations.
//

import Foundation

enum PDFProgressPolicy {
    /// Portion of progress reserved for page-processing work.
    static let processingWeight: Double = 0.90

    /// Start of the finalization phase (write/close/final output flush).
    static let finalizingStart: Double = 0.90

    static func processingProgress(from rawProgress: Double) -> Double {
        clamped(rawProgress) * processingWeight
    }

    static func isFinalizing(_ progress: Double) -> Bool {
        progress >= finalizingStart && progress < 1.0
    }

    private static func clamped(_ progress: Double) -> Double {
        min(max(progress, 0.0), 1.0)
    }
}
