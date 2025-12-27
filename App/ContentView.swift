//
//  ContentView.swift
//  ZapPDF
//
//  Main content view that manages onboarding and dashboard flow.
//

import SwiftUI

struct ContentView: View {
    /// Tracks if user has completed onboarding.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        if hasCompletedOnboarding {
            DashboardView()
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
}
