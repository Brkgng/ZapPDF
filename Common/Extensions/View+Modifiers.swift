//
//  View+Modifiers.swift
//  ZapPDF
//
//  Shared view modifiers for consistent styling across macOS and iOS.
//

import SwiftUI

// MARK: - Card Style Modifier

/// A view modifier that applies card styling with background, corner radius, and shadow.
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
    }
    
    private var cardBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.1)
    }
}

// MARK: - Primary Button Style

/// A button style for primary actions with filled background.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? Color.accentColor : Color.gray)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// A button style for secondary actions with outlined border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// A button style for destructive actions with red color.
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(isEnabled ? .red : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.red : Color.gray, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Loading Overlay Modifier

/// A view modifier that displays a loading overlay with optional message.
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    if let message = message {
                        Text(message)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Drop Target Highlight Modifier

/// A view modifier that highlights a view when it's a drop target.
struct DropTargetHighlight: ViewModifier {
    let isTargeted: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isTargeted ? Color.accentColor : Color.clear,
                        style: StrokeStyle(lineWidth: 3, dash: [8, 4])
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}

// MARK: - Shake Effect Modifier

/// A view modifier that applies a shake animation for error feedback.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

// MARK: - View Extension for Modifiers

extension View {
    /// Apply card styling with background, corner radius, and shadow.
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    /// Apply loading overlay with optional message.
    /// - Parameters:
    ///   - isLoading: Whether to show the loading overlay
    ///   - message: Optional message to display below the spinner
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
    
    /// Apply drop target highlight for drag & drop.
    /// - Parameter isTargeted: Whether the view is currently a drop target
    func dropTargetHighlight(isTargeted: Bool) -> some View {
        modifier(DropTargetHighlight(isTargeted: isTargeted))
    }
    
    /// Apply a shake effect animation.
    /// - Parameter shakes: Animation trigger value
    func shake(shakes: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(shakes)))
    }
    
    /// Conditionally apply a modifier.
    /// - Parameters:
    ///   - condition: Whether to apply the transform
    ///   - transform: The transform to apply if condition is true
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Conditionally apply one of two modifiers.
    /// - Parameters:
    ///   - condition: Whether to apply the first or second transform
    ///   - ifTrue: Transform to apply if condition is true
    ///   - ifFalse: Transform to apply if condition is false
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        ifTrue: (Self) -> TrueContent,
        ifFalse: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Primary button style with filled background.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Secondary button style with outlined border.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    /// Destructive button style with red color.
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}
