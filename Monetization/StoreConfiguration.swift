//
//  StoreConfiguration.swift
//  ZapPDF
//
//  Centralized configuration for RevenueCat and subscription products.
//

import Foundation

// MARK: - Store Configuration

/// Configuration for RevenueCat SDK and subscription products.
///
/// Security model:
/// - The API key is never committed to source control.
/// - Xcode injects `REVENUECAT_API_KEY` into the generated `Info.plist`
///   from local, gitignored build settings (see `Config/Secrets.local.xcconfig`).
///
/// Runtime lookup order:
/// 1. `REVENUECAT_API_KEY` in bundled `Info.plist` (all builds)
/// 2. Empty string fallback (monetization disabled)
enum StoreConfiguration {

    private static let revenueCatAPIKeyName = "REVENUECAT_API_KEY"
    
    // MARK: - API Key
    
    /// RevenueCat API key.
    static var revenueCatAPIKey: String {
        let plistKey = Bundle.main.object(forInfoDictionaryKey: revenueCatAPIKeyName) as? String
        if let plistKey = normalizedAPIKey(plistKey) {
            return plistKey
        }

        return ""
    }
    
    /// Whether RevenueCat is properly configured.
    static var isConfigured: Bool {
        !revenueCatAPIKey.isEmpty
    }

    /// Normalizes a raw API key candidate by trimming whitespace and rejecting unresolved placeholders.
    /// Internal for unit tests that validate configuration parsing behavior.
    static func normalizedAPIKey(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        // Ignore unresolved build variable placeholders.
        if (candidate.hasPrefix("$(") && candidate.hasSuffix(")")) ||
            (candidate.hasPrefix("${") && candidate.hasSuffix("}")) {
            return nil
        }

        if candidate == "YOUR_PUBLIC_SDK_KEY_HERE" {
            return nil
        }

        return candidate
    }
    
    // MARK: - Product Identifiers
    
    /// Product identifiers matching App Store Connect / RevenueCat configuration.
    enum ProductID {
        /// Monthly Pro subscription
        static let monthly = "monthly"
        
        /// Annual Pro subscription
        static let yearly = "yearly"
        
        /// Canonical lifetime Pro purchase identifier.
        static let lifetime = "lifetime_2026"

        /// Legacy lifetime product identifier used by older purchases.
        static let legacyLifetime = "lifetime"

        /// All monthly identifiers accepted by the app.
        static let monthlyIDs: Set<String> = [monthly]

        /// All yearly identifiers accepted by the app.
        static let yearlyIDs: Set<String> = [yearly]

        /// All lifetime identifiers accepted by the app.
        static let lifetimeIDs: Set<String> = [lifetime, legacyLifetime]
    }
    
    // MARK: - Entitlement Identifiers
    
    /// RevenueCat entitlement identifiers.
    enum EntitlementID {
        /// Pro entitlement granting unlimited PDF operations
        static let pro = "ZapPDF Pro"
    }
}
