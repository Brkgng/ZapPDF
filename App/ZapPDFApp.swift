//
//  ZapPDFApp.swift
//  ZapPDF
//
//  Created by Berker Güngör on 23.12.2025.
//

import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct ZapPDFApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    /// iOS App Delegate for synchronous SDK configuration.
    #if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif
    
    /// Shared language manager for app-wide locale control.
    @State private var languageManager = LanguageManager.shared
    
    /// Shared DashboardViewModel for receiving external files via Share Sheet / "Open In".
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    init() {
        // UNCOMMENT the line below to reset onboarding state for debugging
        // UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        
        #if os(macOS)
        // macOS: Configure RevenueCat synchronously in init
        // (iOS uses AppDelegate for earlier configuration)
        configureRevenueCatMacOS()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(languageManager)
                .environment(\.locale, languageManager.currentLocale)
                .environmentObject(dashboardViewModel)  // Inject for external file handling
                #if os(macOS)
                .frame(minWidth: 650, minHeight: 400)
                #endif
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task(priority: .utility) {
                        // Defer post-activation sync so first frame is not contending.
                        try? await Task.sleep(for: .seconds(1))
                        await RevenueCatManager.shared.refreshStatusIfNeeded(reason: .appBecameActive)
                    }
                }
        }
        
        #if os(macOS)
        // macOS Settings window (Cmd + ,)
        Settings {
            SettingsView()
                .environment(languageManager)
                .environment(\.locale, languageManager.currentLocale)
        }
        #endif
    }
    
    /// Handle PDF files opened from external apps (Files, Mail, Safari, etc.)
    private func handleIncomingURL(_ url: URL) {
        // Verify it's a PDF
        guard url.pathExtension.lowercased() == "pdf" else {
            return
        }
        
        // Add file to dashboard
        Task { @MainActor in
            await dashboardViewModel.addFiles(urls: [url])
        }
    }
    
    #if os(macOS)
    private func configureRevenueCatMacOS() {
        #if canImport(RevenueCat)
        let apiKey = StoreConfiguration.revenueCatAPIKey
        guard !apiKey.isEmpty else {
            return
        }
        
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = RevenueCatDelegateHandler.shared
        #endif
    }
    #endif
}
