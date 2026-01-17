import Testing
import Foundation
@testable import ZapPDF

@Suite("UsageManager Persistence Tests")
struct UsageManagerPersistenceTests {
    
    // Legacy key
    private let kLegacyCachedIsProKey = "com.zappdf.cached.isPro"
    
    @Test("Migration from UserDefaults to Keychain")
    func testMigration() throws {
        // 1. Setup Legacy State
        UserDefaults.standard.set(true, forKey: kLegacyCachedIsProKey)
        
        // 2. Clear Keychain (to ensure migration triggers)
        try? KeychainHelper.delete(for: .proStatus)
        
        // 3. Trigger Migration
        let status = UsageManager.loadCachedProStatus()
        
        // 4. Verify
        #expect(status == true)
        
        // Verify UserDefaults is cleared
        let legacyValue = UserDefaults.standard.value(forKey: kLegacyCachedIsProKey)
        #expect(legacyValue == nil)
        
        // Verify Keychain has value
        let keychainValue = try KeychainHelper.loadBool(for: .proStatus)
        #expect(keychainValue == true)
        
        // Cleanup
        try? KeychainHelper.delete(for: .proStatus)
    }
    
    @Test("Loads from Keychain when present")
    func testLoadsFromKeychain() throws {
        // 1. Setup Keychain State
        try KeychainHelper.saveBool(true, for: .proStatus)
        
        // 2. Load
        let status = UsageManager.loadCachedProStatus()
        
        // 3. Verify
        #expect(status == true)
        
        // Cleanup
        try? KeychainHelper.delete(for: .proStatus)
    }
    
    @Test("Returns false cleanly when no data")
    func testReturnsFalseWhenEmpty() throws {
        // 1. Ensure clean slate
        UserDefaults.standard.removeObject(forKey: kLegacyCachedIsProKey)
        try? KeychainHelper.delete(for: .proStatus)
        
        // 2. Load
        let status = UsageManager.loadCachedProStatus()
        
        // 3. Verify
        #expect(status == false)
    }
}
