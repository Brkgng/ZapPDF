//
//  PaywallView.swift
//  ZapPDF
//
//  Subscription paywall screen using RevenueCat's built-in paywall.
//

import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

// MARK: - macOS Paywall Presentation Metrics

#if os(macOS)
enum PaywallPresentationMetrics {
    static let minWidth: CGFloat = 520
    static let minHeight: CGFloat = 620
}
#endif

// MARK: - PaywallView

/// Subscription paywall that uses RevenueCat's built-in PaywallView.
///
/// This view automatically fetches the paywall configured in the RevenueCat
/// dashboard and handles purchases/restores.
///
/// Example:
/// ```swift
/// .sheet(isPresented: $showPaywall) {
///     PaywallView()
/// }
/// ```
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        #if canImport(RevenueCatUI)
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                #if DEBUG
                print("✅ Purchase completed!")
                #endif
                handlePurchaseSuccess(customerInfo)
            }
            .onPurchaseFailure { error in
                #if DEBUG
                print("❌ Purchase failed: \(error.localizedDescription)")
                #endif
                errorMessage = L10n.Error.purchaseFailed
                showError = true
            }
            .onRestoreCompleted { customerInfo in
                #if DEBUG
                print("✅ Restore completed!")
                #endif
                handleRestoreSuccess(customerInfo)
            }
            .onRestoreFailure { error in
                #if DEBUG
                print("❌ Restore failed: \(error.localizedDescription)")
                #endif
                errorMessage = L10n.Error.restoreFailed
                showError = true
            }
            .alert(L10n.Error.title, isPresented: $showError) {
                Button(L10n.Action.ok, role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        #else
        Text("RevenueCat not available")
        #endif
    }
    
    // MARK: - Helpers
    
    #if canImport(RevenueCat)
    private func handlePurchaseSuccess(_ customerInfo: CustomerInfo) {
        Task {
            await RevenueCatManager.shared.refreshStatus()
        }
        dismiss()
    }
    
    private func handleRestoreSuccess(_ customerInfo: CustomerInfo) {
        if customerInfo.entitlements[StoreConfiguration.EntitlementID.pro]?.isActive == true {
            Task {
                await RevenueCatManager.shared.refreshStatus()
            }
            dismiss()
        }
    }
    #endif
}

// MARK: - Paywall Presentation Modifier

#if canImport(RevenueCatUI)
/// View modifier to automatically present paywall when Pro entitlement is missing.
///
/// Example:
/// ```swift
/// ContentView()
///     .presentPaywallIfNeededForPro()
/// ```
struct ProPaywallModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: StoreConfiguration.EntitlementID.pro,
                purchaseCompleted: { customerInfo in
                    #if DEBUG
                    print("✅ Purchase completed via modifier")
                    #endif
                    Task {
                        await RevenueCatManager.shared.refreshStatus()
                    }
                },
                restoreCompleted: { customerInfo in
                    #if DEBUG
                    print("✅ Restore completed via modifier")
                    #endif
                    Task {
                        await RevenueCatManager.shared.refreshStatus()
                    }
                }
            )
    }
}

extension View {
    /// Automatically present RevenueCat paywall if Pro entitlement is not active.
    func presentPaywallIfNeededForPro() -> some View {
        modifier(ProPaywallModifier())
    }
}
#endif

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
}
