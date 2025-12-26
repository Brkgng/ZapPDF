//
//  UsageManagerTests.swift
//  ZapPDFTests
//
//  Unit tests for UsageManager.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("UsageManager Tests")
struct UsageManagerTests {
    
    // MARK: - Helper
    
    /// Create a fresh in-memory UsageManager for testing
    private func createTestManager() -> UsageManager {
        UsageManager.createTestInstance()
    }
    
    // MARK: - Initial State Tests
    
    @Test("Initial actions equal free limit")
    func initialActionsEqualLimit() async {
        let manager = createTestManager()
        
        let remaining = await manager.remainingActions()
        
        #expect(remaining == manager.freeActionLimit)
        #expect(remaining == 5) // Default limit
    }
    
    @Test("Can perform action when actions remain")
    func canPerformActionWhenActionsRemain() async {
        let manager = createTestManager()
        
        let canPerform = await manager.canPerformAction()
        
        #expect(canPerform == true)
    }
    
    // MARK: - Record Action Tests
    
    @Test("Record action decrements count")
    func recordActionDecrementsCount() async throws {
        let manager = createTestManager()
        
        let initialRemaining = await manager.remainingActions()
        
        try await manager.recordAction()
        
        let afterRemaining = await manager.remainingActions()
        
        #expect(afterRemaining == initialRemaining - 1)
    }
    
    @Test("Record multiple actions decrements correctly")
    func recordMultipleActionsDecrementsCorrectly() async throws {
        let manager = createTestManager()
        
        try await manager.recordAction()
        try await manager.recordAction()
        try await manager.recordAction()
        
        let remaining = await manager.remainingActions()
        
        #expect(remaining == 2) // 5 - 3 = 2
    }
    
    @Test("Cannot perform action when exhausted")
    func cannotPerformWhenExhausted() async throws {
        let manager = createTestManager()
        
        // Exhaust all actions
        for _ in 0..<5 {
            try await manager.recordAction()
        }
        
        let canPerform = await manager.canPerformAction()
        
        #expect(canPerform == false)
    }
    
    @Test("Record throws when exhausted")
    func recordThrowsWhenExhausted() async throws {
        let manager = createTestManager()
        
        // Exhaust all actions
        for _ in 0..<5 {
            try await manager.recordAction()
        }
        
        // Next record should throw
        await #expect(throws: UsageError.self) {
            try await manager.recordAction()
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Persists across cache clear")
    func persistsAcrossCacheClear() async throws {
        let manager = createTestManager()
        
        // Record some actions
        try await manager.recordAction()
        try await manager.recordAction()
        
        // Clear cache to force reload from storage
        await manager.clearCache()
        
        // Should still have 3 remaining
        let remaining = await manager.remainingActions()
        
        #expect(remaining == 3) // 5 - 2 = 3
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset restores full limit")
    func resetRestoresFullLimit() async throws {
        let manager = createTestManager()
        
        // Exhaust some actions
        try await manager.recordAction()
        try await manager.recordAction()
        try await manager.recordAction()
        
        let beforeReset = await manager.remainingActions()
        #expect(beforeReset == 2)
        
        // Reset
        await manager.resetUsage()
        
        let afterReset = await manager.remainingActions()
        #expect(afterReset == 5)
    }
    
    @Test("Can perform action after reset")
    func canPerformAfterReset() async throws {
        let manager = createTestManager()
        
        // Exhaust all actions
        for _ in 0..<5 {
            try await manager.recordAction()
        }
        
        #expect(await manager.canPerformAction() == false)
        
        // Reset
        await manager.resetUsage()
        
        #expect(await manager.canPerformAction() == true)
    }
    
    // MARK: - Pro User Tests
    
    @Test("Pro users have unlimited actions")
    func proUsersUnlimited() async {
        let manager = createTestManager()
        
        // Set as Pro user
        await manager.setProStatus(true)
        
        let remaining = await manager.remainingActions()
        
        #expect(remaining == Int.max)
    }
    
    @Test("Pro users can always perform action")
    func proUsersCanAlwaysPerform() async throws {
        let manager = createTestManager()
        
        // Exhaust all free actions first
        for _ in 0..<5 {
            try await manager.recordAction()
        }
        
        #expect(await manager.canPerformAction() == false)
        
        // Upgrade to Pro
        await manager.setProStatus(true)
        
        #expect(await manager.canPerformAction() == true)
    }
    
    @Test("Pro users do not consume actions")
    func proUsersDoNotConsumeActions() async throws {
        let manager = createTestManager()
        
        // Set as Pro
        await manager.setProStatus(true)
        
        // Record actions (should be no-op)
        try await manager.recordAction()
        try await manager.recordAction()
        try await manager.recordAction()
        
        // Downgrade to free
        await manager.setProStatus(false)
        
        // Should still have all 5 actions
        let remaining = await manager.remainingActions()
        #expect(remaining == 5)
    }
    
    // MARK: - Custom Limit Tests
    
    @Test("Custom free action limit is respected")
    func customLimitRespected() async {
        let manager = UsageManager.createTestInstance(freeActionLimit: 10)
        
        let remaining = await manager.remainingActions()
        
        #expect(remaining == 10)
        #expect(manager.freeActionLimit == 10)
    }
    
    // MARK: - Sequential Access Tests
    
    @Test("Sequential actions decrement correctly")
    func sequentialActionsDecrement() async throws {
        let manager = createTestManager()
        
        // Record 5 actions sequentially
        for _ in 0..<5 {
            if await manager.canPerformAction() {
                try await manager.recordAction()
            }
        }
        
        let remaining = await manager.remainingActions()
        #expect(remaining == 0)
        #expect(await manager.canPerformAction() == false)
    }
}
