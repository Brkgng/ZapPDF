//
//  MockSubscriptionManager.swift
//  ZapPDFTests
//
//  Mock implementation of SubscriptionManaging for unit testing.
//

import Foundation
@testable import ZapPDF

/// Mock subscription manager for testing PaywallViewModel and purchase flows.
actor MockSubscriptionManager: SubscriptionManaging {
    
    // MARK: - Mock State
    
    var isPro: Bool = false
    var availablePackages: [SubscriptionPackage] = []
    
    // MARK: - Control Properties
    
    private var shouldThrowOnPurchase: Bool = false
    private var purchaseReturnsSuccess: Bool = true
    private var restoreReturnsSuccess: Bool = false
    private var shouldThrowOnRestore: Bool = false
    
    // MARK: - SubscriptionManaging
    

    
    func purchase(_ package: SubscriptionPackage) async throws -> Bool {
        if shouldThrowOnPurchase {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock purchase error"])
        }
        
        if purchaseReturnsSuccess {
            isPro = true
        }
        return purchaseReturnsSuccess
    }
    
    func restorePurchases() async throws -> Bool {
        if shouldThrowOnRestore {
            throw NSError(domain: "MockError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Mock restore error"])
        }
        
        if restoreReturnsSuccess {
            isPro = true
        }
        return restoreReturnsSuccess
    }
    
    func refreshStatus() async {
        // No-op for tests
    }
    
    // MARK: - Test Helpers
    
    func setMockPro(_ value: Bool) {
        isPro = value
    }
    
    func setMockPackages(_ packages: [SubscriptionPackage]) {
        availablePackages = packages
    }
    
    func setShouldThrowOnPurchase(_ value: Bool) {
        shouldThrowOnPurchase = value
    }
    
    func setPurchaseReturnsSuccess(_ value: Bool) {
        purchaseReturnsSuccess = value
    }
    
    func setRestoreReturnsSuccess(_ value: Bool) {
        restoreReturnsSuccess = value
    }
    
    func setShouldThrowOnRestore(_ value: Bool) {
        shouldThrowOnRestore = value
    }
}

// MARK: - Mock Package Helpers

extension SubscriptionPackage {
    /// Creates a mock monthly package for testing.
    static func mockMonthly(price: String = "$4.99/mo") -> SubscriptionPackage {
        SubscriptionPackage(
            id: "mock_monthly",
            packageType: .monthly,
            localizedPriceString: price,
            localizedTitle: "Pro Monthly"
        )
    }
    
    /// Creates a mock annual package for testing.
    static func mockAnnual(price: String = "$29.99/yr") -> SubscriptionPackage {
        SubscriptionPackage(
            id: "mock_annual",
            packageType: .annual,
            localizedPriceString: price,
            localizedTitle: "Pro Annual"
        )
    }
    
    /// Creates a mock lifetime package for testing.
    static func mockLifetime(price: String = "$49.99") -> SubscriptionPackage {
        SubscriptionPackage(
            id: "mock_lifetime",
            packageType: .lifetime,
            localizedPriceString: price,
            localizedTitle: "Pro Lifetime"
        )
    }
}
