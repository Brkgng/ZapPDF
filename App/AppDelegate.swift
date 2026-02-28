//
//  AppDelegate.swift
//  ZapPDF
//
//  iOS App Delegate for synchronous SDK initialization.
//

#if os(iOS)
import UIKit

/// App delegate for iOS to handle synchronous SDK configuration.
///
/// RevenueCat recommends configuring in `application:didFinishLaunchingWithOptions:`
/// for accuracy, ensuring SDK is ready before any views query subscription status.
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureRevenueCat()
        return true
    }
    
    private func configureRevenueCat() {
        _ = RevenueCatBootstrapper.configureIfNeeded()
    }
}
#endif
