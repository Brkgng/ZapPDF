//
//  SettingsView.swift
//  ZapPDF
//
//  App settings screen with language selection and subscription management.
//

import SwiftUI

/// Settings view with language picker, subscription management, and app information.
struct SettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var restoreSuccess = false
    @State private var showRestartAlert = false
    @State private var showPaywall = false
    
    // App Store subscription management URL
    private let subscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")
    
    // Support form URL
    private let supportURL = URL(string: "https://forms.gle/542Dty1NrMJcKCe98")
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSContent
            #else
            iOSContent
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                #if os(macOS)
                .frame(
                    minWidth: PaywallPresentationMetrics.minWidth,
                    minHeight: PaywallPresentationMetrics.minHeight
                )
                #endif
        }
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
        .frame(width: 400, height: 430)
        .alert(restoreSuccess ? L10n.Processing.completed : L10n.Error.title, isPresented: $showRestoreAlert) {
            Button(L10n.Action.ok, role: .cancel) { }
        } message: {
            Text(restoreMessage)
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
        .alert(restoreSuccess ? L10n.Processing.completed : L10n.Error.title, isPresented: $showRestoreAlert) {
            Button(L10n.Action.ok, role: .cancel) { }
        } message: {
            Text(restoreMessage)
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
        .onChange(of: languageManager.currentLanguage) { _, _ in
            showRestartAlert = true
        }
        .alert(L10n.Settings.restartRequired, isPresented: $showRestartAlert) {
            Button(L10n.Action.ok, role: .cancel) { }
        } message: {
            Text(L10n.Settings.languageRestartMessage)
        }
    }
    
    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            // Subscription status
            SubscriptionStatusRow {
                showPaywall = true
            }

            if MonetizationAvailability.isEnabled {
                // Manage Subscription - opens App Store
                if let url = subscriptionURL {
                    Link(destination: url) {
                        subscriptionActionRow(
                            title: L10n.Settings.manageSubscription,
                            systemImage: "arrow.up.forward.app"
                        )
                    }
                }

                // Restore Purchases
                Button {
                    restorePurchases()
                } label: {
                    subscriptionActionRow(
                        title: L10n.Settings.restorePurchases,
                        systemImage: "arrow.clockwise",
                        showsProgress: isRestoring
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isRestoring)
            } else {
                HStack {
                    Label(MonetizationAvailability.unavailableMessage, systemImage: "exclamationmark.triangle")
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
            
            // Contact Support
            Button {
                contactSupport()
            } label: {
                subscriptionActionRow(
                    title: L10n.Settings.contactSupport,
                    systemImage: "envelope"
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        } header: {
            Text(L10n.Settings.subscription)
        }
    }

    @ViewBuilder
    private func subscriptionActionRow(
        title: String,
        systemImage: String,
        showsProgress: Bool = false
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
    
    // MARK: - Actions
    
    private func restorePurchases() {
        isRestoring = true
        
        Task {
            do {
                let restored = try await RevenueCatManager.shared.restorePurchases()
                await MainActor.run {
                    isRestoring = false
                    restoreSuccess = restored
                    restoreMessage = restored 
                        ? L10n.Settings.restoreSuccess 
                        : L10n.Settings.restoreNoProducts
                    showRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    restoreSuccess = false
                    restoreMessage = error.localizedDescription
                    showRestoreAlert = true
                }
            }
        }
    }
    
    private func contactSupport() {
        if let url = supportURL {
            openURL(url)
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

// MARK: - Subscription Status Row

/// Displays current subscription status with type, expiration, and renewal info.
private struct SubscriptionStatusRow: View {
    @State private var proStatus: ProStatus?
    @State private var offlinePro: Bool = false
    let onUpgradeTapped: () -> Void
    
    var body: some View {
        HStack {
            Label(displayState.statusText, systemImage: displayState.statusIcon)
            Spacer()
            if displayState.showsUpgradeCTA {
                Button(L10n.Action.upgrade) {
                    onUpgradeTapped()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if let subtitle = displayState.statusSubtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .task {
            // Initial fetch
            await refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .usageStateDidChange)) { _ in
            Task {
                await refreshStatus()
            }
        }
    }
    
    private func refreshStatus() async {
        await RevenueCatManager.shared.refreshStatusIfNeeded(reason: .settingsOpened)
        proStatus = await RevenueCatManager.shared.proStatus
        offlinePro = await UsageManager.shared.getProStatus()
    }

    private var displayState: SubscriptionStatusDisplayState {
        SubscriptionStatusDisplayState.make(
            proStatus: proStatus,
            offlinePro: offlinePro,
            monetizationEnabled: MonetizationAvailability.isEnabled
        )
    }
}

struct SubscriptionStatusDisplayState: Equatable {
    let statusText: String
    let statusIcon: String
    let statusSubtitle: String?
    let showsUpgradeCTA: Bool

    static func make(
        proStatus: ProStatus?,
        offlinePro: Bool,
        monetizationEnabled: Bool,
        dateFormatter: DateFormatter = SubscriptionStatusDisplayState.defaultDateFormatter()
    ) -> SubscriptionStatusDisplayState {
        if let status = proStatus, status.isActive {
            let statusText: String
            switch status.type {
            case .lifetime:
                statusText = L10n.Settings.proLifetime
            case .annual:
                statusText = L10n.Settings.proAnnual
            case .monthly:
                statusText = L10n.Settings.proMonthly
            case .none:
                // Handle "Pro with unknown product type" from partial/offline sync.
                statusText = L10n.Settings.proPlan
            }

            var subtitle: String?
            if !status.isLifetime, let expirationDate = status.expirationDate {
                let dateString = dateFormatter.string(from: expirationDate)
                subtitle = status.willRenew == true
                    ? L10n.Settings.renewsOn(dateString)
                    : L10n.Settings.expiresOn(dateString)
            }

            return SubscriptionStatusDisplayState(
                statusText: statusText,
                statusIcon: "star.fill",
                statusSubtitle: subtitle,
                showsUpgradeCTA: false
            )
        }

        if offlinePro {
            return SubscriptionStatusDisplayState(
                statusText: L10n.Settings.proPlan,
                statusIcon: "star.fill",
                statusSubtitle: nil,
                showsUpgradeCTA: false
            )
        }

        return SubscriptionStatusDisplayState(
            statusText: L10n.Settings.freePlan,
            statusIcon: "person.fill",
            statusSubtitle: nil,
            showsUpgradeCTA: monetizationEnabled
        )
    }

    private static func defaultDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(LanguageManager.shared)
}
