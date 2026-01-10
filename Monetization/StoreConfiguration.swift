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
/// API keys are read from Info.plist at runtime, populated via
/// `Secrets.xcconfig` at build time. This keeps secrets out of
/// version control for this open-source project.
///
/// Setup:
/// 1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`
/// 2. Fill in your RevenueCat API key
/// 3. Build the project
enum StoreConfiguration {
    
    // MARK: - API Key
    
    /// RevenueCat API key.
    static var revenueCatAPIKey: String {
        return Secrets.revenueCatAPIKey
    }
    
    /// Whether RevenueCat is properly configured.
    static var isConfigured: Bool {
        !revenueCatAPIKey.isEmpty
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
