//
//  UsageManager.swift
//  ZapPDF
//
//  Actor managing free tier usage tracking for the freemium model.
//

import Foundation

// MARK: - Legacy Cache Keys (for migration)

/// Legacy UserDefaults key for Pro status (to be migrated to Keychain)
private let kLegacyCachedIsProKey = "com.zappdf.cached.isPro"

// MARK: - Usage Errors

/// Errors that can occur during usage management.
enum UsageError: Error, LocalizedError, Sendable {
    /// User has exhausted their free actions
    case noActionsRemaining
    
    /// Failed to persist usage data
    case persistenceFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noActionsRemaining:
            return L10n.UsageError.noActionsRemaining
        case .persistenceFailed:
            return L10n.UsageError.persistenceFailed
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noActionsRemaining:
            return L10n.Error.upgradeForUnlimited
        case .persistenceFailed:
            return L10n.Error.tryAgain
        }
    }
}

// MARK: - UsageManager

/// Actor managing free tier usage with thread-safe operations.
///
/// `UsageManager` tracks the number of free actions a user has performed
/// and enforces the freemium limit. Usage is persisted in the Keychain
/// so it survives app reinstalls.
///
/// Example:
/// ```swift
/// let manager = UsageManager.shared
///
/// if await manager.canPerformAction() {
///     // Perform PDF operation...
///     try await manager.recordAction()
/// } else {
///     // Show paywall
/// }
/// ```
actor UsageManager {
    
    // MARK: - Singleton
    
    /// Shared singleton instance.
    static let shared = UsageManager()
    
    // MARK: - Constants
    
    /// Number of free actions allowed before requiring Pro subscription.
    let freeActionLimit: Int
    
    // MARK: - Private Properties
    
    /// Cached remaining actions (nil means not yet loaded)
    private var cachedRemainingActions: Int?
    
    /// Whether this is a Pro user (placeholder for RevenueCat integration)
    private var isPro: Bool = false
    
    /// Whether cached Pro status has been loaded from storage.
    private var hasLoadedCachedProStatus: Bool = false
    
    /// Whether to use in-memory storage only (for testing)
    private let inMemoryOnly: Bool
    
    /// In-memory storage for testing
    private var inMemoryStorage: Int?
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton usage.
    /// Use `UsageManager.shared` instead.
    private init() {
        self.freeActionLimit = 5
        self.inMemoryOnly = false
        // Intentionally defer Keychain reads until first usage query to keep
        // app construction path lightweight.
        self.isPro = false
    }
    
    /// Load cached Pro status from Keychain, with migration from legacy UserDefaults.
    ///
    /// This is a static method called during init before the actor is fully initialized.
    /// It handles migration from the legacy UserDefaults key to secure Keychain storage.
    ///
    /// - Note: Thread Safety
    /// This method is static and called synchronously during `init`. It accesses
    /// `UserDefaults.standard` (thread-safe) and `KeychainHelper` (thread-safe).
    /// It does not access any actor state, making it safe to call from any context
    /// that initializes the actor.
    static func loadCachedProStatus() -> Bool {
        // Try Keychain first (secure storage)
        do {
            if let cached = try KeychainHelper.loadBool(for: .proStatus) {
                return cached
            }
        } catch {
            #if DEBUG
            print("UsageManager: Failed to load pro status from Keychain: \(error)")
            #endif
        }
        
        // Migration: check UserDefaults for legacy cache
        if UserDefaults.standard.bool(forKey: kLegacyCachedIsProKey) {
            // Migrate to Keychain
            do {
                try KeychainHelper.saveBool(true, for: .proStatus)
                UserDefaults.standard.removeObject(forKey: kLegacyCachedIsProKey)
                #if DEBUG
                print("UsageManager: Successfully migrated legacy Pro status to Keychain")
                #endif
                return true
            } catch {
                #if DEBUG
                print("UsageManager: Failed to migrate legacy Pro status: \(error)")
                #endif
                // Return true anyway so user doesn't lose access this session,
                // but migration failed so it will try again next launch
                return true
            }
        }
        
        return false
    }
    
    /// Creates a test instance that uses in-memory storage only.
    ///
    /// This allows tests to run in isolation without affecting the Keychain.
    ///
    /// - Parameter freeActionLimit: Optional custom limit for testing
    /// - Returns: A new UsageManager instance for testing
    static func createTestInstance(freeActionLimit: Int = 5) -> UsageManager {
        UsageManager(freeActionLimit: freeActionLimit, inMemoryOnly: true)
    }
    
    /// Internal initializer for testing.
    private init(freeActionLimit: Int, inMemoryOnly: Bool) {
        self.freeActionLimit = freeActionLimit
        self.inMemoryOnly = inMemoryOnly
        self.inMemoryStorage = nil
    }
    
    // MARK: - Public Methods
    
    /// Get the number of remaining free actions.
    ///
    /// - Returns: Number of actions remaining (0 if exhausted)
    func remainingActions() async -> Int {
        loadCachedProStatusIfNeeded()
        
        // Pro users have unlimited actions
        if isPro {
            return Int.max
        }
        
        // Return cached value if available
        if let cached = cachedRemainingActions {
            return cached
        }
        
        // Use in-memory storage for test instances
        if inMemoryOnly {
            if let stored = inMemoryStorage {
                cachedRemainingActions = stored
                return stored
            } else {
                // First access - initialize with free limit
                inMemoryStorage = freeActionLimit
                cachedRemainingActions = freeActionLimit
                return freeActionLimit
            }
        }
        
        // Load from Keychain or initialize
        do {
            if let stored = try KeychainHelper.loadInt(for: .actionsRemaining) {
                cachedRemainingActions = stored
                return stored
            } else {
                // First launch - initialize with free limit
                try KeychainHelper.saveInt(freeActionLimit, for: .actionsRemaining)
                cachedRemainingActions = freeActionLimit
                return freeActionLimit
            }
        } catch {
            // If Keychain fails, assume first launch
            // Log error in production
            print("UsageManager: Failed to load remaining actions: \(error)")
            cachedRemainingActions = freeActionLimit
            return freeActionLimit
        }
    }
    
    /// Check if the user can perform an action.
    ///
    /// Pro users always return true. Free tier users return true
    /// only if they have remaining actions.
    ///
    /// - Returns: true if user can perform an action
    func canPerformAction() async -> Bool {
        loadCachedProStatusIfNeeded()
        
        // Pro users always can
        if isPro {
            return true
        }
        
        return await remainingActions() > 0
    }
    
    /// Record a completed action, decrementing the remaining count.
    ///
    /// This method should be called after successfully completing a PDF
    /// operation. It decrements the remaining actions count by 1.
    ///
    /// - Throws: `UsageError.noActionsRemaining` if no actions remain
    /// - Throws: `UsageError.persistenceFailed` if storage fails
    func recordAction() async throws {
        // Pro users don't consume actions
        if isPro {
            return
        }
        
        let remaining = await remainingActions()
        
        guard remaining > 0 else {
            throw UsageError.noActionsRemaining
        }
        
        let newRemaining = remaining - 1
        
        // Use in-memory storage for test instances
        if inMemoryOnly {
            inMemoryStorage = newRemaining
            cachedRemainingActions = newRemaining
            return
        }
        
        do {
            try KeychainHelper.saveInt(newRemaining, for: .actionsRemaining)
            cachedRemainingActions = newRemaining
            postStateChangeNotification()
        } catch {
            throw UsageError.persistenceFailed(error)
        }
    }
    
    /// Reset usage to the initial free limit.
    ///
    /// This method is primarily for testing. In production, it could
    /// be used for promotional resets or subscription expiration handling.
    func resetUsage() async {
        // Use in-memory storage for test instances
        if inMemoryOnly {
            inMemoryStorage = freeActionLimit
            cachedRemainingActions = freeActionLimit
            return
        }
        
        do {
            try KeychainHelper.saveInt(freeActionLimit, for: .actionsRemaining)
            cachedRemainingActions = freeActionLimit
        } catch {
            // Log error in production
            print("UsageManager: Failed to reset usage: \(error)")
        }
    }
    
    /// Set Pro status.
    ///
    /// This method is called by RevenueCatManager when subscription
    /// status changes. Pro users have unlimited actions.
    /// The status is persisted to Keychain for secure offline support.
    ///
    /// - Parameter isPro: Whether the user has an active Pro subscription
    func setProStatus(_ isPro: Bool) {
        loadCachedProStatusIfNeeded()
        
        guard self.isPro != isPro else {
            return
        }
        
        self.isPro = isPro
        hasLoadedCachedProStatus = true
        
        // Persist to Keychain for secure offline support on next cold start
        // Skip persistence for test instances to avoid polluting Keychain
        if !inMemoryOnly {
            do {
                try KeychainHelper.saveBool(isPro, for: .proStatus)
            } catch {
                #if DEBUG
                print("UsageManager: Failed to save Pro status to Keychain: \(error)")
                #endif
            }
        }
        
        postStateChangeNotification()
    }
    
    /// Get the current Pro status.
    ///
    /// - Returns: Whether the user has an active Pro subscription
    func getProStatus() -> Bool {
        loadCachedProStatusIfNeeded()
        return isPro
    }
    
    // MARK: - Private Helpers
    
    /// Post a notification that state has changed.
    /// This runs on the main thread to ensure UI updates are safe.
    private func postStateChangeNotification() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .usageStateDidChange, object: nil)
        }
    }
    
    /// Load cached Pro status once, lazily.
    private func loadCachedProStatusIfNeeded() {
        guard !hasLoadedCachedProStatus else {
            return
        }
        
        hasLoadedCachedProStatus = true
        
        // Test instances should not touch persistent storage.
        guard !inMemoryOnly else {
            return
        }
        
        isPro = Self.loadCachedProStatus()
    }
    
    // MARK: - Testing Support
    
    /// Clear the cached value to force a reload from storage.
    /// Used for testing persistence across manager instances.
    func clearCache() {
        cachedRemainingActions = nil
    }
}
