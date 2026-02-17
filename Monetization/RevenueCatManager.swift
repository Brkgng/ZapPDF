//
//  RevenueCatManager.swift
//  ZapPDF
//
//  RevenueCat SDK wrapper implementing SubscriptionManaging protocol.
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Cache Keys

/// Keys for persisting entitlement state to UserDefaults.
/// Keys for persisting entitlement state to UserDefaults.
private enum CacheKeys {
    static let lastSync = "com.zappdf.cached.lastSync"
}

// MARK: - Debug Logging

/// Debug logging helper for RevenueCat operations.
private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

// MARK: - RevenueCat Manager

/// Actor managing RevenueCat SDK integration for subscriptions.
///
/// `RevenueCatManager` wraps the RevenueCat SDK, providing:
/// - SDK initialization and configuration
/// - Subscription status tracking with offline caching
/// - Purchase and restore flows
/// - Real-time updates via PurchasesDelegate
/// - Automatic sync with UsageManager
///
/// Example:
/// ```swift
/// // SDK is configured automatically in AppDelegate
///
/// // Check subscription status
/// if await RevenueCatManager.shared.isPro {
///     // User has Pro access
/// }
/// ```
actor RevenueCatManager: SubscriptionManaging {
    
    enum RefreshReason: String, Sendable {
        case appBecameActive
        case settingsOpened
        case paywallPresented
        case purchaseCompleted
        case restoreCompleted
        case manual
    }
    
    // MARK: - Singleton
    
    /// Shared singleton instance.
    static let shared = RevenueCatManager()
    
    // MARK: - State
    
    /// Whether the user has an active Pro subscription.
    private(set) var isPro: Bool = false
    
    /// Detailed subscription status.
    private(set) var proStatus: ProStatus = .inactive
    
    /// Whether the SDK has been configured.
    private(set) var isConfigured: Bool = false
    
    /// Whether a status refresh is already running.
    private var isRefreshingStatus: Bool = false
    
    /// Whether offerings are currently being fetched.
    private var isWarmingOfferings: Bool = false
    
    /// Last successful status refresh timestamp.
    private var lastStatusRefreshAt: Date?
    
    #if canImport(RevenueCat)
    /// Cached offerings from RevenueCat.
    private var offerings: Offerings?
    #endif
    
    // MARK: - Initialization
    
    private init() {
        // Cached state is now managed by UsageManager (Keychain)
        // We don't load anything here to avoid source-of-truth conflicts
    }
    
    // MARK: - Configuration
    
    /// Called by AppDelegate after SDK is configured synchronously.
    ///
    /// This method only marks the SDK as ready and registers the delegate.
    /// It intentionally avoids network calls to keep app launch fast.
    func onSDKConfigured() async {
        _ = await ensureSDKReady()
    }
    
    // MARK: - Offline Caching
    
    /// Cache entitlement state to UserDefaults for offline support.
    private func cacheState() {
        UserDefaults.standard.set(Date(), forKey: CacheKeys.lastSync)
    }
    
    // MARK: - Status
    
    /// Refresh subscription status from RevenueCat.
    func refreshStatus() async {
        await refreshStatusIfNeeded(reason: .manual, force: true)
    }
    
    /// Refresh status when needed, with throttling to avoid launch/update storms.
    func refreshStatusIfNeeded(reason: RefreshReason, force: Bool = false) async {
        #if canImport(RevenueCat)
        guard await ensureSDKReady() else {
            return
        }
        
        guard !isRefreshingStatus else {
            debugLog("⚠️ RevenueCatManager: refresh skipped (\(reason.rawValue)) - already in progress")
            return
        }
        
        let now = Date()
        if !force,
           let lastRefresh = lastStatusRefreshAt,
           now.timeIntervalSince(lastRefresh) < minimumRefreshInterval(for: reason) {
            debugLog("⚠️ RevenueCatManager: refresh skipped (\(reason.rawValue)) - throttled")
            return
        }
        
        isRefreshingStatus = true
        
        defer {
            isRefreshingStatus = false
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            lastStatusRefreshAt = Date()
            await handleCustomerInfoUpdate(customerInfo)
        } catch {
            debugLog("RevenueCatManager: Failed to refresh status: \(error.localizedDescription)")
            // Keep cached/current status on error
        }
        #endif
    }
    
    /// Handle customer info updates (from delegate or manual refresh).
    func handleCustomerInfoUpdate(_ customerInfo: Any) async {
        #if canImport(RevenueCat)
        guard let info = customerInfo as? CustomerInfo else { return }
        
        lastStatusRefreshAt = Date()
        
        let entitlement = info.entitlements[StoreConfiguration.EntitlementID.pro]
        let hasProEntitlement = entitlement?.isActive == true
        
        // Update state
        isPro = hasProEntitlement
        
        // Extract detailed subscription info
        if hasProEntitlement, let ent = entitlement {
            let productId = ent.productIdentifier
            let proType = determineProType(from: productId)
            
            proStatus = ProStatus(
                isActive: true,
                type: proType,
                expirationDate: ent.expirationDate,
                willRenew: ent.willRenew,
                productIdentifier: productId
            )
            
            debugLog("📊 Subscription: \(proType.rawValue), expires: \(ent.expirationDate?.description ?? "never"), willRenew: \(ent.willRenew)")
        } else {
            proStatus = .inactive
            debugLog("📊 Subscription status: Free user")
        }
        
        // Persist for offline support
        cacheState()
        
        // Sync with UsageManager
        await UsageManager.shared.setProStatus(hasProEntitlement)
        #endif
    }
    
    /// Pre-fetch offerings only when paywall/subscription data is needed.
    func warmOfferingsIfNeeded() async {
        #if canImport(RevenueCat)
        guard await ensureSDKReady() else {
            return
        }
        
        guard offerings == nil else {
            return
        }
        
        guard !isWarmingOfferings else {
            return
        }
        
        isWarmingOfferings = true
        
        defer {
            isWarmingOfferings = false
        }
        
        do {
            offerings = try await Purchases.shared.offerings()
            
            if let current = offerings?.current {
                debugLog("✅ RevenueCatManager: warmed offerings '\(current.identifier)' with \(current.availablePackages.count) packages")
            } else {
                debugLog("⚠️ RevenueCatManager: warmed offerings but no 'current' offering configured")
            }
        } catch {
            debugLog("❌ RevenueCatManager: Failed to warm offerings: \(error.localizedDescription)")
        }
        #endif
    }
    
    #if canImport(RevenueCat)
    /// Determine ProType from product identifier.
    private func determineProType(from productId: String) -> ProType {
        if productId.contains("lifetime") || productId == StoreConfiguration.ProductID.lifetime {
            return .lifetime
        } else if productId.contains("yearly") || productId.contains("annual") || productId == StoreConfiguration.ProductID.yearly {
            return .annual
        } else if productId.contains("monthly") || productId == StoreConfiguration.ProductID.monthly {
            return .monthly
        }
        return .annual // Default fallback
    }
    #endif
    
    // MARK: - Packages
    
    /// Available subscription packages for purchase.
    var availablePackages: [SubscriptionPackage] {
        get async {
            #if canImport(RevenueCat)
            guard await ensureSDKReady() else {
                debugLog("⚠️ availablePackages: SDK not configured yet")
                return []
            }
            
            await warmOfferingsIfNeeded()
            
            // Convert RevenueCat packages to our abstraction
            guard let currentOffering = offerings?.current else {
                debugLog("⚠️ availablePackages: No 'current' offering found")
                return []
            }
            
            let packages = currentOffering.availablePackages.map { rcPackage in
                SubscriptionPackage(
                    id: rcPackage.identifier,
                    packageType: mapPackageType(rcPackage.packageType),
                    localizedPriceString: rcPackage.localizedPriceString,
                    localizedTitle: rcPackage.storeProduct.localizedTitle,
                    rcPackage: rcPackage
                )
            }
            
            debugLog("✅ availablePackages: Returning \(packages.count) packages from '\(currentOffering.identifier)'")
            return packages
            #else
            return []
            #endif
        }
    }
    
    // MARK: - Purchase
    
    /// Purchase a subscription package.
    ///
    /// - Parameter package: The package to purchase
    /// - Returns: `true` if purchase succeeded, `false` if user cancelled
    /// - Throws: Purchase errors from RevenueCat
    func purchase(_ package: SubscriptionPackage) async throws -> Bool {
        #if canImport(RevenueCat)
        guard await ensureSDKReady() else {
            throw PurchaseError.notConfigured
        }
        
        guard let rcPackage = package.rcPackage as? Package else {
            throw PurchaseError.invalidPackage
        }
        
        let result = try await Purchases.shared.purchase(package: rcPackage)
        
        if result.userCancelled {
            return false
        }
        
        // Update status after purchase (delegate will also be called)
        await refreshStatusIfNeeded(reason: .purchaseCompleted, force: true)
        return true
        #else
        throw PurchaseError.notConfigured
        #endif
    }
    
    // MARK: - Restore
    
    /// Restore previous purchases.
    ///
    /// - Returns: `true` if Pro entitlement was restored
    /// - Throws: Restore errors from RevenueCat
    func restorePurchases() async throws -> Bool {
        #if canImport(RevenueCat)
        guard await ensureSDKReady() else {
            throw PurchaseError.notConfigured
        }
        
        let customerInfo = try await Purchases.shared.restorePurchases()
        await handleCustomerInfoUpdate(customerInfo)
        lastStatusRefreshAt = Date()
        
        return isPro
        #else
        throw PurchaseError.notConfigured
        #endif
    }
    
    // MARK: - Helpers
    
    #if canImport(RevenueCat)
    private func ensureSDKReady() async -> Bool {
        guard StoreConfiguration.isConfigured else {
            return false
        }
        
        guard !isConfigured else {
            return true
        }
        
        isConfigured = true
        
        await MainActor.run {
            Purchases.shared.delegate = RevenueCatDelegateHandler.shared
        }
        
        debugLog("✅ RevenueCatManager ready (lazy fetch mode)")
        
        return true
    }
    
    private func minimumRefreshInterval(for reason: RefreshReason) -> TimeInterval {
        switch reason {
        case .purchaseCompleted, .restoreCompleted, .manual:
            return 0
        case .appBecameActive:
            return 30
        case .settingsOpened, .paywallPresented:
            return 10
        }
    }
    
    private func mapPackageType(_ rcType: PackageType) -> SubscriptionPackageType {
        switch rcType {
        case .monthly:
            return .monthly
        case .annual:
            return .annual
        case .lifetime:
            return .lifetime
        default:
            return .unknown
        }
    }
    #endif
}

