//
//  PaywallViewModel.swift
//  ZapPDF
//
//  ViewModel managing subscription state and purchase flow.
//

import Foundation
import Combine

// MARK: - Purchase State

/// State machine for purchase operations.
enum PurchaseState: Equatable {
    /// No purchase operation in progress.
    case idle
    
    /// Purchase is being processed.
    case purchasing
    
    /// Restore is being processed.
    case restoring
    
    /// Purchase/restore completed successfully.
    case success
    
    /// Purchase/restore failed with error message.
    case failed(message: String)
}

// MARK: - PaywallViewModel

/// ViewModel managing subscription state and purchase flow.
///
/// `PaywallViewModel` tracks the user's subscription status and
/// remaining free actions. It provides placeholder methods for
/// StoreKit/RevenueCat integration (implemented in Phase 7).
///
/// Example:
/// ```swift
/// @StateObject private var viewModel = PaywallViewModel()
///
/// await viewModel.loadState()
///
/// Text("Free actions remaining: \(viewModel.remainingFreeActions)")
///
/// Button("Upgrade to Pro") {
///     Task { await viewModel.purchase(productID: "pro_monthly") }
/// }
/// ```
@MainActor
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Whether the user has an active Pro subscription.
    @Published private(set) var isPro: Bool = false
    
    /// Number of free actions remaining.
    @Published private(set) var remainingFreeActions: Int = 0
    
    /// Current purchase/restore state.
    @Published private(set) var purchaseState: PurchaseState = .idle
    
    // MARK: - Dependencies
    
    private let usageManager: any UsageManaging
    
    // MARK: - Initialization
    
    /// Creates a PaywallViewModel with the default UsageManager.
    init() {
        self.usageManager = UsageManager.shared
    }
    
    /// Creates a PaywallViewModel with a custom UsageManager (for testing).
    init(usageManager: any UsageManaging) {
        self.usageManager = usageManager
    }
    
    // MARK: - Public Methods
    
    /// Load the current subscription and usage state.
    ///
    /// This should be called when the paywall appears.
    func loadState() async {
        remainingFreeActions = await usageManager.remainingActions()
        
        // TODO: Check isPro via RevenueCat in Phase 7
        // isPro = await RevenueCatManager.shared.isPro
    }
    
    /// Attempt to purchase a product.
    ///
    /// - Parameter productID: The product identifier to purchase
    ///
    /// - Note: This is a placeholder for RevenueCat/StoreKit integration.
    func purchase(productID: String) async {
        purchaseState = .purchasing
        
        // TODO: Implement actual purchase via RevenueCat in Phase 7
        // For now, simulate a purchase flow
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            // Update UsageManager (this will post notification to all subscribers)
            await usageManager.setProStatus(true)
            
            // Update local state
            isPro = true
            purchaseState = .success
            
        } catch {
            purchaseState = .failed(message: "Purchase failed. Please try again.")
        }
    }
    
    /// Restore previous purchases.
    ///
    /// - Note: This is a placeholder for RevenueCat/StoreKit integration.
    func restorePurchases() async {
        purchaseState = .restoring
        
        // TODO: Implement actual restore via RevenueCat in Phase 7
        // For now, simulate a restore flow
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            // Simulate checking for existing purchases
            // In Phase 7, this will call RevenueCat.restorePurchases()
            // For now, assume no previous purchases
            purchaseState = .idle
            
        } catch {
            purchaseState = .failed(message: "Restore failed. Please try again.")
        }
    }
    
    /// Reset purchase state to idle.
    func resetPurchaseState() {
        purchaseState = .idle
    }
    
    // MARK: - Computed Properties
    
    /// Whether there are any free actions remaining.
    var hasFreeActionsRemaining: Bool {
        remainingFreeActions > 0
    }
    
    /// Description of remaining free actions.
    var remainingActionsText: String {
        if remainingFreeActions == 0 {
            return "No free actions remaining"
        } else if remainingFreeActions == 1 {
            return "1 free action remaining"
        } else {
            return "\(remainingFreeActions) free actions remaining"
        }
    }
}
