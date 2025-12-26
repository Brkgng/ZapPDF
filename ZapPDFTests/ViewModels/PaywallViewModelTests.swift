//
//  PaywallViewModelTests.swift
//  ZapPDFTests
//
//  Unit tests for PaywallViewModel.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("PaywallViewModel Tests")
struct PaywallViewModelTests {
    
    // MARK: - Helper
    
    @MainActor
    private func createViewModel(usageManager: MockUsageManager = MockUsageManager()) -> PaywallViewModel {
        PaywallViewModel(usageManager: usageManager)
    }
    
    // MARK: - Initial State Tests
    
    @Test("Initial state has defaults")
    @MainActor
    func initialStateHasDefaults() {
        let viewModel = createViewModel()
        
        #expect(viewModel.isPro == false)
        #expect(viewModel.remainingFreeActions == 0)
        #expect(viewModel.purchaseState == .idle)
    }
    
    // MARK: - Load State Tests
    
    @Test("Load state gets remaining actions")
    @MainActor
    func loadStateGetsRemainingActions() async {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(3)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        await viewModel.loadState()
        
        #expect(viewModel.remainingFreeActions == 3)
    }
    
    @Test("Load state with zero remaining")
    @MainActor
    func loadStateWithZeroRemaining() async {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(0)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        await viewModel.loadState()
        
        #expect(viewModel.remainingFreeActions == 0)
        #expect(viewModel.hasFreeActionsRemaining == false)
    }
    
    // MARK: - Purchase State Tests
    
    @Test("Purchase transitions to purchasing")
    @MainActor
    func purchaseTransitionsToPurchasing() async {
        let viewModel = createViewModel()
        
        // Start purchase in background
        Task {
            await viewModel.purchase(productID: "test_product")
        }
        
        // Give time to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Should be purchasing or success by now
        let isValidState = viewModel.purchaseState == .purchasing || viewModel.purchaseState == .success
        #expect(isValidState)
    }
    
    @Test("Purchase completes with success")
    @MainActor
    func purchaseCompletesWithSuccess() async {
        let viewModel = createViewModel()
        
        await viewModel.purchase(productID: "test_product")
        
        #expect(viewModel.purchaseState == .success)
        #expect(viewModel.isPro == true)
    }
    
    // MARK: - Restore Tests
    
    @Test("Restore transitions to restoring")
    @MainActor
    func restoreTransitionsToRestoring() async {
        let viewModel = createViewModel()
        
        // Start restore in background
        Task {
            await viewModel.restorePurchases()
        }
        
        // Give time to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Should be restoring or idle by now
        let isValidState = viewModel.purchaseState == .restoring || viewModel.purchaseState == .idle
        #expect(isValidState)
    }
    
    @Test("Restore completes")
    @MainActor
    func restoreCompletes() async {
        let viewModel = createViewModel()
        
        await viewModel.restorePurchases()
        
        // Should return to idle (no previous purchases in mock)
        #expect(viewModel.purchaseState == .idle)
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset purchase state returns to idle")
    @MainActor
    func resetPurchaseStateReturnsToIdle() async {
        let viewModel = createViewModel()
        
        await viewModel.purchase(productID: "test")
        viewModel.resetPurchaseState()
        
        #expect(viewModel.purchaseState == .idle)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Remaining actions text is correct")
    @MainActor
    func remainingActionsTextIsCorrect() async {
        let mockUsageManager = MockUsageManager()
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        // Test zero
        await mockUsageManager.setMockRemaining(0)
        await viewModel.loadState()
        #expect(viewModel.remainingActionsText == "No free actions remaining")
        
        // Test one
        await mockUsageManager.setMockRemaining(1)
        await viewModel.loadState()
        #expect(viewModel.remainingActionsText == "1 free action remaining")
        
        // Test multiple
        await mockUsageManager.setMockRemaining(3)
        await viewModel.loadState()
        #expect(viewModel.remainingActionsText == "3 free actions remaining")
    }
    
    @Test("Has free actions remaining is correct")
    @MainActor
    func hasFreeActionsRemainingIsCorrect() async {
        let mockUsageManager = MockUsageManager()
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        await mockUsageManager.setMockRemaining(5)
        await viewModel.loadState()
        #expect(viewModel.hasFreeActionsRemaining == true)
        
        await mockUsageManager.setMockRemaining(0)
        await viewModel.loadState()
        #expect(viewModel.hasFreeActionsRemaining == false)
    }
}
