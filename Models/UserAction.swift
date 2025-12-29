//
//  UserAction.swift
//  ZapPDF
//
//  Type-safe enumeration of available PDF operations.
//

import SwiftUI

/// Available PDF operations in ZapPDF.
///
/// Each action represents a distinct PDF manipulation operation that
/// users can perform. The enum provides display information, icons,
/// and validation rules for each operation.
///
/// Example:
/// ```swift
/// let action = UserAction.merge
/// print(action.displayName)  // "Merge PDFs"
/// print(action.requiresMultipleFiles)  // true
/// ```
enum UserAction: String, CaseIterable, Identifiable, Sendable {
    case merge
    case split
    case reorder
    case convert  // Future: PDF to image, etc.
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// User-facing name for the action.
    var displayName: String {
        switch self {
        case .merge:
            return "Merge PDFs"
        case .split:
            return "Split PDF"
        case .reorder:
            return "Reorder Pages"
        case .convert:
            return "Convert PDF"
        }
    }
    
    /// SF Symbol name for the action icon.
    var iconName: String {
        switch self {
        case .merge:
            return "doc.on.doc"
        case .split:
            return "scissors"
        case .reorder:
            return "arrow.up.arrow.down"
        case .convert:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    /// Short description of what the action does.
    var description: String {
        switch self {
        case .merge:
            return "Combine multiple PDFs into one document"
        case .split:
            return "Extract pages or split into multiple documents"
        case .reorder:
            return "Reorder pages within a PDF"
        case .convert:
            return "Convert PDF to other formats"
        }
    }
    
    // MARK: - Validation
    
    /// Whether this action requires multiple files to be selected.
    var requiresMultipleFiles: Bool {
        switch self {
        case .merge:
            return true
        case .split, .reorder, .convert:
            return false
        }
    }
    
    /// Minimum number of files required for this action.
    var minimumFileCount: Int {
        requiresMultipleFiles ? 2 : 1
    }
    
    /// Maximum number of files allowed for this action.
    /// Returns nil if there's no maximum.
    var maximumFileCount: Int? {
        switch self {
        case .merge:
            return nil  // No limit for merging
        case .split, .reorder, .convert:
            return 1  // Single file operations
        }
    }
    
    /// Check if the given file count is valid for this action.
    func isValidFileCount(_ count: Int) -> Bool {
        guard count >= minimumFileCount else { return false }
        if let max = maximumFileCount {
            return count <= max
        }
        return true
    }
    
    /// Error message when file count is invalid.
    func fileCountError(for count: Int) -> String? {
        if count < minimumFileCount {
            if requiresMultipleFiles {
                return "Please select at least 2 PDF files to merge."
            } else {
                return "Please select a PDF file."
            }
        }
        if let max = maximumFileCount, count > max {
            return "Please select only one PDF file for this action."
        }
        return nil
    }
    
    // MARK: - Accent Color
    
    /// Accent color for the action's UI elements.
    var accentColor: Color {
        switch self {
        case .merge:
            return .blue
        case .split:
            return .orange
        case .reorder:
            return .green
        case .convert:
            return .purple
        }
    }
}

// MARK: - UserAction Groups

extension UserAction {
    /// Actions available in the free tier.
    static var freeActions: [UserAction] {
        [.merge, .split, .reorder]
    }
    
    /// Actions that require Pro subscription.
    static var proActions: [UserAction] {
        [.convert]
    }
    
    /// Whether this action is available in the free tier.
    var isFreeTierAction: Bool {
        UserAction.freeActions.contains(self)
    }
}
