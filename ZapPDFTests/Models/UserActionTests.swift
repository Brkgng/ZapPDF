//
//  UserActionTests.swift
//  ZapPDFTests
//
//  Unit tests for UserAction enum.
//

import Testing
@testable import ZapPDF

@Suite("UserAction Tests")
struct UserActionTests {
    
    // MARK: - Display Properties
    
    @Test("Display names are human readable")
    func displayNamesAreHumanReadable() {
        #expect(UserAction.merge.displayName == "Merge PDFs")
        #expect(UserAction.split.displayName == "Split PDF")
        #expect(UserAction.convert.displayName == "Convert PDF")
    }
    
    @Test("Icon names are valid SF Symbols")
    func iconNamesAreValid() {
        #expect(UserAction.merge.iconName == "doc.on.doc")
        #expect(UserAction.split.iconName == "scissors")
        #expect(UserAction.convert.iconName == "arrow.triangle.2.circlepath")
    }
    
    @Test("Descriptions are not empty")
    func descriptionsAreNotEmpty() {
        for action in UserAction.allCases {
            #expect(!action.description.isEmpty)
        }
    }
    
    // MARK: - File Requirements
    
    @Test("Merge requires multiple files")
    func mergeRequiresMultipleFiles() {
        #expect(UserAction.merge.requiresMultipleFiles == true)
        #expect(UserAction.merge.minimumFileCount == 2)
        #expect(UserAction.merge.maximumFileCount == nil)
    }
    
    @Test("Split requires single file")
    func splitRequiresSingleFile() {
        #expect(UserAction.split.requiresMultipleFiles == false)
        #expect(UserAction.split.minimumFileCount == 1)
        #expect(UserAction.split.maximumFileCount == 1)
    }
    
    @Test("Convert requires single file")
    func convertRequiresSingleFile() {
        #expect(UserAction.convert.requiresMultipleFiles == false)
        #expect(UserAction.convert.minimumFileCount == 1)
        #expect(UserAction.convert.maximumFileCount == 1)
    }
    
    // MARK: - Validation
    
    @Test("isValidFileCount for merge action")
    func isValidFileCountForMerge() {
        #expect(UserAction.merge.isValidFileCount(0) == false)
        #expect(UserAction.merge.isValidFileCount(1) == false)
        #expect(UserAction.merge.isValidFileCount(2) == true)
        #expect(UserAction.merge.isValidFileCount(10) == true)
        #expect(UserAction.merge.isValidFileCount(100) == true)
    }
    
    @Test("isValidFileCount for single file actions")
    func isValidFileCountForSingleFileActions() {
        let singleFileActions: [UserAction] = [.split, .convert]
        
        for action in singleFileActions {
            #expect(action.isValidFileCount(0) == false)
            #expect(action.isValidFileCount(1) == true)
            #expect(action.isValidFileCount(2) == false)
        }
    }
    
    @Test("fileCountError returns appropriate messages")
    func fileCountErrorReturnsAppropriateMessages() {
        // Merge with insufficient files
        #expect(UserAction.merge.fileCountError(for: 0) != nil)
        #expect(UserAction.merge.fileCountError(for: 1) != nil)
        #expect(UserAction.merge.fileCountError(for: 2) == nil)
        
        // Single file actions with too many files
        #expect(UserAction.split.fileCountError(for: 0) != nil)
        #expect(UserAction.split.fileCountError(for: 1) == nil)
        #expect(UserAction.split.fileCountError(for: 2) != nil)
    }
    
    // MARK: - Identifiable
    
    @Test("All actions have unique IDs")
    func allActionsHaveUniqueIDs() {
        let ids = UserAction.allCases.map { $0.id }
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }
    
    // MARK: - CaseIterable
    
    @Test("All cases are iterable")
    func allCasesAreIterable() {
        #expect(UserAction.allCases.count == 3)
        #expect(UserAction.allCases.contains(.merge))
        #expect(UserAction.allCases.contains(.split))
        #expect(UserAction.allCases.contains(.convert))
    }
    
    // MARK: - Free Tier
    
    @Test("Free tier actions are correct")
    func freeTierActionsAreCorrect() {
        #expect(UserAction.freeActions.count == 2)
        #expect(UserAction.freeActions.contains(.merge))
        #expect(UserAction.freeActions.contains(.split))
        #expect(!UserAction.freeActions.contains(.convert))
    }
    
    @Test("isFreeTierAction returns correct value")
    func isFreeTierActionReturnsCorrectValue() {
        #expect(UserAction.merge.isFreeTierAction == true)
        #expect(UserAction.split.isFreeTierAction == true)
        #expect(UserAction.convert.isFreeTierAction == false)
    }
}

