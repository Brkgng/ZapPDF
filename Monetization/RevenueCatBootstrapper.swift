//
//  RevenueCatBootstrapper.swift
//  ZapPDF
//
//  Centralized, one-time RevenueCat SDK configuration.
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

enum RevenueCatBootstrapper {
    @MainActor private static var didConfigure = false

    /// Configure RevenueCat SDK once and register a single delegate owner.
    ///
    /// - Returns: `true` when monetization is configured and ready.
    @MainActor
    @discardableResult
    static func configureIfNeeded() -> Bool {
        #if canImport(RevenueCat)
        let apiKey = StoreConfiguration.revenueCatAPIKey
        guard !apiKey.isEmpty else {
            return false
        }

        guard !didConfigure else {
            return true
        }

        // Keep logs actionable in this app by hiding non-critical ATT attribution warnings.
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = RevenueCatDelegateHandler.shared
        didConfigure = true
        return true
        #else
        return false
        #endif
    }
}
