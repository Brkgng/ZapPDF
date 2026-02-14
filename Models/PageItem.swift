//
//  PageItem.swift
//  ZapPDF
//
//  Identifiable page wrapper for drag-and-drop reordering.
//

import Foundation
import CoreGraphics

// MARK: - PageRotation

/// Represents the rotation angle for a PDF page.
///
/// `PageRotation` tracks the cumulative rotation applied to a page
/// during editing. Rotations are always in 90° increments.
///
/// Example:
/// ```swift
/// var rotation = PageRotation.none
/// rotation.rotateClockwise()      // now .clockwise90
/// rotation.rotateClockwise()      // now .clockwise180
/// rotation.rotateCounterClockwise() // back to .clockwise90
/// ```
enum PageRotation: Int, Sendable, CaseIterable, Codable {
    case none = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270  // Same as counterClockwise90
    
    /// The rotation in degrees (0, 90, 180, or 270).
    var degrees: Int { rawValue }
    
    /// Rotate 90° clockwise.
    mutating func rotateClockwise() {
        self = PageRotation(rawValue: (self.rawValue + 90) % 360) ?? .none
    }
    
    /// Rotate 90° counter-clockwise.
    mutating func rotateCounterClockwise() {
        self = PageRotation(rawValue: (self.rawValue + 270) % 360) ?? .none
    }
    
    /// Returns a new rotation rotated 90° clockwise.
    func rotatedClockwise() -> PageRotation {
        PageRotation(rawValue: (self.rawValue + 90) % 360) ?? .none
    }
    
    /// Returns a new rotation rotated 90° counter-clockwise.
    func rotatedCounterClockwise() -> PageRotation {
        PageRotation(rawValue: (self.rawValue + 270) % 360) ?? .none
    }
}

// MARK: - PageItem


/// Represents a single page in a PDF document for editing.
///
/// `PageItem` wraps page information needed for the page editor UI,
/// including the original index, rotation state, and identity for
/// SwiftUI lists and grids.
///
/// Example:
/// ```swift
/// // Create pages for a 5-page document
/// var pages = (0..<5).map { PageItem(originalIndex: $0) }
///
/// // Rotate a page
/// pages[0].rotation.rotateClockwise()
///
/// // Check if any changes exist
/// if pages.hasChanges {
///     let newOrder = pages.reorderedIndices
///     let rotations = pages.rotationsMap
/// }
/// ```
struct PageItem: Identifiable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier for this page instance.
    let id: UUID
    
    /// Original 0-based page index in the source PDF.
    let originalIndex: Int
    
    /// The rotation applied to this page (default: none).
    var rotation: PageRotation = .none
    
    // MARK: - Initialization
    
    /// Creates a PageItem for the given page index.
    ///
    /// - Parameter originalIndex: The 0-based page index in the source PDF
    init(originalIndex: Int) {
        self.id = UUID()
        self.originalIndex = originalIndex
        self.rotation = .none
    }
    
    /// Internal initializer for testing with specific ID and rotation.
    init(id: UUID = UUID(), originalIndex: Int, rotation: PageRotation = .none) {
        self.id = id
        self.originalIndex = originalIndex
        self.rotation = rotation
    }
    
    // MARK: - Computed Properties
    
    /// Display page number (1-based) for UI.
    var displayPageNumber: Int {
        originalIndex + 1
    }
    
    /// Whether this page has been rotated from its original orientation.
    var isRotated: Bool {
        rotation != .none
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
    
    /// Get all page rotations as a dictionary.
    ///
    /// Maps original page index to rotation. Only includes pages
    /// that have been rotated (rotation != .none).
    ///
    /// Example:
    /// ```swift
    /// // Page at original index 2 rotated 90° clockwise
    /// let rotations = pages.rotationsMap  // [2: .clockwise90]
    /// ```
    var rotationsMap: [Int: PageRotation] {
        var map: [Int: PageRotation] = [:]
        for page in self where page.rotation != .none {
            map[page.originalIndex] = page.rotation
        }
        return map
    }

    /// Returns whether the page at `currentIndex` has been manually reordered.
    ///
    /// This detects relative-order inversions between the page and other
    /// remaining pages. Pure deletion shifts do not create inversions and
    /// therefore return `false`.
    ///
    /// - Parameter currentIndex: Current position in this array.
    /// - Returns: `true` if relative order indicates manual reordering.
    func isManuallyReordered(at currentIndex: Int) -> Bool {
        guard indices.contains(currentIndex) else { return false }

        let page = self[currentIndex]
        let originalIndex = page.originalIndex

        // Any earlier page that originally came after this one means reorder.
        if self[..<currentIndex].contains(where: { $0.originalIndex > originalIndex }) {
            return true
        }

        // Any later page that originally came before this one means reorder.
        if self[(currentIndex + 1)...].contains(where: { $0.originalIndex < originalIndex }) {
            return true
        }

        return false
    }
    
    /// Check if any changes have been made (position or rotation).
    ///
    /// Returns `true` if:
    /// - Any page is in a different position than its original index
    /// - Any page has been rotated
    /// - Any page has been deleted (count differs from original positions)
    ///
    /// Used to enable/disable the "Save" button.
    var hasChanges: Bool {
        for (currentPosition, page) in enumerated() {
            // Check position change
            if currentPosition != page.originalIndex {
                return true
            }
            // Check rotation change
            if page.rotation != .none {
                return true
            }
        }
        // Check for deletions (original indices should be contiguous 0..<count)
        let originalIndices = Set(map { $0.originalIndex })
        if originalIndices.count != count {
            return true
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
