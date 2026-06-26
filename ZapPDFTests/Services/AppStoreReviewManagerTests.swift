//
//  AppStoreReviewManagerTests.swift
//  ZapPDFTests
//
//  Tests for AppStoreReviewManager.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("AppStoreReviewManager Tests", .serialized)
struct AppStoreReviewManagerTests {

    // MARK: - Helper

    /// Reset state before each test using shared instance
    private func resetManager() async {
        await AppStoreReviewManager.shared.resetForTesting()
    }

    // MARK: - Should Show And Mark Tests

    @Test("Returns true on first launch")
    func returnsTrueOnFirstLaunch() async {
        await resetManager()

        let shouldShow = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        #expect(shouldShow == true, "Should show review prompt on first launch")
    }

    @Test("Returns false after already shown this launch")
    func returnsFalseAfterShownThisLaunch() async {
        await resetManager()

        // First call marks as shown
        _ = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        // Second call should return false
        let secondCheck = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        #expect(secondCheck == false, "Should not show after already shown this launch")
    }

    // MARK: - Version Tracking Tests

    @Test("Persists across launch simulation")
    func persistsAcrossLaunchSimulation() async {
        await resetManager()

        // Mark as shown for current version
        _ = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        // Simulate a new launch by resetting only in-memory state.
        await AppStoreReviewManager.shared.resetLaunchStateForTesting()

        let afterMark = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        #expect(afterMark == false, "Should not show after version already prompted")
    }

    // MARK: - Reset Tests

    @Test("Reset clears all state")
    func resetClearsAllState() async {
        await resetManager()

        // Mark as shown
        _ = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        // Reset
        await AppStoreReviewManager.shared.resetForTesting()

        #expect(
            UserDefaults.standard.string(forKey: AppStoreReviewManager.lastPromptedVersionDefaultsKey) == nil,
            "Reset should clear persisted review prompt version"
        )

        // Should show again
        let afterReset = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        #expect(afterReset == true, "Should show again after reset")
    }

    @Test("Multiple resets do not cause errors")
    func multipleResetsDoNotCauseErrors() async {
        await AppStoreReviewManager.shared.resetForTesting()
        await AppStoreReviewManager.shared.resetForTesting()
        await AppStoreReviewManager.shared.resetForTesting()

        let shouldShow = await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt()

        #expect(shouldShow == true, "Multiple resets should not cause issues")
    }
}
