//
//  MonetizationAvailability.swift
//  ZapPDF
//
//  Centralized feature gate for monetization-dependent UI/flows.
//

import Foundation

enum MonetizationAvailability {
    enum State: Equatable {
        case enabled
        case disabled(message: String)
    }

    /// Resolved monetization state derived from runtime configuration.
    static var state: State {
        if StoreConfiguration.isConfigured {
            return .enabled
        }
        return .disabled(message: L10n.Monetization.unavailable)
    }

    static var isEnabled: Bool {
        if case .enabled = state {
            return true
        }
        return false
    }

    /// User-facing fallback copy used when monetization is disabled in this build.
    static var unavailableMessage: String {
        switch state {
        case .enabled:
            return L10n.Monetization.unavailable
        case .disabled(let message):
            return message
        }
    }
}
