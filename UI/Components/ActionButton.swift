//
//  ActionButton.swift
//  ZapPDF
//
//  Styled button component for PDF actions (merge, split, convert).
//

import SwiftUI

/// Style variants for action buttons.
enum ActionButtonStyle {
    /// Filled background with accent color.
    case primary
    /// Outlined border with accent color.
    case secondary
    /// Compact icon-only style with small label.
    case compact
}

/// A styled button for PDF actions with icon and label.
///
/// `ActionButton` uses the `UserAction` enum to display appropriate
/// icons, colors, and labels. It supports multiple style variants
/// and proper disabled state handling.
///
/// Example:
/// ```swift
/// ActionButton(action: .merge, isEnabled: canMerge) {
///     // Handle merge action
/// }
///
/// ActionButton(action: .split, isEnabled: true, style: .compact) {
///     // Handle split action
/// }
/// ```
struct ActionButton: View {
    
    // MARK: - Properties
    
    /// The action this button represents.
    let action: UserAction
    
    /// Whether the button is enabled.
    let isEnabled: Bool
    
    /// The visual style of the button.
    var style: ActionButtonStyle = .primary
    
    /// Whether to show the action label.
    var showLabel: Bool = true
    
    /// The action to perform when tapped.
    var onTap: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        styledButton()
    }
    
    // MARK: - Button Content
    
    @ViewBuilder
    var buttonContent: some View {
        switch style {
        case .primary, .secondary:
            HStack(spacing: 8) {
                Image(systemName: action.iconName)
                    .font(.body.weight(.medium))
                if showLabel {
                    Text(action.displayName)
                        .font(.headline)
                }
            }
            
        case .compact:
            VStack(spacing: 4) {
                Image(systemName: action.iconName)
                    .font(.title2)
                if showLabel {
                    Text(action.displayName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 60)
        }
    }
    
    // MARK: - Private Methods
    
    func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Custom Button Styles for ActionButton

/// Primary filled button style using action's accent color.
struct ActionPrimaryButtonStyle: ButtonStyle {
    let accentColor: Color
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? accentColor : Color.gray)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary outlined button style using action's accent color.
struct ActionSecondaryButtonStyle: ButtonStyle {
    let accentColor: Color
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? accentColor : .gray)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEnabled ? accentColor : Color.gray, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Compact button style for icon-focused display.
struct ActionCompactButtonStyle: ButtonStyle {
    let accentColor: Color
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? accentColor : .gray)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - ActionButton with Proper Style Application

extension ActionButton {
    /// Creates an ActionButton with the specified style applied.
    @ViewBuilder
    func styledButton() -> some View {
        switch style {
        case .primary:
            Button {
                triggerHaptic()
                onTap()
            } label: {
                buttonContent
            }
            .disabled(!isEnabled)
            .buttonStyle(ActionPrimaryButtonStyle(accentColor: action.accentColor))
            
        case .secondary:
            Button {
                triggerHaptic()
                onTap()
            } label: {
                buttonContent
            }
            .disabled(!isEnabled)
            .buttonStyle(ActionSecondaryButtonStyle(accentColor: action.accentColor))
            
        case .compact:
            Button {
                triggerHaptic()
                onTap()
            } label: {
                buttonContent
            }
            .disabled(!isEnabled)
            .buttonStyle(ActionCompactButtonStyle(accentColor: action.accentColor))
        }
    }
}

// MARK: - Pro Badge Modifier

extension ActionButton {
    /// Adds a "Pro" badge to the button if the action requires Pro subscription.
    @ViewBuilder
    func withProBadge() -> some View {
        if !action.isFreeTierAction {
            ZStack(alignment: .topTrailing) {
                styledButton()
                
                Text(L10n.Common.proBadge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                    )
                    .offset(x: 4, y: -4)
            }
        } else {
            styledButton()
        }
    }
}

// MARK: - Convenient Initializer View

/// A convenient wrapper that applies the proper button style.
struct StyledActionButton: View {
    let action: UserAction
    let isEnabled: Bool
    var style: ActionButtonStyle = .primary
    var showLabel: Bool = true
    var showProBadge: Bool = true
    var onTap: () -> Void
    
    var body: some View {
        let button = ActionButton(
            action: action,
            isEnabled: isEnabled,
            style: style,
            showLabel: showLabel,
            onTap: onTap
        )
        
        if showProBadge {
            button.withProBadge()
        } else {
            button.styledButton()
        }
    }
}

// MARK: - Preview

#Preview("Primary Style") {
    VStack(spacing: 20) {
        ForEach(UserAction.allCases) { action in
            StyledActionButton(action: action, isEnabled: true) {
                print("\(action.displayName) tapped")
            }
        }
    }
    .padding()
}

#Preview("Secondary Style") {
    VStack(spacing: 20) {
        ForEach(UserAction.allCases) { action in
            StyledActionButton(action: action, isEnabled: true, style: .secondary) {
                print("\(action.displayName) tapped")
            }
        }
    }
    .padding()
}

#Preview("Compact Style") {
    HStack(spacing: 16) {
        ForEach(UserAction.allCases) { action in
            StyledActionButton(action: action, isEnabled: true, style: .compact) {
                print("\(action.displayName) tapped")
            }
        }
    }
    .padding()
}

#Preview("Disabled States") {
    VStack(spacing: 20) {
        StyledActionButton(action: .merge, isEnabled: false) {}
        StyledActionButton(action: .split, isEnabled: false, style: .secondary) {}
        StyledActionButton(action: .convert, isEnabled: false, style: .compact) {}
    }
    .padding()
}
