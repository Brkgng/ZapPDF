//
//  StoreConfigurationTests.swift
//  ZapPDFTests
//
//  Unit tests for RevenueCat key normalization behavior.
//

import Testing
@testable import ZapPDF

@Suite("StoreConfiguration Tests")
struct StoreConfigurationTests {

    private func isConfiguredCandidate(_ rawValue: String?) -> Bool {
        StoreConfiguration.normalizedAPIKey(rawValue) != nil
    }

    @Test("normalized API key rejects empty values")
    func normalizedAPIKeyRejectsEmptyValues() {
        #expect(StoreConfiguration.normalizedAPIKey(nil) == nil)
        #expect(StoreConfiguration.normalizedAPIKey("") == nil)
        #expect(StoreConfiguration.normalizedAPIKey("   \n\t") == nil)
    }

    @Test("normalized API key rejects unresolved placeholders")
    func normalizedAPIKeyRejectsUnresolvedPlaceholders() {
        #expect(StoreConfiguration.normalizedAPIKey("$(REVENUECAT_API_KEY)") == nil)
        #expect(StoreConfiguration.normalizedAPIKey("${REVENUECAT_API_KEY}") == nil)
        #expect(StoreConfiguration.normalizedAPIKey("YOUR_PUBLIC_SDK_KEY_HERE") == nil)
    }

    @Test("normalized API key trims and keeps valid value")
    func normalizedAPIKeyKeepsValidValue() {
        #expect(StoreConfiguration.normalizedAPIKey("  apikey_123  ") == "apikey_123")
    }

    @Test("placeholder values are treated as not configured")
    func placeholderValuesAreNotConfigured() {
        #expect(isConfiguredCandidate("$(REVENUECAT_API_KEY)") == false)
        #expect(isConfiguredCandidate("${REVENUECAT_API_KEY}") == false)
        #expect(isConfiguredCandidate("YOUR_PUBLIC_SDK_KEY_HERE") == false)
    }
}
