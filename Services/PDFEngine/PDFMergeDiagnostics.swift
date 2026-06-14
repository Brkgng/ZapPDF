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

// MARK: - Preflight

/// Conservative preflight thresholds for merge safety.
///
/// `PDFMerger` accumulates the entire output `PDFDocument` in memory before
/// writing, so unbounded merges risk out-of-memory termination on
/// memory-constrained devices. These thresholds are intentionally generous so
/// that only pathological inputs are refused, while the `warn` band surfaces a
/// confirmation for large-but-plausible jobs.
enum MergePreflightLimits {
    /// Page count at or above which the UI warns the user before merging.
    nonisolated static let warnPageThreshold: Int = 750

    /// Hard page cap beyond which the merge is refused.
    nonisolated static let maxPageCount: Int = 2000

    /// Total input bytes at or above which the UI warns the user before merging.
    nonisolated static let warnByteThreshold: Int64 = 200 * 1024 * 1024

    /// Hard input-byte cap beyond which the merge is refused.
    nonisolated static let maxInputBytes: Int64 = 600 * 1024 * 1024
}

/// Risk classification for a prospective merge, derived from its preflight totals.
enum MergePreflightRisk: String, Sendable, Equatable {
    /// Within safe limits; proceed without prompting.
    case safe

    /// Large enough to warrant a user confirmation, but not refused.
    case warn

    /// Exceeds the hard cap; the merge is refused.
    case unsafe
}

/// Pure, I/O-free summary of a prospective merge's size profile.
///
/// Computed from already-known page counts and byte sizes (e.g. from a
/// `[PDFFile]` collection), so it can be evaluated in the UI layer without
/// re-opening any documents.
struct MergePreflightSummary: Sendable, Equatable {
    let totalPages: Int
    let totalBytes: Int64
    let risk: MergePreflightRisk

    /// Classify a prospective merge given its total page count and input bytes.
    ///
    /// Uses `MergePreflightLimits`. The hard cap (`.unsafe`) is checked first,
    /// then the `warn` band. Zero-input merges are considered `.safe` so that
    /// empty-selection states never trigger a prompt.
    nonisolated static func evaluate(totalPages: Int, totalBytes: Int64) -> MergePreflightSummary {
        if totalPages >= MergePreflightLimits.maxPageCount
            || totalBytes >= MergePreflightLimits.maxInputBytes {
            return MergePreflightSummary(
                totalPages: totalPages,
                totalBytes: totalBytes,
                risk: .unsafe
            )
        }

        if totalPages >= MergePreflightLimits.warnPageThreshold
            || totalBytes >= MergePreflightLimits.warnByteThreshold {
            return MergePreflightSummary(
                totalPages: totalPages,
                totalBytes: totalBytes,
                risk: .warn
            )
        }

        return MergePreflightSummary(
            totalPages: totalPages,
            totalBytes: totalBytes,
            risk: .safe
        )
    }
}
