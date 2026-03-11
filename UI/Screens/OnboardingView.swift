//
//  OnboardingView.swift
//  ZapPDF
//
//  First-launch onboarding with privacy-first messaging.
//

import SwiftUI

/// A single onboarding page with icon, title, and description.
struct OnboardingPage: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 80))
                .foregroundColor(iconColor)
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer(minLength: 0)
        }
        .padding()
    }
}

// MARK: - Page Indicator

/// Custom page indicator dots for navigation.
struct PageIndicator: View {
    let pageCount: Int
    @Binding var currentPage: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        withAnimation {
                            currentPage = index
                        }
                    }
            }
        }
    }
}

// MARK: - Navigation Controls

/// Navigation controls for macOS onboarding.
struct OnboardingNavigationControls: View {
    let pageCount: Int
    @Binding var currentPage: Int
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Previous button
            Button {
                withAnimation {
                    currentPage = max(0, currentPage - 1)
                }
            } label: {
                Label(L10n.Onboarding.previous, systemImage: "chevron.left")
            }
            .disabled(currentPage == 0)
            .opacity(currentPage == 0 ? 0.3 : 1)
            
            Spacer()
            
            // Page indicator
            PageIndicator(pageCount: pageCount, currentPage: $currentPage)
            
            Spacer()
            
            // Next/Get Started button
            if currentPage < pageCount - 1 {
                Button {
                    withAnimation {
                        currentPage = min(pageCount - 1, currentPage + 1)
                    }
                } label: {
                    Label(L10n.Onboarding.next, systemImage: "chevron.right")
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button(L10n.Action.getStarted) {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

// MARK: - Final Page

/// Final onboarding page with Get Started button.
struct OnboardingFinalPage: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text(L10n.Onboarding.readyTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(L10n.Onboarding.readyDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer(minLength: 0)
            
            // Get Started Button (iOS only - macOS uses navigation controls)
            #if os(iOS)
            Button {
                onComplete()
            } label: {
                Text(L10n.Action.getStarted)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            #endif
            
            Spacer(minLength: 0)
        }
        .padding()
    }
}

// MARK: - OnboardingView

/// First-launch onboarding view with privacy-focused introduction.
///
/// Presents a multi-page introduction highlighting:
/// - Welcome message
/// - Privacy-first approach
/// - Key features
/// - Get started prompt
///
/// Example:
/// ```swift
/// @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
///
/// if !hasCompletedOnboarding {
///     OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
/// }
/// ```
struct OnboardingView: View {
    
    // MARK: - Properties
    
    /// Binding to track onboarding completion state.
    @Binding var hasCompletedOnboarding: Bool
    
    /// Current page index for TabView.
    @State private var currentPage = 0
    
    /// Total number of onboarding pages.
    static let pageCount = 4
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background - use platform-appropriate background
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            #endif
            
            #if os(macOS)
            // Keep macOS controls pinned so short windows compress the page body first.
            onboardingPage(for: currentPage)
                .id(currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: currentPage)
            #else
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    OnboardingPage(
                        iconName: "doc.text.fill",
                        iconColor: .accentColor,
                        title: L10n.Onboarding.welcomeTitle,
                        description: L10n.Onboarding.welcomeDescription
                    )
                    .tag(0)
                    
                    // Page 2: Privacy
                    OnboardingPage(
                        iconName: "lock.shield.fill",
                        iconColor: .green,
                        title: L10n.Onboarding.privacyTitle,
                        description: L10n.Onboarding.privacyDescription
                    )
                    .tag(1)
                    
                    // Page 3: Features
                    OnboardingPage(
                        iconName: "square.grid.2x2.fill",
                        iconColor: .orange,
                        title: L10n.Onboarding.featuresTitle,
                        description: L10n.Onboarding.featuresDescription
                    )
                    .tag(2)
                    
                    // Page 4: Get Started
                    OnboardingFinalPage {
                        completeOnboarding()
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            #endif
        }
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            OnboardingNavigationControls(
                pageCount: Self.pageCount,
                currentPage: $currentPage,
                onComplete: completeOnboarding
            )
        }
        #endif
    }
    
    // MARK: - Private Methods

    @ViewBuilder
    private func onboardingPage(for page: Int) -> some View {
        switch page {
        case 0:
            OnboardingPage(
                iconName: "doc.text.fill",
                iconColor: .accentColor,
                title: L10n.Onboarding.welcomeTitle,
                description: L10n.Onboarding.welcomeDescription
            )
        case 1:
            OnboardingPage(
                iconName: "lock.shield.fill",
                iconColor: .green,
                title: L10n.Onboarding.privacyTitle,
                description: L10n.Onboarding.privacyDescription
            )
        case 2:
            OnboardingPage(
                iconName: "square.grid.2x2.fill",
                iconColor: .orange,
                title: L10n.Onboarding.featuresTitle,
                description: L10n.Onboarding.featuresDescription
            )
        default:
            OnboardingFinalPage {
                completeOnboarding()
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    @Previewable @State var hasCompleted = false
    
    OnboardingView(hasCompletedOnboarding: $hasCompleted)
}

#Preview("Page 1 - Welcome") {
    OnboardingPage(
        iconName: "doc.text.fill",
        iconColor: .accentColor,
        title: "Welcome to ZapPDF",
        description: "Powerful PDF tools with zero compromises."
    )
}

#Preview("Final Page") {
    OnboardingFinalPage {}
}
