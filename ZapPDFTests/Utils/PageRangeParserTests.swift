//
//  PageRangeParserTests.swift
//  ZapPDFTests
//
//  Unit tests for PageRangeParser.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("PageRangeParser Tests")
struct PageRangeParserTests {
    
    // MARK: - Valid Input Tests
    
    @Test("Parses single page")
    func parsesSinglePage() throws {
        let ranges = try PageRangeParser.parse("5", maxPage: 10)
        #expect(ranges.count == 1)
        #expect(ranges[0] == 5...5)
    }
    
    @Test("Parses multiple single pages")
    func parsesMultipleSinglePages() throws {
        let ranges = try PageRangeParser.parse("1, 5, 10", maxPage: 10)
        #expect(ranges.count == 3)
        #expect(ranges[0] == 1...1)
        #expect(ranges[1] == 5...5)
        #expect(ranges[2] == 10...10)
    }
    
    @Test("Parses simple range")
    func parsesSimpleRange() throws {
        let ranges = try PageRangeParser.parse("1-5", maxPage: 10)
        #expect(ranges.count == 1)
        #expect(ranges[0] == 1...5)
    }
    
    @Test("Parses multiple ranges")
    func parsesMultipleRanges() throws {
        let ranges = try PageRangeParser.parse("1-5, 10-15", maxPage: 20)
        #expect(ranges.count == 2)
        #expect(ranges[0] == 1...5)
        #expect(ranges[1] == 10...15)
    }
    
    @Test("Parses mixed single pages and ranges")
    func parsesMixedSinglePagesAndRanges() throws {
        let ranges = try PageRangeParser.parse("1-5, 10, 15-20", maxPage: 20)
        #expect(ranges.count == 3)
        #expect(ranges[0] == 1...5)
        #expect(ranges[1] == 10...10)
        #expect(ranges[2] == 15...20)
    }
    
    @Test("Handles whitespace in input")
    func handlesWhitespaceInInput() throws {
        let ranges = try PageRangeParser.parse("  1 - 5 ,  10  , 15 - 20  ", maxPage: 20)
        #expect(ranges.count == 3)
        #expect(ranges[0] == 1...5)
        #expect(ranges[1] == 10...10)
        #expect(ranges[2] == 15...20)
    }
    
    @Test("Sorts ranges by start page")
    func sortsRangesByStartPage() throws {
        let ranges = try PageRangeParser.parse("10-15, 1-5, 20", maxPage: 20)
        #expect(ranges.count == 3)
        #expect(ranges[0] == 1...5)
        #expect(ranges[1] == 10...15)
        #expect(ranges[2] == 20...20)
    }
    
    // MARK: - Error Tests
    
    @Test("Throws on empty input")
    func throwsOnEmptyInput() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("", maxPage: 10)
        }
    }
    
    @Test("Throws on whitespace-only input")
    func throwsOnWhitespaceOnlyInput() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("   ", maxPage: 10)
        }
    }
    
    @Test("Throws on invalid format")
    func throwsOnInvalidFormat() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("abc", maxPage: 10)
        }
    }
    
    @Test("Throws on page below 1")
    func throwsOnPageBelowOne() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("0", maxPage: 10)
        }
    }
    
    @Test("Throws on page above max")
    func throwsOnPageAboveMax() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("15", maxPage: 10)
        }
    }
    
    @Test("Throws on invalid range (start > end)")
    func throwsOnInvalidRangeStartGreaterThanEnd() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("10-5", maxPage: 10)
        }
    }
    
    @Test("Throws on range with page above max")
    func throwsOnRangeWithPageAboveMax() {
        #expect(throws: PageRangeParseError.self) {
            _ = try PageRangeParser.parse("1-15", maxPage: 10)
        }
    }
    
    // MARK: - toPageIndices Tests
    
    @Test("Converts ranges to page indices")
    func convertsRangesToPageIndices() {
        let ranges = [1...3, 5...5, 8...10]
        let indices = PageRangeParser.toPageIndices(ranges)
        #expect(indices == [1, 2, 3, 5, 8, 9, 10])
    }
    
    @Test("Deduplicates overlapping ranges")
    func deduplicatesOverlappingRanges() {
        let ranges = [1...5, 3...7] // Overlapping at 3, 4, 5
        let indices = PageRangeParser.toPageIndices(ranges)
        #expect(indices == [1, 2, 3, 4, 5, 6, 7])
    }
    
    @Test("Returns empty array for empty ranges")
    func returnsEmptyArrayForEmptyRanges() {
        let indices = PageRangeParser.toPageIndices([])
        #expect(indices.isEmpty)
    }
    
    // MARK: - isValid Tests
    
    @Test("isValid returns true for valid input")
    func isValidReturnsTrueForValidInput() {
        #expect(PageRangeParser.isValid("1-5, 10", maxPage: 10) == true)
    }
    
    @Test("isValid returns false for invalid input")
    func isValidReturnsFalseForInvalidInput() {
        #expect(PageRangeParser.isValid("15", maxPage: 10) == false)
    }
    
    @Test("isValid returns false for empty input")
    func isValidReturnsFalseForEmptyInput() {
        #expect(PageRangeParser.isValid("", maxPage: 10) == false)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handles single page equal to max")
    func handlesSinglePageEqualToMax() throws {
        let ranges = try PageRangeParser.parse("10", maxPage: 10)
        #expect(ranges.count == 1)
        #expect(ranges[0] == 10...10)
    }
    
    @Test("Handles range covering all pages")
    func handlesRangeCoveringAllPages() throws {
        let ranges = try PageRangeParser.parse("1-10", maxPage: 10)
        #expect(ranges.count == 1)
        #expect(ranges[0] == 1...10)
    }
    
    @Test("Handles same page as range")
    func handlesSamePageAsRange() throws {
        let ranges = try PageRangeParser.parse("5-5", maxPage: 10)
        #expect(ranges.count == 1)
        #expect(ranges[0] == 5...5)
    }
}
