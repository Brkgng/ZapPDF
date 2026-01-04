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
        #expect(viewModel.files.isEmpty)
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
        
        #expect(viewModel.files.count == 1)
        #expect(viewModel.files.first?.fileName == testURL.lastPathComponent)
        #expect(viewModel.hasFiles == true)
        #expect(viewModel.isLoading == false)
        // Verify default is NOT selected
        #expect(viewModel.selectedFiles.isEmpty)
    }
    
    @Test("Adding multiple files works correctly")
    @MainActor
    func addMultipleFiles() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3, 4])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        #expect(viewModel.files.count == 3)
        #expect(viewModel.totalPageCount == 9) // 2 + 3 + 4
    }
    
    @Test("Remove file updates selection")
    @MainActor
    func removeFileUpdatesSelection() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        // Select first file
        let firstFile = viewModel.files[0]
        viewModel.selectFile(firstFile)
        
        #expect(viewModel.selectedFiles.count == 1)
        
        viewModel.removeFile(firstFile)
        
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.files.count == 1)
    }
    
    @Test("Reorder files preserves all files")
    @MainActor
    func reorderFilesPreservesAll() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [1, 2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        let originalFirst = viewModel.files[0]
        
        // Move first to last position
        viewModel.reorderFiles(from: IndexSet(integer: 0), to: 3)
        
        #expect(viewModel.files.count == 3)
        #expect(viewModel.files.last?.id == originalFirst.id)
    }
    
    @Test("Clear all resets state")
    @MainActor
    func clearAllResetsState() async throws {
        let viewModel = createViewModel()
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 2)
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        viewModel.selectFile(viewModel.files[0])
        
        viewModel.clearAll()
        
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.files.isEmpty)
        #expect(viewModel.hasFiles == false)
    }
    
    // MARK: - Selection Tests
    
    @Test("Selection methods work correctly")
    @MainActor
    func selectionMethodsWork() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [1, 1])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        let file1 = viewModel.files[0]
        let file2 = viewModel.files[1]
        
        // Test select
        viewModel.selectFile(file1)
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(file1))
        #expect(!viewModel.isSelected(file2))
        
        // Test toggle
        viewModel.toggleSelection(for: file1)
        #expect(viewModel.selectedFiles.isEmpty)
        
        viewModel.toggleSelection(for: file2)
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(file2))
        
        // Test select all
        viewModel.selectAll()
        #expect(viewModel.selectedFiles.count == 2)
        #expect(viewModel.allSelected)
        
        // Test deselect all
        viewModel.deselectAll()
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.noneSelected)
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
        
        // Should default to true if NO files are selected (fallback behavior)
        #expect(viewModel.canPerform(action: .merge) == true)
        
        // If we select just 1, it should fail
        viewModel.selectFile(viewModel.files[0])
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // If we select both, it should pass
        viewModel.selectAll()
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
        
        // One file added (none selected) -> Split requires selection
        await viewModel.addFiles(urls: [urls[0]])
        #expect(viewModel.canPerform(action: .split) == false)
        
        // Select one file -> Valid
        viewModel.selectFile(viewModel.files[0])
        #expect(viewModel.canPerform(action: .split) == true)
        
        // Two files selected -> Invalid
        await viewModel.addFiles(urls: [urls[1]])
        viewModel.selectAll()
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
        #expect(viewModel.files.isEmpty)
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
    
    // MARK: - Subscription State Tests
    
    @Test("loadSubscriptionState updates isPro and remainingFreeActions")
    @MainActor
    func loadSubscriptionStateUpdatesState() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(3)
        await mockUsageManager.setProStatus(false)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        // Initially uses defaults
        #expect(viewModel.isPro == false)
        #expect(viewModel.remainingFreeActions == 5) // Default value
        
        // Load state
        await viewModel.loadSubscriptionState()
        
        #expect(viewModel.isPro == false)
        #expect(viewModel.remainingFreeActions == 3)
    }
    
    @Test("loadSubscriptionState reflects Pro status")
    @MainActor
    func loadSubscriptionStateReflectsProStatus() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setProStatus(true)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        
        await viewModel.loadSubscriptionState()
        
        #expect(viewModel.isPro == true)
        #expect(viewModel.remainingFreeActions == Int.max)
    }
    
    @Test("refreshUsageState updates remainingFreeActions")
    @MainActor
    func refreshUsageStateUpdatesRemaining() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(5)
        
        let viewModel = createViewModel(usageManager: mockUsageManager)
        await viewModel.loadSubscriptionState()
        
        #expect(viewModel.remainingFreeActions == 5)
        
        // Simulate action consumption
        try await mockUsageManager.recordAction()
        await viewModel.refreshUsageState()
        
        #expect(viewModel.remainingFreeActions == 4)
    }
    
    @Test("freeActionLimit is constant at 5")
    @MainActor
    func freeActionLimitIsConstant() async {
        let viewModel = createViewModel()
        
        #expect(viewModel.freeActionLimit == 5)
    }
    
    // MARK: - Notification Integration Tests
    
    @Test("Usage change triggers automatic update via notification")
    @MainActor
    func usageChangeTriggersAutomaticUpdate() async throws {
        // Create real UsageManager test instance (not mock) because it posts notifications
        let usageManager = UsageManager.createTestInstance()
        
        // Create ViewModel with the real UsageManager
        let viewModel = DashboardViewModel(usageManager: usageManager)
        
        // Load initial state
        await viewModel.loadSubscriptionState()
        let initialRemaining = viewModel.remainingFreeActions
        #expect(initialRemaining == 5)
        
        // Record an action - this should post a notification
        // that the DashboardViewModel's subscription will receive
        try await usageManager.recordAction()
        
        // Wait briefly for the notification to be delivered and processed
        // (the notification is posted on MainActor.run)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify that the ViewModel auto-updated without manual refresh call
        #expect(viewModel.remainingFreeActions == 4)
    }
    
    @Test("Pro status change triggers automatic update via notification")
    @MainActor
    func proStatusChangeTriggersAutomaticUpdate() async throws {
        // Create real UsageManager test instance
        let usageManager = UsageManager.createTestInstance()
        
        // Create ViewModel
        let viewModel = DashboardViewModel(usageManager: usageManager)
        
        // Load initial state
        await viewModel.loadSubscriptionState()
        #expect(viewModel.isPro == false)
        
        // Change Pro status - this should post a notification
        await usageManager.setProStatus(true)
        
        // Wait briefly for notification delivery
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify that the ViewModel auto-updated
        #expect(viewModel.isPro == true)
    }
}
