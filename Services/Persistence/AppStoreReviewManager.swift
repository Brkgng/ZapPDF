//
//  AppStoreReviewManager.swift
//  ZapPDF
//
//  Actor managing App Store review prompt eligibility.
//

import Foundation

/// Actor managing App Store review prompt eligibility with thread-safe operations.
///
/// `AppStoreReviewManager` tracks whether a review prompt should be shown
/// based on app version and per-launch state. It follows Apple's guidelines
/// for requesting reviews at appropriate moments.
///
/// - Important: Methods are actor-isolated. Use `await` when calling from MainActor.
///
/// Example:
/// ```swift
/// Task {
///     if await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt() {
///         requestReview()  // SwiftUI environment action
///     }
/// }
/// ```
actor AppStoreReviewManager: ReviewPromptManaging {

    // MARK: - Singleton

    /// Shared singleton instance.
    static let shared = AppStoreReviewManager()

    // MARK: - Private Properties

    /// Track if review has been shown this app launch
    private var hasShownReviewThisLaunch: Bool = false

    // MARK: - Computed Properties

    /// Current app version from Info.plist
    private var currentAppVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    // MARK: - Initialization

    /// Private initializer to enforce singleton usage.
    /// Use `AppStoreReviewManager.shared` instead.
    private init() {}

    // MARK: - Public Methods

    func shouldShowAndMarkReviewPrompt() async -> Bool {
        // Already shown this launch?
        guard !hasShownReviewThisLaunch else { return false }

        // Get current version
        guard let version = currentAppVersion else { return false }

        // Check if already prompted for this version
        if let lastPromptedVersion = try? KeychainHelper.loadString(for: .lastReviewPromptVersion),
           lastPromptedVersion == version {
            return false
        }

        // Atomically mark as shown before returning true
        hasShownReviewThisLaunch = true
        do {
            try KeychainHelper.saveString(version, for: .lastReviewPromptVersion)
        } catch {
            #if DEBUG
            print("AppStoreReviewManager: Failed to save version to Keychain: \(error)")
            #endif
        }

        return true
    }

    /// Reset all review prompt state.
    ///
    /// - Important: This method is only available in DEBUG builds for testing purposes.
    func resetForTesting() async {
        #if DEBUG
        hasShownReviewThisLaunch = false
        try? KeychainHelper.delete(for: .lastReviewPromptVersion)
        #endif
    }
}
