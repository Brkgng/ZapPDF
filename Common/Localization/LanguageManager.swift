//
//  LanguageManager.swift
//  ZapPDF
//
//  Manages app-wide language state with persistence.
//

import Foundation
import SwiftUI

/// Observable manager for app language preferences.
///
/// This uses the `AppleLanguages` UserDefaults key which is the standard
/// iOS/macOS approach for in-app language switching. Changes require
/// an app restart to take effect.
@Observable
final class LanguageManager {
    
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        static let selectedLanguage = "app.selectedLanguage"
        static let appleLanguages = "AppleLanguages"
    }
    
    // MARK: - Published State
    
    /// The currently selected language.
    /// When set, persists to UserDefaults and requires app restart.
    var currentLanguage: AppLanguage {
        didSet {
            guard currentLanguage != oldValue else { return }
            persist()
            applyLanguageOverride()
            pendingRestart = true
        }
    }
    
    /// Whether a language change is pending (requires restart).
    var pendingRestart: Bool = false
    
    /// The effective locale to apply to the app.
    /// Returns `.current` when using system default.
    var currentLocale: Locale {
        currentLanguage.locale ?? .current
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load persisted language or default to system
        if let savedRawValue = UserDefaults.standard.string(forKey: StorageKey.selectedLanguage),
           let savedLanguage = AppLanguage(rawValue: savedRawValue) {
            self.currentLanguage = savedLanguage
        } else {
            self.currentLanguage = .system
        }
        
        // Apply on launch
        applyLanguageOverride()
    }
    
    // MARK: - Persistence
    
    private func persist() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: StorageKey.selectedLanguage)
        UserDefaults.standard.synchronize()
    }
    
    /// Apply language override via AppleLanguages.
    /// This is the standard iOS/macOS mechanism for language switching.
    private func applyLanguageOverride() {
        if currentLanguage == .system {
            // Remove override, use system language
            UserDefaults.standard.removeObject(forKey: StorageKey.appleLanguages)
        } else {
            // Set the preferred language
            let languageCode = currentLanguage.languageCode
            UserDefaults.standard.set([languageCode], forKey: StorageKey.appleLanguages)
        }
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Testing Support
    
    #if DEBUG
    /// Resets language to system default. For testing only.
    func reset() {
        currentLanguage = .system
        UserDefaults.standard.removeObject(forKey: StorageKey.selectedLanguage)
        UserDefaults.standard.removeObject(forKey: StorageKey.appleLanguages)
        UserDefaults.standard.synchronize()
    }
    #endif
}

