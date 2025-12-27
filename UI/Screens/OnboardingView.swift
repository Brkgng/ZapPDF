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
            Spacer()
            
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
            
            Spacer()
            Spacer()
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
                Label("Previous", systemImage: "chevron.left")
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
                    Label("Next", systemImage: "chevron.right")
                }
            } else {
                Button("Get Started") {
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
            Spacer()
            
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text("Ready to Start")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("You have 5 free actions to try all features.\nUpgrade anytime for unlimited access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Get Started Button (iOS only - macOS uses navigation controls)
            #if os(iOS)
            Button {
                onComplete()
            } label: {
                Text("Get Started")
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
            
            Spacer()
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
            
            VStack(spacing: 0) {
                // Skip button (except on last page)
                HStack {
                    Spacer()
                    
                    if currentPage < Self.pageCount - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    OnboardingPage(
                        iconName: "doc.text.fill",
                        iconColor: .accentColor,
                        title: "Welcome to ZapPDF",
                        description: "Powerful PDF tools with zero compromises.\nMerge, split, compress, and convert with ease."
                    )
                    .tag(0)
                    
                    // Page 2: Privacy
                    OnboardingPage(
                        iconName: "lock.shield.fill",
                        iconColor: .green,
                        title: "Your Privacy Matters",
                        description: "All processing happens locally on your device.\nYour files never leave your device."
                    )
                    .tag(1)
                    
                    // Page 3: Features
                    OnboardingPage(
                        iconName: "square.grid.2x2.fill",
                        iconColor: .orange,
                        title: "Everything You Need",
                        description: "Merge multiple PDFs into one.\nSplit PDFs by page range.\nCompress to reduce file size.\nConvert to other formats."
                    )
                    .tag(2)
                    
                    // Page 4: Get Started
                    OnboardingFinalPage {
                        completeOnboarding()
                    }
                    .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                #endif
                
                // Navigation controls for macOS
                #if os(macOS)
                OnboardingNavigationControls(
                    pageCount: Self.pageCount,
                    currentPage: $currentPage,
                    onComplete: completeOnboarding
                )
                #endif
            }
            #if os(macOS)
            .frame(minWidth: 700, minHeight: 500)
            #endif
        }
    }
    
    // MARK: - Private Methods
    
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
    OnboardingFinalPage {
        print("Completed!")
    }
}
