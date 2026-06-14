//
//  MergePreflightSummaryTests.swift
//  ZapPDFTests
//
//  Unit tests for MergePreflightSummary risk classification (W8 preflight guard).
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("Merge Preflight Summary")
struct MergePreflightSummaryTests {

    // MARK: - Safe band

    @Test("Small merge is safe")
    func smallMergeIsSafe() {
        let summary = MergePreflightSummary.evaluate(totalPages: 10, totalBytes: 1_000_000)
        #expect(summary.risk == .safe)
        #expect(summary.totalPages == 10)
        #expect(summary.totalBytes == 1_000_000)
    }

    @Test("Just under page warn threshold is safe")
    func justUnderPageWarnThresholdIsSafe() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: MergePreflightLimits.warnPageThreshold - 1,
            totalBytes: 0
        )
        #expect(summary.risk == .safe)
    }

    @Test("Just under byte warn threshold is safe")
    func justUnderByteWarnThresholdIsSafe() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: 0,
            totalBytes: MergePreflightLimits.warnByteThreshold - 1
        )
        #expect(summary.risk == .safe)
    }

    @Test("Zero input is safe")
    func zeroInputIsSafe() {
        let summary = MergePreflightSummary.evaluate(totalPages: 0, totalBytes: 0)
        #expect(summary.risk == .safe)
    }

    // MARK: - Warn band

    @Test("At page warn threshold warns")
    func atPageWarnThresholdWarns() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: MergePreflightLimits.warnPageThreshold,
            totalBytes: 0
        )
        #expect(summary.risk == .warn)
    }

    @Test("At byte warn threshold warns")
    func atByteWarnThresholdWarns() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: 0,
            totalBytes: MergePreflightLimits.warnByteThreshold
        )
        #expect(summary.risk == .warn)
    }

    @Test("Just under page hard cap still warns")
    func justUnderPageHardCapWarns() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: MergePreflightLimits.maxPageCount - 1,
            totalBytes: 0
        )
        #expect(summary.risk == .warn)
    }

    @Test("Just under byte hard cap still warns")
    func justUnderByteHardCapWarns() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: 0,
            totalBytes: MergePreflightLimits.maxInputBytes - 1
        )
        #expect(summary.risk == .warn)
    }

    // MARK: - Unsafe band (hard cap)

    @Test("At page hard cap is unsafe")
    func atPageHardCapIsUnsafe() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: MergePreflightLimits.maxPageCount,
            totalBytes: 0
        )
        #expect(summary.risk == .unsafe)
    }

    @Test("At byte hard cap is unsafe")
    func atByteHardCapIsUnsafe() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: 0,
            totalBytes: MergePreflightLimits.maxInputBytes
        )
        #expect(summary.risk == .unsafe)
    }

    @Test("Far over both limits is unsafe")
    func farOverBothLimitsIsUnsafe() {
        let summary = MergePreflightSummary.evaluate(
            totalPages: MergePreflightLimits.maxPageCount * 5,
            totalBytes: MergePreflightLimits.maxInputBytes * 5
        )
        #expect(summary.risk == .unsafe)
    }

    // MARK: - Summary value passthrough

    @Test("Summary echoes input totals")
    func summaryEchoesInputTotals() {
        let summary = MergePreflightSummary.evaluate(totalPages: 4321, totalBytes: 999)
        #expect(summary.totalPages == 4321)
        #expect(summary.totalBytes == 999)
    }
}
