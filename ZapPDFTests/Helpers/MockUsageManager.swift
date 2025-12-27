
import Foundation
@testable import ZapPDF

actor MockUsageManager: UsageManaging {
    private var remaining: Int = 5
    private var isPro: Bool = false
    private var recordActionCalled: Bool = false
    private var shouldThrowError: Bool = false
    
    func setMockRemaining(_ amount: Int) {
        self.remaining = amount
    }
    
    func setProStatus(_ isPro: Bool) {
        self.isPro = isPro
    }
    
    func setShouldThrowError(_ shouldThrow: Bool) {
        self.shouldThrowError = shouldThrow
    }
    
    func canPerformAction() async -> Bool {
        if isPro { return true }
        return remaining > 0
    }
    
    func remainingActions() async -> Int {
        if isPro { return Int.max }
        return remaining
    }
    
    func recordAction() async throws {
        if shouldThrowError {
            throw UsageError.persistenceFailed(NSError(domain: "MockError", code: -1))
        }
        
        if isPro { return }
        
        guard remaining > 0 else {
            throw UsageError.noActionsRemaining
        }
        
        remaining -= 1
        recordActionCalled = true
    }
    
    func wasRecordActionCalled() -> Bool {
        return recordActionCalled
    }
    
    func resetUsage() async {
        remaining = 5
        recordActionCalled = false
    }
}
