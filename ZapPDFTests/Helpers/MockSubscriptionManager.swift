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
    var proStatus: ProStatus = .inactive
    var availablePackages: [SubscriptionPackage] = []
    
    // MARK: - Control Properties
    
    private var shouldThrowOnPurchase: Bool = false
    private var purchaseReturnsSuccess: Bool = true
    private var restoreReturnsSuccess: Bool = false
    private var shouldThrowOnRestore: Bool = false
    private var mockProType: ProType = .annual
    
    // MARK: - SubscriptionManaging
    
    func purchase(_ package: SubscriptionPackage) async throws -> Bool {
        if shouldThrowOnPurchase {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock purchase error"])
        }
        
        if purchaseReturnsSuccess {
            isPro = true
            proStatus = createProStatus(for: package.packageType)
        }
        return purchaseReturnsSuccess
    }
    
    func restorePurchases() async throws -> Bool {
        if shouldThrowOnRestore {
            throw NSError(domain: "MockError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Mock restore error"])
        }
        
        if restoreReturnsSuccess {
            isPro = true
            proStatus = createProStatus(for: mockProType)
        }
        return restoreReturnsSuccess
    }
    
    func refreshStatus() async {
        // No-op for tests
    }
    
    // MARK: - Helper
    
    private func createProStatus(for packageType: SubscriptionPackageType) -> ProStatus {
        createProStatus(for: mapToProType(packageType))
    }
    
    private func createProStatus(for type: ProType) -> ProStatus {
        ProStatus(
            isActive: true,
            type: type,
            expirationDate: type == .lifetime ? nil : Date().addingTimeInterval(365 * 24 * 60 * 60),
            willRenew: type != .lifetime,
            productIdentifier: "mock_\(type.rawValue)"
        )
    }
    
    private func mapToProType(_ packageType: SubscriptionPackageType) -> ProType {
        switch packageType {
        case .monthly: return .monthly
        case .annual: return .annual
        case .lifetime: return .lifetime
        case .unknown: return .annual
        }
    }
    
    // MARK: - Test Helpers
    
    func setMockPro(_ value: Bool, type: ProType = .annual) {
        isPro = value
        proStatus = value ? createProStatus(for: type) : .inactive
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
    
    func setRestoreReturnsSuccess(_ value: Bool, proType: ProType = .annual) {
        restoreReturnsSuccess = value
        mockProType = proType
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
