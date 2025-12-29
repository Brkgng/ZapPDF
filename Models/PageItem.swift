//
//  PageItem.swift
//  ZapPDF
//
//  Identifiable page wrapper for drag-and-drop reordering.
//

import Foundation
import CoreGraphics

/// Represents a single page in a PDF document for reordering.
///
/// `PageItem` wraps page information needed for the page reorder UI,
/// including the original index and optional cached thumbnail. It
/// conforms to `Identifiable` for use with SwiftUI lists and grids.
///
/// Example:
/// ```swift
/// // Create pages for a 5-page document
/// let pages = (0..<5).map { PageItem(originalIndex: $0) }
///
/// // Check if order has changed after reordering
/// if pages.hasChanges {
///     let newOrder = pages.reorderedIndices
///     // newOrder: [0, 2, 1, 3, 4] - page 2 and 3 swapped
/// }
/// ```
struct PageItem: Identifiable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier for this page instance.
    let id: UUID
    
    /// Original 0-based page index in the source PDF.
    let originalIndex: Int
    
    // MARK: - Initialization
    
    /// Creates a PageItem for the given page index.
    ///
    /// - Parameter originalIndex: The 0-based page index in the source PDF
    init(originalIndex: Int) {
        self.id = UUID()
        self.originalIndex = originalIndex
    }
    
    /// Internal initializer for testing with specific ID.
    init(id: UUID = UUID(), originalIndex: Int) {
        self.id = id
        self.originalIndex = originalIndex
    }
    
    // MARK: - Computed Properties
    
    /// Display page number (1-based) for UI.
    var displayPageNumber: Int {
        originalIndex + 1
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PageItem, rhs: PageItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PageItem Collection Extension

extension Array where Element == PageItem {
    
    /// Get the new page order as an array of original 0-based indices.
    ///
    /// This is used when saving the reordered PDF to know which source
    /// pages go where in the output.
    ///
    /// Example:
    /// ```swift
    /// // Original: pages at indices 0, 1, 2
    /// // After reordering: page 2 moved to first position
    /// let indices = pages.reorderedIndices  // [2, 0, 1]
    /// ```
    var reorderedIndices: [Int] {
        map { $0.originalIndex }
    }
    
    /// Check if the order has changed from the original sequence.
    ///
    /// Returns `true` if any page is in a different position than its
    /// original index. Used to enable/disable the "Save" button.
    var hasChanges: Bool {
        for (currentPosition, page) in enumerated() {
            if currentPosition != page.originalIndex {
                return true
            }
        }
        return false
    }
    
    /// Create a page array for a PDF with the given page count.
    ///
    /// - Parameter pageCount: Number of pages in the PDF (must be > 0)
    /// - Returns: Array of PageItems in original order
    static func create(pageCount: Int) -> [PageItem] {
        guard pageCount > 0 else { return [] }
        return (0..<pageCount).map { PageItem(originalIndex: $0) }
    }
}
