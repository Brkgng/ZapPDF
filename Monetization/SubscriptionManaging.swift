//
//  SubscriptionManaging.swift
//  ZapPDF
//
//  Protocol for subscription management dependency injection.
//

import Foundation

// MARK: - Package Type (RevenueCat-compatible)

/// Represents a subscription package type.
///
/// Mirrors RevenueCat's `PackageType` for use in UI without tight SDK coupling.
enum SubscriptionPackageType: String, Sendable {
    case monthly
    case annual
    case lifetime
    case unknown
}

// MARK: - Subscription Package

/// A subscription package available for purchase.
///
/// Abstracts RevenueCat's `Package` for testability and UI use.
struct SubscriptionPackage: Identifiable, Sendable {
    let id: String
    let packageType: SubscriptionPackageType
    let localizedPriceString: String
    let localizedTitle: String
    
    /// Underlying RevenueCat package (nil for mocks)
    let rcPackage: Any?
    
    init(
        id: String,
        packageType: SubscriptionPackageType,
        localizedPriceString: String,
        localizedTitle: String,
        rcPackage: Any? = nil
    ) {
        self.id = id
        self.packageType = packageType
        self.localizedPriceString = localizedPriceString
        self.localizedTitle = localizedTitle
        self.rcPackage = rcPackage
    }
}

// MARK: - Subscription Managing Protocol

/// Protocol for managing subscriptions and entitlements.
///
/// This protocol enables dependency injection for testing.
/// The real implementation uses RevenueCat SDK; tests use a mock.
///
/// Example:
/// ```swift
/// let manager: any SubscriptionManaging = RevenueCatManager.shared
///
/// if await manager.isPro {
///     // User has Pro entitlement
/// }
/// ```
protocol SubscriptionManaging: Actor {
    
    /// Whether the user currently has Pro entitlement.
    var isPro: Bool { get async }
    
    /// Detailed subscription status including type, expiration, and renewal info.
    var proStatus: ProStatus { get async }
    
    /// Available subscription packages for purchase.
    var availablePackages: [SubscriptionPackage] { get async }
    
    /// Purchase a subscription package.
    ///
    /// - Parameter package: The package to purchase
    /// - Returns: `true` if purchase succeeded, `false` if user cancelled
    /// - Throws: Purchase errors from the payment system
    func purchase(_ package: SubscriptionPackage) async throws -> Bool
    
    /// Restore previous purchases.
    ///
    /// - Returns: `true` if Pro entitlement was restored
    /// - Throws: Restore errors from the payment system
    func restorePurchases() async throws -> Bool
    
    /// Refresh subscription status from the server.
    func refreshStatus() async
}
