//
//  PageRangeParser.swift
//  ZapPDF
//
//  Utility for parsing page range strings like "1-5, 10, 15-20".
//

import Foundation

/// Errors that can occur during page range parsing.
enum PageRangeParseError: LocalizedError {
    case invalidFormat(String)
    case pageOutOfRange(page: Int, maxPage: Int)
    case emptyRange
    case invalidRange(start: Int, end: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let text):
            return L10n.PageRangeError.invalidFormat(text)
        case .pageOutOfRange(let page, let maxPage):
            return L10n.PageRangeError.pageOutOfRange(page, maxPage)
        case .emptyRange:
            return L10n.PageRangeError.emptyRange
        case .invalidRange(let start, let end):
            return L10n.PageRangeError.invalidRange(start, end)
        }
    }
}

/// Utility for parsing page range strings.
///
/// Supports formats like:
/// - Single pages: "1, 5, 10"
/// - Ranges: "1-5, 10-15"
/// - Mixed: "1-5, 10, 15-20"
///
/// Example:
/// ```swift
/// let ranges = try PageRangeParser.parse("1-5, 10, 15-20", maxPage: 20)
/// // Returns: [1...5, 10...10, 15...20]
/// ```
enum PageRangeParser {
    
    /// Parse a page range string into an array of closed ranges.
    ///
    /// - Parameters:
    ///   - input: The input string (e.g., "1-5, 10, 15-20")
    ///   - maxPage: The maximum valid page number
    /// - Returns: Array of 1-indexed closed ranges
    /// - Throws: `PageRangeParseError` if parsing fails
    static func parse(_ input: String, maxPage: Int) throws -> [ClosedRange<Int>] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw PageRangeParseError.emptyRange
        }
        
        var ranges: [ClosedRange<Int>] = []
        
        // Split by comma
        let parts = trimmed.components(separatedBy: ",")
        
        for part in parts {
            let cleaned = part.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }
            
            if cleaned.contains("-") {
                // Range format: "1-5"
                let rangeParts = cleaned.components(separatedBy: "-")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                guard rangeParts.count == 2,
                      let start = Int(rangeParts[0]),
                      let end = Int(rangeParts[1]) else {
                    throw PageRangeParseError.invalidFormat(cleaned)
                }
                
                guard start <= end else {
                    throw PageRangeParseError.invalidRange(start: start, end: end)
                }
                
                guard start >= 1 else {
                    throw PageRangeParseError.pageOutOfRange(page: start, maxPage: maxPage)
                }
                
                guard end <= maxPage else {
                    throw PageRangeParseError.pageOutOfRange(page: end, maxPage: maxPage)
                }
                
                ranges.append(start...end)
            } else {
                // Single page format: "10"
                guard let page = Int(cleaned) else {
                    throw PageRangeParseError.invalidFormat(cleaned)
                }
                
                guard page >= 1, page <= maxPage else {
                    throw PageRangeParseError.pageOutOfRange(page: page, maxPage: maxPage)
                }
                
                ranges.append(page...page)
            }
        }
        
        guard !ranges.isEmpty else {
            throw PageRangeParseError.emptyRange
        }
        
        // Sort ranges by start page
        return ranges.sorted { $0.lowerBound < $1.lowerBound }
    }
    
    /// Convert page ranges to individual page indices.
    ///
    /// - Parameter ranges: Array of closed ranges
    /// - Returns: Sorted, deduplicated array of page numbers
    static func toPageIndices(_ ranges: [ClosedRange<Int>]) -> [Int] {
        var indices = Set<Int>()
        for range in ranges {
            for page in range {
                indices.insert(page)
            }
        }
        return indices.sorted()
    }
    
    /// Validate a page range string without fully parsing it.
    ///
    /// - Parameters:
    ///   - input: The input string to validate
    ///   - maxPage: The maximum valid page number
    /// - Returns: `true` if the string is valid
    static func isValid(_ input: String, maxPage: Int) -> Bool {
        do {
            _ = try parse(input, maxPage: maxPage)
            return true
        } catch {
            return false
        }
    }
}
