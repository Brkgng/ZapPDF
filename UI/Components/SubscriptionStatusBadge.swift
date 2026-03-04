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
    
    /// Rendering style for contexts with different space constraints.
    enum PresentationStyle {
        case full
        case compactToolbar
    }
    
    /// Whether the user has Pro subscription.
    let isPro: Bool
    
    /// Number of remaining free actions.
    let remainingActions: Int
    
    /// Total free action limit.
    let freeActionLimit: Int
    
    /// Rendering style (defaults to full text).
    let presentationStyle: PresentationStyle
    
    /// Action when free user taps to upgrade.
    let onUpgradeTapped: () -> Void
    
    init(
        isPro: Bool,
        remainingActions: Int,
        freeActionLimit: Int,
        presentationStyle: PresentationStyle = .full,
        onUpgradeTapped: @escaping () -> Void
    ) {
        self.isPro = isPro
        self.remainingActions = remainingActions
        self.freeActionLimit = freeActionLimit
        self.presentationStyle = presentationStyle
        self.onUpgradeTapped = onUpgradeTapped
    }
    
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
            if presentationStyle == .compactToolbar {
                compactFreeBadgeLabel
            } else {
                fullFreeBadgeLabel
            }
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .help(L10n.Accessibility.upgradeHint)
        #endif
    }

    private var compactFreeBadgeLabel: some View {
        Text("\(Image(systemName: statusIcon)) \(statusText)")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private var fullFreeBadgeLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption)
            
            Text(statusText)
                .font(.caption)
            
            if clampedRemainingActions == 0 {
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
    
    // MARK: - Status Helpers

    private var clampedRemainingActions: Int {
        max(remainingActions, 0)
    }

    private var statusIcon: String {
        switch clampedRemainingActions {
        case 0:
            return "xmark.circle.fill"
        case 1...2:
            return "exclamationmark.triangle.fill"
        default:
            return "bolt.fill"
        }
    }
    
    private var statusText: String {
        if presentationStyle == .compactToolbar {
            return L10n.Paywall.actionsLeft(clampedRemainingActions)
        }
        
        switch clampedRemainingActions {
        case 0:
            return L10n.Paywall.noActionsLeft()
        case 1:
            return L10n.Paywall.actionsLeft(1)
        case 2:
            return L10n.Paywall.actionsLeft(2)
        default:
            return L10n.Paywall.actionsRemaining(clampedRemainingActions, of: freeActionLimit)
        }
    }
    
    private var statusColor: Color {
        switch clampedRemainingActions {
        case 0:
            return .red
        case 1...2:
            return .orange
        default:
            return presentationStyle == .compactToolbar ? .primary : .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        switch clampedRemainingActions {
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

#Preview("Free User - Compact") {
    SubscriptionStatusBadge(
        isPro: false,
        remainingActions: 5,
        freeActionLimit: 5,
        presentationStyle: .compactToolbar,
        onUpgradeTapped: {}
    )
    .padding()
}
