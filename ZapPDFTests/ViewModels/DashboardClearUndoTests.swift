//
//  DashboardClearUndoTests.swift
//  ZapPDFTests
//
//  Unit tests for DashboardViewModel clear and undo functionality.
//

import Testing
import Foundation
import Combine
@testable import ZapPDF

@Suite("Dashboard Clear & Undo Tests")
struct DashboardClearUndoTests {
    
    // MARK: - Helper
    
    @MainActor
    private func createViewModel() -> DashboardViewModel {
        DashboardViewModel(usageManager: MockUsageManager())
    }
    
    // MARK: - Clear All Tests
    
    @Test("clearAll posts notification with correct user info")
    @MainActor
    func clearAllPostsNotification() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "clear_test")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        viewModel.selectFile(viewModel.files[0])
        
        // Capture initial state
        let expectedFiles = viewModel.files
        let expectedSelection = viewModel.selectedFileIDs
        
        // Expect notification
        await confirmation("Notification received", expectedCount: 1) { confirm in
            let cancellable = NotificationCenter.default.publisher(for: .filesCleared)
                .sink { notification in
                    guard let userInfo = notification.userInfo,
                          let files = userInfo["previousFiles"] as? [PDFFile],
                          let selection = userInfo["previousSelection"] as? Set<UUID> else {
                        Issue.record("Notification missing required user info")
                        return
                    }
                    
                    #expect(files.count == 1)
                    #expect(files[0].id == expectedFiles[0].id)
                    #expect(selection == expectedSelection)
                    confirm()
                }
            
            // Perform action
            viewModel.clearAll()
            
            // Cleanup subscription explicitly if needed, but 'cancellable' local scope handles it
            _ = cancellable
        }
    }
    
    @Test("clearAll clears files and selection")
    @MainActor
    func clearAllClearsState() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "clear_state")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        viewModel.selectFile(viewModel.files[0])
        
        viewModel.clearAll()
        
        #expect(viewModel.files.isEmpty)
        #expect(viewModel.selectedFileIDs.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }
    
    // MARK: - Restore Tests
    
    @Test("restoreFiles restores previous state")
    @MainActor
    func restoreFilesRestoresState() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "restore_test")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        let originalFile = viewModel.files[0]
        viewModel.selectFile(originalFile)
        
        // Capture state
        let filesToRestore = viewModel.files
        let selectionToRestore = viewModel.selectedFileIDs
        
        // Clear first
        viewModel.clearAll()
        #expect(viewModel.files.isEmpty)
        
        // Restore
        viewModel.restoreFiles(filesToRestore, selection: selectionToRestore)
        
        #expect(viewModel.files.count == 1)
        #expect(viewModel.files[0].id == originalFile.id)
        #expect(viewModel.selectedFileIDs.count == 1)
        #expect(viewModel.selectedFileIDs.contains(originalFile.id))
    }
}
