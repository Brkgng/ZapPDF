//
//  AppDelegate.swift
//  ZapPDF
//
//  iOS App Delegate for synchronous SDK initialization.
//

#if os(iOS)
import UIKit

#if canImport(RevenueCat)
import RevenueCat
#endif

/// App delegate for iOS to handle synchronous SDK configuration.
///
/// RevenueCat recommends configuring in `application:didFinishLaunchingWithOptions:`
/// for accuracy, ensuring SDK is ready before any views query subscription status.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureRevenueCat()
        return true
    }
    
    private func configureRevenueCat() {
        #if canImport(RevenueCat)
        let apiKey = StoreConfiguration.revenueCatAPIKey
        guard !apiKey.isEmpty else {
            return
        }
        
        // Configure synchronously before any views load
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        
        // Register delegate immediately, but defer all non-essential fetches.
        Purchases.shared.delegate = RevenueCatDelegateHandler.shared
        #endif
    }
}
#endif
