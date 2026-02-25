//
//  ClearAllButton.swift
//  ZapPDF
//
//  A styled destructive button for clearing all files.
//

import SwiftUI

// MARK: - ClearAllButton

/// A styled button for the "Clear All" action with icon, hover effects, and haptic feedback.
///
/// This button follows Apple HIG for destructive actions with:
/// - Trash icon for clear visual intent
/// - Bordered style with red accent
/// - Hover effects on macOS
/// - Haptic feedback on iOS
/// - Press scale animation
///
/// Example:
/// ```swift
/// ClearAllButton {
///     showConfirmation = true
/// }
/// ```
struct ClearAllButton: View {
    
    // MARK: - Properties
    
    /// Action to perform when tapped.
    let onTap: () -> Void
    
    /// Whether the button is disabled.
    var isDisabled: Bool = false
    
    // MARK: - Private State
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        Button {
            triggerHaptic()
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                
                Text(L10n.Dashboard.clearAll)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(buttonForegroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(buttonBackgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(buttonBorderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        #if os(macOS)
        .help(L10n.Help.clearAll)
        #endif
    }
    
    // MARK: - Computed Properties
    
    private var buttonForegroundColor: Color {
        if isDisabled {
            return .gray
        }
        return isHovered ? .primary : .secondary
    }
    
    private var buttonBackgroundColor: Color {
        if isDisabled {
            return .gray.opacity(0.1)
        }
        return isHovered ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.08)
    }
    
    private var buttonBorderColor: Color {
        if isDisabled {
            return .gray.opacity(0.3)
        }
        return Color.secondary.opacity(0.3)
    }
    
    // MARK: - Private Methods
    
    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Preview

#Preview("Default State") {
    ClearAllButton {}
    .padding()
}

#Preview("Disabled State") {
    ClearAllButton(onTap: {}, isDisabled: true)
        .padding()
}

#Preview("In Context") {
    VStack(spacing: 20) {
        // Simulating bottom bar context
        HStack {
            Text("3 of 5 selected")
                .font(.subheadline)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Text("125 pages")
                .font(.subheadline)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Text("15.2 MB")
                .font(.subheadline)
            
            Spacer()
            
            ClearAllButton {}
        }
        .foregroundColor(.secondary)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    .padding()
}
