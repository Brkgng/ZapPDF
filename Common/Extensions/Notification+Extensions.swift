//
//  Notification+Extensions.swift
//  ZapPDF
//
//  Centralized notification names for app-level events.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    
    // MARK: - UI Events
    
    /// Posted when all files are cleared from the dashboard.
    /// Includes userInfo with "previousFiles" and "previousSelection" for undo support.
    static let filesCleared = Notification.Name("filesCleared")
    
    // MARK: - Usage & Subscription
    
    /// Posted when the user's subscription or usage state changes.
    /// ViewModels should subscribe to this to refresh their UI.
    static let usageStateDidChange = Notification.Name("usageStateDidChange")
}