// MARK: - RevenueCat Delegate Handler

#if canImport(RevenueCat)
/// Delegate handler for RevenueCat real-time updates.
///
/// This class bridges RevenueCat's delegate pattern to our actor-based manager.
/// It handles:
/// - Server-side subscription changes
/// - Family sharing updates
/// - External cancellations
final class RevenueCatDelegateHandler: NSObject, PurchasesDelegate {
    
    /// Shared instance.
    static let shared = RevenueCatDelegateHandler()
    
    private override init() {
        super.init()
    }
    
    /// Called when customer info is updated (subscription changes).
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        debugLog("🔔 RevenueCat delegate: Received customer info update")
        
        Task {
            await RevenueCatManager.shared.handleCustomerInfoUpdate(customerInfo)
        }
    }
}
#endif

// MARK: - Purchase Errors

/// Errors that can occur during purchase operations.
enum PurchaseError: Error, LocalizedError {
    /// RevenueCat is not configured
    case notConfigured
    
    /// Invalid package provided
    case invalidPackage
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Purchases are not configured. Please check your setup."
        case .invalidPackage:
            return "Invalid subscription package."
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension RevenueCatManager {
    /// Create a test instance that doesn't connect to RevenueCat.
    ///
    /// - Returns: A manager instance for testing
    static func createTestInstance() -> RevenueCatManager {
        RevenueCatManager()
    }
    
    /// Set Pro status for testing.
    func setTestProStatus(_ isPro: Bool) {
        self.isPro = isPro
        // No caching needed for test
    }
}
#endif
