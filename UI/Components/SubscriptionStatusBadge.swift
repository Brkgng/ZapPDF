//
//  SubscriptionStatusBadge.swift
//  ZapPDF
//
//  Displays subscription status in the toolbar.
//

import SwiftUI

// MARK: - SubscriptionStatusBadge

/// Badge displaying subscription status (Pro or Free with remaining actions).
///
/// Pro users see a crown badge, free users see remaining actions
/// with a tap-to-upgrade option.
///
/// Example:
/// ```swift
/// SubscriptionStatusBadge(
///     isPro: viewModel.isPro,
///     remainingActions: viewModel.remainingFreeActions,
///     freeActionLimit: 5,
///     onUpgradeTapped: { viewModel.showPaywall = true }
/// )
/// ```
struct SubscriptionStatusBadge: View {
    
    // MARK: - Properties
    
    /// Whether the user has Pro subscription.
    let isPro: Bool
    
    /// Number of remaining free actions.
    let remainingActions: Int
    
    /// Total free action limit.
    let freeActionLimit: Int
    
    /// Action when free user taps to upgrade.
    let onUpgradeTapped: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        if isPro {
            proBadge
        } else {
            freeBadge
        }
    }
    
    // MARK: - Pro Badge
    
    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption)
            
            Text(L10n.Paywall.pro)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
    
    // MARK: - Free Badge
    
    private var freeBadge: some View {
        Button {
            onUpgradeTapped()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.caption)
                
                Text(statusText)
                    .font(.caption)
                
                if remainingActions == 0 {
                    Text(L10n.Action.upgrade)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                        )
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusBackgroundColor)
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .help(L10n.Accessibility.upgradeHint)
        #endif
    }
    
    // MARK: - Status Helpers
    
    private var statusIcon: String {
        switch remainingActions {
        case 0:
            return "xmark.circle.fill"
        case 1...2:
            return "exclamationmark.triangle.fill"
        default:
            return "bolt.fill"
        }
    }
    
    private var statusText: String {
        switch remainingActions {
        case 0:
            return L10n.Paywall.noActionsLeft()
        case 1:
            return L10n.Paywall.actionsLeft(1)
        case 2:
            return L10n.Paywall.actionsLeft(2)
        default:
            return L10n.Paywall.actionsRemaining(remainingActions, of: freeActionLimit)
        }
    }
    
    private var statusColor: Color {
        switch remainingActions {
        case 0:
            return .red
        case 1...2:
            return .orange
        default:
            return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        switch remainingActions {
        case 0:
            return .red.opacity(0.15)
        case 1...2:
            return .orange.opacity(0.15)
        default:
            #if os(macOS)
            return Color(nsColor: .controlBackgroundColor)
            #else
            return Color(uiColor: .secondarySystemBackground)
            #endif
        }
    }
}

// MARK: - Preview

#Preview("Pro User") {
    SubscriptionStatusBadge(
        isPro: true,
        remainingActions: 0,
        freeActionLimit: 5,
        onUpgradeTapped: {}
    )
    .padding()
}

#Preview("Free User - Full") {
    SubscriptionStatusBadge(
        isPro: false,
        remainingActions: 5,
        freeActionLimit: 5,
        onUpgradeTapped: {}
    )
    .padding()
}

#Preview("Free User - Low") {
    SubscriptionStatusBadge(
        isPro: false,
        remainingActions: 2,
        freeActionLimit: 5,
        onUpgradeTapped: {}
    )
    .padding()
}

#Preview("Free User - Empty") {
    SubscriptionStatusBadge(
        isPro: false,
        remainingActions: 0,
        freeActionLimit: 5,
        onUpgradeTapped: {}
    )
    .padding()
}
