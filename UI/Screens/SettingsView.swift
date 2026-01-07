//
//  SettingsView.swift
//  ZapPDF
//
//  App settings screen with language selection.
//

import SwiftUI

/// Settings view with language picker and app information.
struct SettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iOSContent
        #endif
    }
    
    // MARK: - macOS Layout
    
    #if os(macOS)
    private var macOSContent: some View {
        Form {
            languageSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 250)
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSContent: some View {
        NavigationStack {
            Form {
                languageSection
                aboutSection
            }
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Action.done) {
                        dismiss()
                    }
                }
            }
        }
    }
    #endif
    
    // MARK: - Sections
    
    @ViewBuilder
    private var languageSection: some View {
        Section {
            @Bindable var manager = languageManager
            
            Picker(selection: $manager.currentLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    HStack(spacing: 12) {
                        Text(language.flag)
                        Text(language.nativeName)
                        if language != .system {
                            Spacer()
                            Text(language.localizedName)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .tag(language)
                }
            } label: {
                Label(L10n.Settings.language, systemImage: "globe")
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif
        } header: {
            Text(L10n.Settings.language)
        } footer: {
            Text(L10n.Settings.languageDescription)
        }
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack {
                Label(L10n.Settings.version, systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.Settings.about)
        }
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(LanguageManager.shared)
}
