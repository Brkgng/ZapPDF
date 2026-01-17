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
    case editPages  // Formerly "reorder" - now includes rotate, delete, reorder
    case flatten    // Flatten annotations and form fields into page content
    case convert    // Future: PDF to image, etc.
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// User-facing name for the action.
    var displayName: String {
        switch self {
        case .merge:
            return L10n.Operation.Merge.title
        case .split:
            return L10n.Operation.Split.title
        case .editPages:
            return L10n.Operation.EditPages.title
        case .flatten:
            return L10n.Operation.Flatten.title
        case .convert:
            return L10n.Operation.Convert.title
        }
    }
    
    /// SF Symbol name for the action icon.
    var iconName: String {
        switch self {
        case .merge:
            return "doc.on.doc"
        case .split:
            return "scissors"
        case .editPages:
            return "square.and.pencil"
        case .flatten:
            return "square.on.square.dashed"
        case .convert:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    /// Short description of what the action does.
    var description: String {
        switch self {
        case .merge:
            return L10n.Operation.Merge.description
        case .split:
            return L10n.Operation.Split.description
        case .editPages:
            return L10n.Operation.EditPages.description
        case .flatten:
            return L10n.Operation.Flatten.description
        case .convert:
            return L10n.Operation.Convert.description
        }
    }
    
    // MARK: - Validation
    
    /// Whether this action requires multiple files to be selected.
    var requiresMultipleFiles: Bool {
        switch self {
        case .merge:
            return true
        case .split, .editPages, .flatten, .convert:
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
        case .split, .editPages, .flatten, .convert:
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
                return L10n.Validation.selectMultipleForMerge
            } else {
                return L10n.Validation.selectOneFile
            }
        }
        if let max = maximumFileCount, count > max {
            return L10n.Validation.selectOnlyOne
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
        case .editPages:
            return .green
        case .flatten:
            return .teal
        case .convert:
            return .purple
        }
    }
}


