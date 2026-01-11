//
//  ProStatus.swift
//  ZapPDF
//
//  Model representing detailed subscription status for display in Settings.
//

import Foundation

// MARK: - Pro Status Type

/// Represents the type of Pro subscription.
enum ProType: String, Sendable {
    case monthly
    case annual
    case lifetime
    case none
}

// MARK: - Pro Status Model

/// Detailed subscription status including type, expiration, and renewal info.
///
/// Used to display subscription details in Settings view.
///
/// Example:
/// ```swift
/// if proStatus.isActive {
///     if proStatus.type == .lifetime {
///         Text("Pro Lifetime")
///     } else if let expiration = proStatus.expirationDate {
///         Text("Pro until \(expiration.formatted())")
///     }
/// }
/// ```
struct ProStatus: Sendable {
    /// Whether the user currently has Pro access.
    let isActive: Bool
    
    /// The type of Pro subscription (monthly, annual, lifetime, or none).
    let type: ProType
    
    /// Expiration date for time-limited subscriptions. Nil for lifetime or inactive.
    let expirationDate: Date?
    
    /// Whether the subscription will auto-renew. Nil for lifetime or inactive.
    let willRenew: Bool?
    
    /// The product identifier that granted this status.
    let productIdentifier: String?
    
    // MARK: - Convenience Properties
    
    /// Whether this is a lifetime purchase (never expires).
    var isLifetime: Bool {
        type == .lifetime
    }
    
    /// Whether the subscription is active but will not renew.
    var isExpiring: Bool {
        isActive && !isLifetime && willRenew == false
    }
    
    // MARK: - Factory Methods
    
    /// Creates an inactive (free user) status.
    static let inactive = ProStatus(
        isActive: false,
        type: .none,
        expirationDate: nil,
        willRenew: nil,
        productIdentifier: nil
    )
}
