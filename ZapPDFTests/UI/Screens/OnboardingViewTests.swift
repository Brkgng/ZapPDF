//
//  OnboardingViewTests.swift
//  ZapPDFTests
//
//  Unit tests for OnboardingView.
//

import Testing
import SwiftUI
@testable import ZapPDF

@Suite("OnboardingView Tests")
struct OnboardingViewTests {

    @Test("OnboardingPage stores its parameters")
    func onboardingPageStoresParameters() {
        let page = OnboardingPage(
            iconName: "doc.text.fill",
            iconColor: .blue,
            title: "Test Title",
            description: "Test Description"
        )

        #expect(page.iconName == "doc.text.fill")
        #expect(page.title == "Test Title")
        #expect(page.description == "Test Description")
    }

    @Test("OnboardingView has correct page count")
    func pageCountIsCorrect() {
        #expect(OnboardingView.pageCount == 4)
    }
}
