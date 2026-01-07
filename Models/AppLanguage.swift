//
//  AppLanguage.swift
//  ZapPDF
//
//  Defines supported languages for in-app language switching.
//

import Foundation

/// Supported languages for ZapPDF.
/// The `system` case follows device language settings.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case en
    case de
    case fr
    case es
    case ja
    case zhHans
    case tr
    
    var id: String { rawValue }
    
    /// The locale for this language, or `nil` for system default.
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .en: return Locale(identifier: "en")
        case .de: return Locale(identifier: "de")
        case .fr: return Locale(identifier: "fr")
        case .es: return Locale(identifier: "es")
        case .ja: return Locale(identifier: "ja")
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .tr: return Locale(identifier: "tr")
        }
    }
    
    /// Language code for AppleLanguages override.
    var languageCode: String {
        switch self {
        case .system: return "en" // Fallback, shouldn't be used
        case .en: return "en"
        case .de: return "de"
        case .fr: return "fr"
        case .es: return "es"
        case .ja: return "ja"
        case .zhHans: return "zh-Hans"
        case .tr: return "tr"
        }
    }
    
    /// Native name of the language (displayed in picker).
    /// Shows the language name in its own script for easy recognition.
    var nativeName: String {
        switch self {
        case .system: return L10n.Settings.systemDefault
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .tr: return "Türkçe"
        }
    }
    
    /// Localized name of the language (e.g., "German" in English UI).
    var localizedName: String {
        switch self {
        case .system: return L10n.Settings.systemDefault
        case .en: return L10n.Language.english
        case .de: return L10n.Language.german
        case .fr: return L10n.Language.french
        case .es: return L10n.Language.spanish
        case .ja: return L10n.Language.japanese
        case .zhHans: return L10n.Language.chineseSimplified
        case .tr: return L10n.Language.turkish
        }
    }
    
    /// Flag emoji for visual indicator.
    var flag: String {
        switch self {
        case .system: return "🌐"
        case .en: return "🇺🇸"
        case .de: return "🇩🇪"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        case .ja: return "🇯🇵"
        case .zhHans: return "🇨🇳"
        case .tr: return "🇹🇷"
        }
    }
}
