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
    
    /// Shared dashboard view model (injected for external file handling).
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    
    var body: some View {
        // Skip onboarding if files were added via "Open In"
        if hasCompletedOnboarding || dashboardViewModel.hasFiles {
            DashboardView()
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DashboardViewModel())
}
