//
//  Date+Filename.swift
//  ZapPDF
//
//  Extension for generating filename-safe timestamp strings.
//

import Foundation

extension Date {
    /// Generates a compact timestamp string suitable for filenames.
    ///
    /// Format: `YYMMDD_HHmmss` (e.g., "250101_215738")
    ///
    /// This format is:
    /// - Compact (13 characters)
    /// - Human-readable
    /// - Filesystem-safe (no special characters)
    /// - Chronologically sortable
    ///
    /// Example:
    /// ```swift
    /// let timestamp = Date.filenameTimestamp() // "250101_215738"
    /// let filename = "Merged_\(timestamp).pdf" // "Merged_250101_215738.pdf"
    /// ```
    ///
    /// - Parameter date: The date to format (defaults to current date/time)
    /// - Returns: A filename-safe timestamp string
    nonisolated static func filenameTimestamp(from date: Date = Date()) -> String {
        // Use a simple string format to avoid DateFormatter thread-safety issues
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        let year = (components.year ?? 2025) % 100  // Last 2 digits
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        
        return String(format: "%02d%02d%02d_%02d%02d%02d", year, month, day, hour, minute, second)
    }
}

