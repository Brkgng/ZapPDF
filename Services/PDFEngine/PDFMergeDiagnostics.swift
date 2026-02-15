//
//  PDFMergeDiagnostics.swift
//  ZapPDF
//
//  Types describing merge output diagnostics and anomaly detection.
//

import Foundation

/// Strategy used when serializing merged output.
enum MergeWriteProfile: String, Sendable, Codable {
    /// Preserve source fidelity and avoid lossy image transforms.
    case losslessPreserve

    /// Allow screen-optimized image encoding (lossy).
    case screenOptimizedLossy
}

/// Size anomaly classification for merged output.
enum MergeAnomaly: String, Sendable, Codable {
    case none
    case excessiveGrowth
    case unexpectedShrink
}

/// Diagnostics captured for a merge result.
struct MergeDiagnostics: Sendable, Equatable {
    let inputBytes: Int64
    let outputBytes: Int64
    let growthFactor: Double
    let pageCount: Int
    let writeProfile: MergeWriteProfile
    let anomaly: MergeAnomaly
}

/// Rich merge result containing output location and diagnostics.
struct PDFMergeResult: Sendable, Equatable {
    let outputURL: URL
    let diagnostics: MergeDiagnostics
}
