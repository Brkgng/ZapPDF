//
//  RevenueCatManagerTests.swift
//  ZapPDFTests
//
//  Unit tests for RevenueCatManager.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("RevenueCatManager Tests")
struct RevenueCatManagerTests {
    
    // MARK: - Initial State Tests
    
    @Test("Initial state is not Pro")
    func initialStateIsNotPro() async {
        #if DEBUG
        let manager = RevenueCatManager.createTestInstance()
        let isPro = await manager.isPro
        #expect(isPro == false)
        #endif
    }
    
    // MARK: - Configuration Tests
    
    @Test("StoreConfiguration configuration check")
    func storeConfigurationCheck() {
        let key = StoreConfiguration.revenueCatAPIKey
        #expect(StoreConfiguration.isConfigured == !key.isEmpty)
    }
    
    @Test("Product IDs are correctly defined")
    func productIDsAreCorrectlyDefined() {
        #expect(StoreConfiguration.ProductID.monthly == "monthly")
        #expect(StoreConfiguration.ProductID.yearly == "yearly")
        #expect(StoreConfiguration.ProductID.lifetime == "lifetime")
    }
    
    @Test("Entitlement ID is correctly defined")
    func entitlementIDIsCorrectlyDefined() {
        #expect(StoreConfiguration.EntitlementID.pro == "ZapPDF Pro")
    }
    
    // MARK: - SubscriptionPackage Tests
    
    @Test("SubscriptionPackage initialization works")
    func subscriptionPackageInitialization() {
        let package = SubscriptionPackage(
            id: "test_id",
            packageType: .monthly,
            localizedPriceString: "$4.99",
            localizedTitle: "Test Package"
        )
        
        #expect(package.id == "test_id")
        #expect(package.packageType == .monthly)
        #expect(package.localizedPriceString == "$4.99")
        #expect(package.localizedTitle == "Test Package")
        #expect(package.rcPackage == nil)
    }
    

    
    // MARK: - PurchaseError Tests
    
    @Test("PurchaseError has correct descriptions")
    func purchaseErrorDescriptions() {
        let notConfigured = PurchaseError.notConfigured
        let invalidPackage = PurchaseError.invalidPackage
        
        #expect(notConfigured.errorDescription != nil)
        #expect(invalidPackage.errorDescription != nil)
    }
}
