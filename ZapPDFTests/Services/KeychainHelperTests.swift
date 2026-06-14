//
//  KeychainHelperTests.swift
//  ZapPDFTests
//
//  Unit tests for KeychainHelper.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("KeychainHelper Tests", .serialized)
struct KeychainHelperTests {
    
    // MARK: - Setup/Teardown
    
    /// Clean up test keys before/after each test
    private func cleanup() {
        try? KeychainHelper.delete(for: .keychainHelperTestPrimary)
        try? KeychainHelper.delete(for: .keychainHelperTestSecondary)
    }
    
    // MARK: - Save and Load Tests
    
    @Test("Save and load data successfully")
    func saveAndLoadData() throws {
        cleanup()
        defer { cleanup() }
        
        let testData = Data("test_secret_data".utf8)
        
        // Save
        try KeychainHelper.save(testData, for: .keychainHelperTestPrimary)
        
        // Load
        let loaded = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        
        #expect(loaded == testData)
    }
    
    @Test("Load non-existent key returns nil")
    func loadNonExistentKey() throws {
        cleanup()
        
        let loaded = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        
        #expect(loaded == nil)
    }
    
    @Test("Overwrite existing item updates value")
    func overwriteExistingItem() throws {
        cleanup()
        defer { cleanup() }
        
        let firstData = Data("first_value".utf8)
        let secondData = Data("second_value".utf8)
        
        // Save first value
        try KeychainHelper.save(firstData, for: .keychainHelperTestPrimary)
        
        // Overwrite with second value
        try KeychainHelper.save(secondData, for: .keychainHelperTestPrimary)
        
        // Load should return second value
        let loaded = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        
        #expect(loaded == secondData)
    }
    
    // MARK: - Delete Tests
    
    @Test("Delete existing item removes it")
    func deleteExistingItem() throws {
        cleanup()
        
        let testData = Data("to_be_deleted".utf8)
        
        // Save
        try KeychainHelper.save(testData, for: .keychainHelperTestPrimary)
        
        // Verify it exists
        #expect(KeychainHelper.exists(for: .keychainHelperTestPrimary) == true)
        
        // Delete
        try KeychainHelper.delete(for: .keychainHelperTestPrimary)
        
        // Verify it's gone
        let loaded = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        #expect(loaded == nil)
    }
    
    @Test("Delete non-existent item does not throw")
    func deleteNonExistentItem() throws {
        cleanup()
        
        // Should not throw
        try KeychainHelper.delete(for: .keychainHelperTestPrimary)
    }
    
    // MARK: - Exists Tests
    
    @Test("Exists returns true for saved items")
    func existsReturnsTrue() throws {
        cleanup()
        defer { cleanup() }
        
        let testData = Data("exists_test".utf8)
        
        try KeychainHelper.save(testData, for: .keychainHelperTestPrimary)
        
        #expect(KeychainHelper.exists(for: .keychainHelperTestPrimary) == true)
    }
    
    @Test("Exists returns false for missing items")
    func existsReturnsFalse() {
        cleanup()
        
        #expect(KeychainHelper.exists(for: .keychainHelperTestPrimary) == false)
    }
    
    // MARK: - Integer Convenience Tests
    
    @Test("Save and load integer value")
    func saveAndLoadInt() throws {
        cleanup()
        defer { cleanup() }
        
        let testValue = 42
        
        // Save
        try KeychainHelper.saveInt(testValue, for: .keychainHelperTestPrimary)
        
        // Load
        let loaded = try KeychainHelper.loadInt(for: .keychainHelperTestPrimary)
        
        #expect(loaded == testValue)
    }
    
    @Test("Load integer from non-existent key returns nil")
    func loadIntNonExistent() throws {
        cleanup()
        
        let loaded = try KeychainHelper.loadInt(for: .keychainHelperTestPrimary)
        
        #expect(loaded == nil)
    }
    
    @Test("Save and load zero integer")
    func saveAndLoadZeroInt() throws {
        cleanup()
        defer { cleanup() }
        
        let testValue = 0
        
        try KeychainHelper.saveInt(testValue, for: .keychainHelperTestPrimary)
        
        let loaded = try KeychainHelper.loadInt(for: .keychainHelperTestPrimary)
        
        #expect(loaded == testValue)
    }
    
    @Test("Save and load negative integer")
    func saveAndLoadNegativeInt() throws {
        cleanup()
        defer { cleanup() }
        
        let testValue = -5
        
        try KeychainHelper.saveInt(testValue, for: .keychainHelperTestPrimary)
        
        let loaded = try KeychainHelper.loadInt(for: .keychainHelperTestPrimary)
        
        #expect(loaded == testValue)
    }
    
    @Test("Save and load large integer")
    func saveAndLoadLargeInt() throws {
        cleanup()
        defer { cleanup() }
        
        let testValue = Int.max
        
        try KeychainHelper.saveInt(testValue, for: .keychainHelperTestPrimary)
        
        let loaded = try KeychainHelper.loadInt(for: .keychainHelperTestPrimary)
        
        #expect(loaded == testValue)
    }
    
    // MARK: - Multiple Keys Tests
    
    @Test("Multiple keys stored independently")
    func multipleKeysIndependent() throws {
        cleanup()
        defer { cleanup() }
        
        let data1 = Data("value_for_key_1".utf8)
        let data2 = Data("value_for_key_2".utf8)
        
        try KeychainHelper.save(data1, for: .keychainHelperTestPrimary)
        try KeychainHelper.save(data2, for: .keychainHelperTestSecondary)
        
        let loaded1 = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        let loaded2 = try KeychainHelper.load(for: .keychainHelperTestSecondary)
        
        #expect(loaded1 == data1)
        #expect(loaded2 == data2)
        
        // Delete one, other should remain
        try KeychainHelper.delete(for: .keychainHelperTestPrimary)
        
        let afterDelete1 = try KeychainHelper.load(for: .keychainHelperTestPrimary)
        let afterDelete2 = try KeychainHelper.load(for: .keychainHelperTestSecondary)
        
        #expect(afterDelete1 == nil)
        #expect(afterDelete2 == data2)
    }
}
