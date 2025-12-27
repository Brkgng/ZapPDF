//
//  DashboardViewModelTests.swift
//  ZapPDFTests
//
//  Unit tests for DashboardViewModel.
//

import Testing
import Foundation
@testable import ZapPDF



@Suite("DashboardViewModel Tests")
struct DashboardViewModelTests {
    
    // MARK: - Helper
    
    @MainActor
    private func createViewModel(usageManager: MockUsageManager = MockUsageManager()) -> DashboardViewModel {
        DashboardViewModel(usageManager: usageManager)
    }
    
    // MARK: - Initial State Tests
    
    @Test("Initial state has no files")
    @MainActor
    func initialStateHasNoFiles() async {
        let viewModel = createViewModel()
        
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasFiles == false)
    }
    
    // MARK: - File Management Tests
    
    @Test("Adding files from URLs creates PDFFile instances")
    @MainActor
    func addFilesFromURLs() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "dashboard_add")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.selectedFiles.first?.fileName == testURL.lastPathComponent)
        #expect(viewModel.hasFiles == true)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Adding multiple files works correctly")
    @MainActor
    func addMultipleFiles() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3, 4])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        #expect(viewModel.selectedFiles.count == 3)
        #expect(viewModel.totalPageCount == 9) // 2 + 3 + 4
    }
    
    @Test("Remove file updates selection")
    @MainActor
    func removeFileUpdatesSelection() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        let firstFile = viewModel.selectedFiles[0]
        viewModel.removeFile(firstFile)
        
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.selectedFiles.first?.fileName != firstFile.fileName)
    }
    
    @Test("Reorder files preserves all files")
    @MainActor
    func reorderFilesPreservesAll() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [1, 2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        let originalFirst = viewModel.selectedFiles[0]
        
        // Move first to last position
        viewModel.reorderFiles(from: IndexSet(integer: 0), to: 3)
        
        #expect(viewModel.selectedFiles.count == 3)
        #expect(viewModel.selectedFiles.last?.id == originalFirst.id)
    }
    
    @Test("Clear all resets state")
    @MainActor
    func clearAllResetsState() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 2)
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        viewModel.clearAll()
        
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.hasFiles == false)
    }
    
    // MARK: - Action Validation Tests
    
    @Test("Can perform merge requires two files")
    @MainActor
    func canPerformMergeRequiresTwoFiles() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 2)
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        // No files
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // One file
        await viewModel.addFiles(urls: [testURL])
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // Two files
        let secondURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "second")
        defer { PDFTestHelpers.cleanup(url: secondURL) }
        
        await viewModel.addFiles(urls: [secondURL])
        #expect(viewModel.canPerform(action: .merge) == true)
    }
    
    @Test("Can perform split requires exactly one file")
    @MainActor
    func canPerformSplitRequiresOneFile() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [3, 4])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        // No files
        #expect(viewModel.canPerform(action: .split) == false)
        
        // One file - valid
        await viewModel.addFiles(urls: [urls[0]])
        #expect(viewModel.canPerform(action: .split) == true)
        
        // Two files - invalid for split
        await viewModel.addFiles(urls: [urls[1]])
        #expect(viewModel.canPerform(action: .split) == false)
    }
    
    // MARK: - Paywall Tests
    
    @Test("Should show paywall when exhausted")
    @MainActor
    func shouldShowPaywallWhenExhausted() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(0)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        let shouldShow = await viewModel.shouldShowPaywall()
        
        #expect(shouldShow == true)
    }
    
    @Test("Should not show paywall when actions remain")
    @MainActor
    func shouldNotShowPaywallWhenActionsRemain() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(5)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        let shouldShow = await viewModel.shouldShowPaywall()
        
        #expect(shouldShow == false)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Adding invalid URL shows error")
    @MainActor
    func addingInvalidURLShowsError() async {
        let viewModel = createViewModel()
        
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        
        await viewModel.addFiles(urls: [invalidURL])
        
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.selectedFiles.isEmpty)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Total page count is calculated correctly")
    @MainActor
    func totalPageCountCalculated() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [5, 10, 15])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        #expect(viewModel.totalPageCount == 30)
    }
}
