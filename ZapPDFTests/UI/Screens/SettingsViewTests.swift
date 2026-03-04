//
//  SettingsViewTests.swift
//  ZapPDFTests
//
//  Unit tests for Settings subscription status presentation logic.
//

import Foundation
import Testing
@testable import ZapPDF

@Suite("Settings Subscription Status Tests")
struct SettingsSubscriptionStatusTests {

    private func testDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    @Test("Free plan shows upgrade CTA when monetization is enabled")
    func freePlanShowsUpgradeCTAWhenMonetizationEnabled() {
        let state = SubscriptionStatusDisplayState.make(
            proStatus: nil,
            offlinePro: false,
            monetizationEnabled: true
        )

        #expect(state.statusText == L10n.Settings.freePlan)
        #expect(state.statusIcon == "person.fill")
        #expect(state.statusSubtitle == nil)
        #expect(state.showsUpgradeCTA == true)
    }

    @Test("Free plan hides upgrade CTA when monetization is disabled")
    func freePlanHidesUpgradeCTAWhenMonetizationDisabled() {
        let state = SubscriptionStatusDisplayState.make(
            proStatus: nil,
            offlinePro: false,
            monetizationEnabled: false
        )

        #expect(state.statusText == L10n.Settings.freePlan)
        #expect(state.statusIcon == "person.fill")
        #expect(state.statusSubtitle == nil)
        #expect(state.showsUpgradeCTA == false)
    }

    @Test("Offline pro status does not show upgrade CTA")
    func offlineProStatusDoesNotShowUpgradeCTA() {
        let state = SubscriptionStatusDisplayState.make(
            proStatus: nil,
            offlinePro: true,
            monetizationEnabled: true
        )

        #expect(state.statusText == L10n.Settings.proPlan)
        #expect(state.statusIcon == "star.fill")
        #expect(state.statusSubtitle == nil)
        #expect(state.showsUpgradeCTA == false)
    }

    @Test("Annual renewing status shows renews subtitle")
    func annualRenewingStatusShowsRenewsSubtitle() {
        let formatter = testDateFormatter()
        let expirationDate = Date(timeIntervalSince1970: 1_750_000_000)
        let status = ProStatus(
            isActive: true,
            type: .annual,
            expirationDate: expirationDate,
            willRenew: true,
            productIdentifier: "yearly"
        )

        let state = SubscriptionStatusDisplayState.make(
            proStatus: status,
            offlinePro: false,
            monetizationEnabled: true,
            dateFormatter: formatter
        )

        #expect(state.statusText == L10n.Settings.proAnnual)
        #expect(state.statusIcon == "star.fill")
        #expect(state.statusSubtitle == L10n.Settings.renewsOn(formatter.string(from: expirationDate)))
        #expect(state.showsUpgradeCTA == false)
    }

    @Test("Annual non-renewing status shows expires subtitle")
    func annualNonRenewingStatusShowsExpiresSubtitle() {
        let formatter = testDateFormatter()
        let expirationDate = Date(timeIntervalSince1970: 1_760_000_000)
        let status = ProStatus(
            isActive: true,
            type: .annual,
            expirationDate: expirationDate,
            willRenew: false,
            productIdentifier: "yearly"
        )

        let state = SubscriptionStatusDisplayState.make(
            proStatus: status,
            offlinePro: false,
            monetizationEnabled: true,
            dateFormatter: formatter
        )

        #expect(state.statusText == L10n.Settings.proAnnual)
        #expect(state.statusIcon == "star.fill")
        #expect(state.statusSubtitle == L10n.Settings.expiresOn(formatter.string(from: expirationDate)))
        #expect(state.showsUpgradeCTA == false)
    }

    @Test("Lifetime status has no subtitle and no CTA")
    func lifetimeStatusHasNoSubtitleAndNoCTA() {
        let status = ProStatus(
            isActive: true,
            type: .lifetime,
            expirationDate: nil,
            willRenew: nil,
            productIdentifier: "lifetime_2026"
        )

        let state = SubscriptionStatusDisplayState.make(
            proStatus: status,
            offlinePro: false,
            monetizationEnabled: true
        )

        #expect(state.statusText == L10n.Settings.proLifetime)
        #expect(state.statusIcon == "star.fill")
        #expect(state.statusSubtitle == nil)
        #expect(state.showsUpgradeCTA == false)
    }
}
