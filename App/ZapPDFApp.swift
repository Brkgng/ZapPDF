//
//  ZapPDFApp.swift
//  ZapPDF
//
//  Created by Berker Güngör on 23.12.2025.
//

import SwiftUI

@main
struct ZapPDFApp: App {
    
    /// Shared language manager for app-wide locale control.
    @State private var languageManager = LanguageManager.shared
    
    init() {
        // UNCOMMENT the line below to reset onboarding state for debugging
        // UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(languageManager)
                .environment(\.locale, languageManager.currentLocale)
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
}

