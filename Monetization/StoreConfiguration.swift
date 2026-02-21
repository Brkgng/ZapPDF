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
/// API key lookup order:
/// 1. `REVENUECAT_API_KEY` environment variable
/// 2. `REVENUECAT_API_KEY` in Info.plist
/// 3. Empty string fallback (monetization disabled)
enum StoreConfiguration {

    private static let revenueCatAPIKeyName = "REVENUECAT_API_KEY"
    
    // MARK: - API Key
    
    /// RevenueCat API key.
    static var revenueCatAPIKey: String {
        if let envKey = normalizedAPIKey(ProcessInfo.processInfo.environment[revenueCatAPIKeyName]) {
            return envKey
        }

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

    private static func normalizedAPIKey(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        // Ignore unresolved build variable placeholders.
        if (candidate.hasPrefix("$(") && candidate.hasSuffix(")")) ||
            (candidate.hasPrefix("${") && candidate.hasSuffix("}")) {
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
        
        /// Lifetime Pro purchase
        static let lifetime = "lifetime"
    }
    
    // MARK: - Entitlement Identifiers
    
    /// RevenueCat entitlement identifiers.
    enum EntitlementID {
        /// Pro entitlement granting unlimited PDF operations
        static let pro = "ZapPDF Pro"
    }
}
