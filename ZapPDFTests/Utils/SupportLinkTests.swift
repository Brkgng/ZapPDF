//
//  SupportLinkTests.swift
//  ZapPDFTests
//
//  Unit tests for SupportLink.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("SupportLink Tests")
struct SupportLinkTests {

    // MARK: - mailtoURL

    @Test("Builds a mailto URL with the support address")
    func buildsMailtoURLWithSupportAddress() throws {
        let url = try #require(SupportLink.mailtoURL(appName: "ZapPDF", appVersion: "1.2.3"))

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.scheme == "mailto")
        #expect(components?.path == SupportLink.supportEmailAddress)
    }

    @Test("Subject query item includes app name and public version")
    func subjectIncludesAppNameAndPublicVersion() throws {
        let url = try #require(SupportLink.mailtoURL(appName: "ZapPDF", appVersion: "1.2.3 (1)"))

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let subject = try #require(components?.queryItems?.first { $0.name == "subject" }?.value)

        #expect(subject == "ZapPDF Support (v1.2.3)")
    }

    // MARK: - subject

    @Test("Subject formats app name and version")
    func subjectFormatsAppNameAndVersion() {
        let subject = SupportLink.subject(appName: "ZapPDF", appVersion: "1.2.3")
        #expect(subject == "ZapPDF Support (v1.2.3)")
    }

    @Test("Subject omits build when version string has one")
    func subjectOmitsBuildWhenPresent() {
        let subject = SupportLink.subject(appName: "ZapPDF", appVersion: "1.2.3 (1)")
        #expect(subject == "ZapPDF Support (v1.2.3)")
    }

    @Test("Subject omits build for single-component version")
    func subjectOmitsBuildForSingleComponentVersion() {
        let subject = SupportLink.subject(appName: "ZapPDF", appVersion: "1 (5)")
        #expect(subject == "ZapPDF Support (v1)")
    }

    @Test("Subject omits version segment when version is empty")
    func subjectOmitsVersionWhenEmpty() {
        let subject = SupportLink.subject(appName: "ZapPDF", appVersion: "")
        #expect(subject == "ZapPDF Support")
    }

    @Test("Subject omits version segment when version is whitespace")
    func subjectOmitsVersionWhenWhitespace() {
        let subject = SupportLink.subject(appName: "ZapPDF", appVersion: "  ")
        #expect(subject == "ZapPDF Support")
    }
}
