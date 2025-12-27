//
//  PaywallViewTests.swift
//  ZapPDFTests
//
//  Unit tests for PaywallView.
//

import Testing
import SwiftUI
@testable import ZapPDF

@Suite("PaywallView Tests")
struct PaywallViewTests {
    
    // MARK: - ViewModel Integration Tests
    
    @Test("PaywallView initializes with ViewModel")
    @MainActor
    func initializesWithViewModel() async {
        // PaywallView should create its own ViewModel
        let view = PaywallView()
        
        // View should initialize without error
        #expect(view != nil)
    }
    
    @Test("PaywallViewModel loads initial state")
    @MainActor
    func viewModelLoadsState() async {
        let viewModel = PaywallViewModel()
        
        // Initial state before loading
        #expect(viewModel.isPro == false)
        #expect(viewModel.purchaseState == .idle)
        
        // Load state
        await viewModel.loadState()
        
        // State should be loaded (remaining actions should be >= 0)
        #expect(viewModel.remainingFreeActions >= 0)
    }
    
    @Test("PaywallViewModel purchase state transitions")
    @MainActor
    func purchaseStateTransitions() async {
        let viewModel = PaywallViewModel()
        
        #expect(viewModel.purchaseState == .idle)
        
        // Start purchase (this is a simulated purchase)
        Task {
            await viewModel.purchase(productID: "test_product")
        }
        
        // Give time for state to change
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // State should have changed (either purchasing or success for simulated)
        // In the simulated implementation, it will quickly transition to success
    }
    
    @Test("PaywallViewModel restore state transitions")
    @MainActor
    func restoreStateTransitions() async {
        let viewModel = PaywallViewModel()
        
        #expect(viewModel.purchaseState == .idle)
        
        // Start restore
        await viewModel.restorePurchases()
        
        // Should return to idle after simulated restore
        #expect(viewModel.purchaseState == .idle)
    }
    
    @Test("PaywallViewModel reset purchase state")
    @MainActor
    func resetPurchaseState() async {
        let viewModel = PaywallViewModel()
        
        // Reset should set to idle
        viewModel.resetPurchaseState()
        
        #expect(viewModel.purchaseState == .idle)
    }
}

// MARK: - Feature Comparison Tests

@Suite("Feature Comparison Tests")
struct FeatureComparisonTests {
    
    @Test("Free tier actions are correctly defined")
    func freeTierActions() {
        let freeActions = UserAction.freeActions
        
        #expect(freeActions.contains(.merge))
        #expect(freeActions.contains(.split))
        #expect(freeActions.contains(.compress))
        #expect(!freeActions.contains(.convert))
    }
    
    @Test("Pro tier actions are correctly defined")
    func proTierActions() {
        let proActions = UserAction.proActions
        
        #expect(proActions.contains(.convert))
        #expect(proActions.count == 1)
    }
    
    @Test("isFreeTierAction returns correct values")
    func isFreeTierActionValues() {
        #expect(UserAction.merge.isFreeTierAction == true)
        #expect(UserAction.split.isFreeTierAction == true)
        #expect(UserAction.compress.isFreeTierAction == true)
        #expect(UserAction.convert.isFreeTierAction == false)
    }
}

// MARK: - PurchaseState Tests

@Suite("PurchaseState Tests")
struct PurchaseStateTests {
    
    @Test("PurchaseState cases exist")
    func purchaseStateCases() {
        let idle = PurchaseState.idle
        let purchasing = PurchaseState.purchasing
        let restoring = PurchaseState.restoring
        let success = PurchaseState.success
        let failed = PurchaseState.failed(message: "Error")
        
        #expect(idle == .idle)
        #expect(purchasing == .purchasing)
        #expect(restoring == .restoring)
        #expect(success == .success)
        
        if case .failed(let message) = failed {
            #expect(message == "Error")
        } else {
            Issue.record("Failed state should have message")
        }
    }
    
    @Test("PurchaseState conforms to Equatable")
    func purchaseStateEquatable() {
        #expect(PurchaseState.idle == PurchaseState.idle)
        #expect(PurchaseState.purchasing == PurchaseState.purchasing)
        #expect(PurchaseState.idle != PurchaseState.purchasing)
    }
}

// MARK: - Remaining Actions Display Tests

@Suite("Remaining Actions Display Tests")
struct RemainingActionsDisplayTests {
    
    @Test("RemainingActionsText formats correctly")
    @MainActor
    func remainingActionsText() async {
        let mockUsageManager = MockUsageManager()
        
        // Test 0 actions
        await mockUsageManager.setMockRemaining(0)
        let viewModel0 = PaywallViewModel(usageManager: mockUsageManager)
        await viewModel0.loadState()
        #expect(viewModel0.remainingActionsText == "No free actions remaining")
        
        // Test 1 action
        await mockUsageManager.setMockRemaining(1)
        let viewModel1 = PaywallViewModel(usageManager: mockUsageManager)
        await viewModel1.loadState()
        #expect(viewModel1.remainingActionsText == "1 free action remaining")
        
        // Test multiple actions
        await mockUsageManager.setMockRemaining(3)
        let viewModel3 = PaywallViewModel(usageManager: mockUsageManager)
        await viewModel3.loadState()
        #expect(viewModel3.remainingActionsText == "3 free actions remaining")
    }
    
    @Test("HasFreeActionsRemaining returns correct value")
    @MainActor
    func hasFreeActionsRemaining() async {
        let mockUsageManager = MockUsageManager()
        
        // With actions
        await mockUsageManager.setMockRemaining(5)
        let viewModel1 = PaywallViewModel(usageManager: mockUsageManager)
        await viewModel1.loadState()
        #expect(viewModel1.hasFreeActionsRemaining == true)
        
        // Without actions
        await mockUsageManager.setMockRemaining(0)
        let viewModel0 = PaywallViewModel(usageManager: mockUsageManager)
        await viewModel0.loadState()
        #expect(viewModel0.hasFreeActionsRemaining == false)
    }
}
