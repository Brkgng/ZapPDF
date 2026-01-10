//
//  SettingsView.swift
//  ZapPDF
//
//  App settings screen with language selection and subscription management.
//

import SwiftUI

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// Settings view with language picker, subscription management, and app information.
struct SettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomerCenter = false
    
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
            subscriptionSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .sheet(isPresented: $showCustomerCenter) {
            customerCenterSheet
        }
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSContent: some View {
        NavigationStack {
            Form {
                languageSection
                subscriptionSection
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
        .sheet(isPresented: $showCustomerCenter) {
            customerCenterSheet
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
    private var subscriptionSection: some View {
        Section {
            Button {
                showCustomerCenter = true
            } label: {
                Label(L10n.Settings.manageSubscription, systemImage: "creditcard")
            }
        } header: {
            Text(L10n.Settings.subscription)
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
    
    // MARK: - Customer Center Sheet
    
    @ViewBuilder
    private var customerCenterSheet: some View {
        // CustomerCenterView is only available on iOS
        #if os(iOS) && canImport(RevenueCatUI)
        ZapPDFCustomerCenterView()
        #else
        // Fallback for macOS or when RevenueCatUI is unavailable
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L10n.Settings.manageSubscription)
                .font(.headline)
            
            subscriptionManagementMessage
            
            Button(L10n.Action.done) {
                showCustomerCenter = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        #if os(macOS)
        .frame(width: 350, height: 200)
        #endif
        #endif
    }
    
    @ViewBuilder
    private var subscriptionManagementMessage: some View {
        #if os(macOS)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            Link(L10n.Settings.manageSubscription, destination: url)
                .font(.headline)
                .controlSize(.large)
                .padding(.top, 4)
        } else {
            Text("To manage your subscription, please use the App Store app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        #else
        Text("Subscription management is not available.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        #endif
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
