//
//  PaywallView.swift
//  ZapPDF
//
//  Subscription upsell screen with feature comparison.
//

import SwiftUI

// MARK: - Feature Row

/// A row comparing a feature between free and pro tiers.
private struct FeatureComparisonRow: View {
    let feature: String
    let isFreeIncluded: Bool
    let isProIncluded: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.body)
            
            Spacer()
            
            // Free column
            Image(systemName: isFreeIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isFreeIncluded ? .green : .red.opacity(0.6))
                .frame(width: 60)
            
            // Pro column
            Image(systemName: isProIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isProIncluded ? .green : .red.opacity(0.6))
                .frame(width: 60)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - PaywallView

/// Subscription paywall screen with feature comparison and purchase options.
///
/// Presents:
/// - Feature comparison between free and pro tiers
/// - Remaining free actions counter
/// - Purchase and restore buttons
/// - Privacy messaging
///
/// Example:
/// ```swift
/// .sheet(isPresented: $showPaywall) {
///     PaywallView()
/// }
/// ```
struct PaywallView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Feature comparison
                    featureComparisonSection
                    
                    // Remaining actions
                    remainingActionsSection
                    
                    // Purchase buttons
                    purchaseSection
                    
                    // Privacy note
                    privacySection
                }
                .padding()
            }
            .navigationTitle(L10n.Paywall.upgradeTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadState()
            }
            .alert(L10n.Paywall.purchaseSuccess, isPresented: isPurchaseSuccessBinding) {
                Button(L10n.Action.ok) {
                    dismiss()
                }
            } message: {
                Text(L10n.Paywall.purchaseSuccessMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pro badge icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            Text(L10n.Paywall.upgradeTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(L10n.Paywall.upgradeSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    // MARK: - Feature Comparison Section
    
    private var featureComparisonSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text(L10n.Paywall.features)
                    .font(.headline)
                
                Spacer()
                
                Text(L10n.Paywall.free)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                Text(L10n.Paywall.pro)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .frame(width: 60)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Feature rows
            FeatureComparisonRow(feature: L10n.Operation.Merge.title, isFreeIncluded: true, isProIncluded: true)
            FeatureComparisonRow(feature: L10n.Operation.Split.title, isFreeIncluded: true, isProIncluded: true)
            FeatureComparisonRow(feature: L10n.Operation.Convert.title, isFreeIncluded: false, isProIncluded: true)
            
            Divider()
            
            // Actions row
            HStack {
                Text(L10n.Paywall.pdfActions)
                    .font(.body)
                
                Spacer()
                
                Text("5")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                Text("∞")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .frame(width: 60)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(uiColor: .secondarySystemBackground))
                #endif
        )
    }
    
    // MARK: - Remaining Actions Section
    
    private var remainingActionsSection: some View {
        HStack {
            Image(systemName: viewModel.hasFreeActionsRemaining ? "sparkles" : "exclamationmark.triangle.fill")
                .foregroundColor(viewModel.hasFreeActionsRemaining ? .orange : .red)
            
            Text(viewModel.remainingActionsText)
                .font(.subheadline)
                .foregroundColor(viewModel.hasFreeActionsRemaining ? .primary : .red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.hasFreeActionsRemaining ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Purchase Section
    
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Purchase button
            Button {
                Task {
                    await viewModel.purchase(productID: "pro_monthly")
                }
            } label: {
                HStack {
                    if viewModel.purchaseState == .purchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    
                    Text(viewModel.purchaseState == .purchasing ? L10n.Common.processing : L10n.Paywall.upgradeTitle)
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.purchaseState == .purchasing || viewModel.purchaseState == .restoring)
            
            // Restore purchases button
            Button {
                Task {
                    await viewModel.restorePurchases()
                }
            } label: {
                Text(viewModel.purchaseState == .restoring ? L10n.Paywall.restoring : L10n.Paywall.restorePurchases)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .disabled(viewModel.purchaseState == .purchasing || viewModel.purchaseState == .restoring)
            
            // Price note (placeholder for Phase 7)
            Text(L10n.Common.pricingPlaceholder)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.green)
            
            Text(L10n.Paywall.privacyNote)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    // MARK: - Helpers
    
    private var isPurchaseSuccessBinding: Binding<Bool> {
        Binding(
            get: { viewModel.purchaseState == .success },
            set: { if !$0 { viewModel.resetPurchaseState() } }
        )
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
}

#Preview("Paywall - No Actions") {
    PaywallView()
}
