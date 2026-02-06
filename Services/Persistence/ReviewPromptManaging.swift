//
//  ReviewPromptManaging.swift
//  ZapPDF
//
//  Protocol for App Store review prompt management.
//

import Foundation

/// Protocol defining review prompt management operations.
///
/// This protocol enables dependency injection for testing by
/// abstracting the review prompt eligibility logic.
///
/// - Important: All methods are actor-isolated. Callers must use `await`
///   when calling from non-isolated contexts (e.g., MainActor views).
///
/// Example from a SwiftUI view:
/// ```swift
/// Task {
///     if await reviewManager.shouldShowAndMarkReviewPrompt() {
///         requestReview()  // SwiftUI environment action
///     }
/// }
/// ```
protocol ReviewPromptManaging: Sendable {
    /// Atomically check eligibility and mark as shown if eligible.
    ///
    /// This method combines the check and mark operations to prevent
    /// race conditions where multiple callers could both receive `true`.
    ///
    /// - Returns: `true` if a review prompt should be shown (and marks as shown),
    ///            `false` if ineligible (already shown this launch or version)
    func shouldShowAndMarkReviewPrompt() async -> Bool

    /// Reset all review prompt state (DEBUG builds only, for testing).
    func resetForTesting() async
}
