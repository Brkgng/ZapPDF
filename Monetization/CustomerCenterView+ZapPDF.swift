//
//  CustomerCenterView+ZapPDF.swift
//  ZapPDF
//
//  SwiftUI integration for RevenueCat's Customer Center.
//  Note: CustomerCenterView is only available on iOS, not macOS.
//

import SwiftUI

// CustomerCenterView is only available on iOS
#if os(iOS)

#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

// MARK: - Customer Center Wrapper

#if canImport(RevenueCatUI)
/// A SwiftUI view that displays RevenueCat's Customer Center.
///
/// Customer Center provides a self-service UI for customers to:
/// - View and manage their subscription
/// - Cancel subscriptions
/// - Request refunds (iOS only)
/// - Restore purchases
/// - Contact support
///
/// Example:
/// ```swift
/// .sheet(isPresented: $showCustomerCenter) {
///     ZapPDFCustomerCenterView()
/// }
/// ```
struct ZapPDFCustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        CustomerCenterView()
            .onCustomerCenterRestoreCompleted { customerInfo in
                #if DEBUG
                print("✅ Restore completed from Customer Center")
                #endif
                Task {
                    await RevenueCatManager.shared.refreshStatus()
                }
            }
            .onCustomerCenterRestoreFailed { error in
                #if DEBUG
                print("❌ Restore failed: \(error.localizedDescription)")
                #endif
            }
    }
}

// MARK: - Customer Center Button

/// A button that opens the Customer Center.
///
/// Add this to your Settings screen to give users access to subscription management.
///
/// Example:
/// ```swift
/// CustomerCenterButton()
/// ```
struct CustomerCenterButton: View {
    @State private var showCustomerCenter = false
    
    var body: some View {
        Button {
            showCustomerCenter = true
        } label: {
            Label(L10n.Settings.manageSubscription, systemImage: "creditcard")
        }
        .sheet(isPresented: $showCustomerCenter) {
            ZapPDFCustomerCenterView()
        }
    }
}

// MARK: - Customer Center Modifier

/// View modifier to present Customer Center.
///
/// Example:
/// ```swift
/// ContentView()
///     .presentCustomerCenter(isPresented: $showCustomerCenter)
/// ```
struct CustomerCenterModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ZapPDFCustomerCenterView()
            }
    }
}

extension View {
    /// Present RevenueCat's Customer Center.
    func presentZapPDFCustomerCenter(isPresented: Binding<Bool>) -> some View {
        modifier(CustomerCenterModifier(isPresented: isPresented))
    }
}

// MARK: - Preview

#Preview("Customer Center") {
    ZapPDFCustomerCenterView()
}
#endif // canImport(RevenueCatUI)

#endif // os(iOS)

