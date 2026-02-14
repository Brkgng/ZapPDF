//
//  SplitOutputNamingTests.swift
//  ZapPDFTests
//
//  Unit tests for split output filename generation.
//

import Testing
@testable import ZapPDF

@Suite("SplitOutputNaming Tests")
struct SplitOutputNamingTests {

    @Test("Builds compact page token from mixed ranges")
    func buildsCompactPageToken() {
        let token = SplitOutputNaming.pageToken(from: [1, 2, 3, 5, 7, 8])
        #expect(token == "1-3_5_7-8")
    }

    @Test("Sorts pages before tokenization")
    func sortsPagesBeforeTokenization() {
        let token = SplitOutputNaming.pageToken(from: [5, 1, 4, 3])
        #expect(token == "1_3-5")
    }

    @Test("Returns fallback token for empty input")
    func returnsFallbackTokenForEmptyInput() {
        let token = SplitOutputNaming.pageToken(from: [])
        #expect(token == "pages")
    }

    @Test("Builds stem with optional timestamp and duplicate suffix")
    func buildsStemWithTimestampAndDuplicateSuffix() {
        let baseStem = SplitOutputNaming.makeStem(
            baseName: "MyPDF",
            pageToken: "1-5",
            timestamp: "250214_163355",
            duplicateIndex: nil
        )
        #expect(baseStem == "MyPDF_p1-5_250214_163355")

        let duplicateStem = SplitOutputNaming.makeStem(
            baseName: "MyPDF",
            pageToken: "1-5",
            timestamp: "250214_163355",
            duplicateIndex: 2
        )
        #expect(duplicateStem == "MyPDF_p1-5_250214_163355_2")
    }
}
