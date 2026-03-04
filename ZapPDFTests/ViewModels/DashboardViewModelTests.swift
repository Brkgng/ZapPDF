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
        // Verify auto-selection for single file added to empty dashboard
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(viewModel.files[0]))
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
        
        // One file (auto-selected due to empty dashboard)
        await viewModel.addFiles(urls: [testURL])
        // With 1 file selected, merge should still fail (need 2+)
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // Two files - add second file (not auto-selected since dashboard not empty)
        let secondURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "second")
        defer { PDFTestHelpers.cleanup(url: secondURL) }
        
        await viewModel.addFiles(urls: [secondURL])
        
        // First file is still selected, second is not - merge fails with just 1 selected
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // If we select both, it should pass
        viewModel.selectAll()
        #expect(viewModel.canPerform(action: .merge) == true)
        
        // Deselect all - fallback to all files for merge
        viewModel.deselectAll()
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
        
        // One file added to empty dashboard -> auto-selected -> Split works immediately
        await viewModel.addFiles(urls: [urls[0]])
        #expect(viewModel.canPerform(action: .split) == true)
        
        // Two files - add second (not auto-selected), first is still selected -> Split still works
        await viewModel.addFiles(urls: [urls[1]])
        #expect(viewModel.canPerform(action: .split) == true)
        
        // Two files selected -> Invalid (split requires exactly 1)
        viewModel.selectAll()
        #expect(viewModel.canPerform(action: .split) == false)
        
        // Deselect all -> Invalid (no selection)
        viewModel.deselectAll()
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

    @Test("Upgrade tap presents paywall when monetization is enabled")
    @MainActor
    func upgradeTapPresentsPaywallWhenMonetizationIsEnabled() async throws {
        let mockUsageManager = MockUsageManager()
        let viewModel = DashboardViewModel(
            usageManager: mockUsageManager,
            monetizationStateProvider: { .enabled }
        )

        viewModel.handleUpgradeTap()

        #expect(viewModel.showPaywall == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Upgrade tap shows message when monetization is disabled")
    @MainActor
    func upgradeTapShowsMessageWhenMonetizationIsDisabled() async throws {
        let mockUsageManager = MockUsageManager()
        let viewModel = DashboardViewModel(
            usageManager: mockUsageManager,
            monetizationStateProvider: { .disabled(message: "disabled") }
        )

        viewModel.handleUpgradeTap()

        #expect(viewModel.showPaywall == false)
        #expect(viewModel.errorMessage == "disabled")
    }

    @Test("Prepare action does not present paywall when monetization is disabled")
    @MainActor
    func prepareActionDoesNotPresentPaywallWhenMonetizationDisabled() async throws {
        let mockUsageManager = MockUsageManager()
        await mockUsageManager.setMockRemaining(0)

        let viewModel = DashboardViewModel(
            usageManager: mockUsageManager,
            monetizationStateProvider: { .disabled(message: L10n.Monetization.unavailable) }
        )

        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "prepare_action_no_paywall")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        await viewModel.addFiles(urls: [testURL])

        let canProceed = await viewModel.prepareAction(.split)

        #expect(canProceed == false)
        #expect(viewModel.showPaywall == false)
        #expect(viewModel.errorMessage == L10n.Monetization.unavailable)
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
        
        // Wait for notification delivery (polling)
        // This is more robust than a fixed sleep
        let timeout: UInt64 = 2_000_000_000 // 2 seconds
        let startTime = DispatchTime.now().uptimeNanoseconds
        
        while viewModel.remainingFreeActions != 4 {
            if DispatchTime.now().uptimeNanoseconds - startTime > timeout {
                Issue.record("Timed out waiting for usage update")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms poll
        }
        
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
        
        // Wait for notification delivery (polling)
        // This is more robust than a fixed sleep
        let timeout: UInt64 = 2_000_000_000 // 2 seconds
        let startTime = DispatchTime.now().uptimeNanoseconds
        
        while !viewModel.isPro {
            if DispatchTime.now().uptimeNanoseconds - startTime > timeout {
                Issue.record("Timed out waiting for Pro status update")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms poll
        }
        
        // Verify that the ViewModel auto-updated
        #expect(viewModel.isPro == true)
    }
    
    // MARK: - Auto-Selection Tests
    
    @Test("Auto-selects when adding 1 file to empty dashboard")
    @MainActor
    func autoSelectSingleFileToEmpty() async throws {
        let viewModel = createViewModel()
        
        // Given: Empty dashboard
        #expect(viewModel.files.isEmpty)
        #expect(viewModel.selectedFiles.isEmpty)
        
        // When: Adding 1 file
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "auto_select_single")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        
        // Then: File is auto-selected
        #expect(viewModel.files.count == 1)
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(viewModel.files[0]))
    }
    
    @Test("Does NOT auto-select when adding multiple files to empty dashboard")
    @MainActor
    func noAutoSelectMultipleFilesToEmpty() async throws {
        let viewModel = createViewModel()
        
        // Given: Empty dashboard
        #expect(viewModel.files.isEmpty)
        
        // When: Adding 2 files simultaneously
        let urls = try PDFTestHelpers.createTestPDFs(counts: [5, 10])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        // Then: No files are auto-selected
        #expect(viewModel.files.count == 2)
        #expect(viewModel.selectedFiles.isEmpty)
    }
    
    @Test("Does NOT auto-select when adding file to non-empty dashboard")
    @MainActor
    func noAutoSelectWhenDashboardNotEmpty() async throws {
        let viewModel = createViewModel()
        
        // Given: Dashboard with 1 existing file (already auto-selected)
        let existingURL = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "existing")
        defer { PDFTestHelpers.cleanup(url: existingURL) }
        
        await viewModel.addFiles(urls: [existingURL])
        
        // Clear selection to reset state
        viewModel.deselectAll()
        #expect(viewModel.files.count == 1)
        #expect(viewModel.selectedFiles.isEmpty)
        
        // When: Adding 1 more file
        let newURL = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "new")
        defer { PDFTestHelpers.cleanup(url: newURL) }
        
        await viewModel.addFiles(urls: [newURL])
        
        // Then: New file is NOT auto-selected (dashboard was not empty)
        #expect(viewModel.files.count == 2)
        #expect(viewModel.selectedFiles.isEmpty)
    }
    
    @Test("Auto-select happens after clear all + add 1 file")
    @MainActor
    func autoSelectAfterClearAll() async throws {
        let viewModel = createViewModel()
        
        // Given: Dashboard with files, then cleared
        let url1 = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "clear_first")
        defer { PDFTestHelpers.cleanup(url: url1) }
        
        await viewModel.addFiles(urls: [url1])
        viewModel.clearAll()
        
        #expect(viewModel.files.isEmpty)
        
        // When: Adding 1 file to now-empty dashboard
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 10, identifier: "clear_second")
        defer { PDFTestHelpers.cleanup(url: url2) }
        
        await viewModel.addFiles(urls: [url2])
        
        // Then: File is auto-selected
        #expect(viewModel.files.count == 1)
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(viewModel.files[0]))
    }
    
    @Test("Auto-selected file enables Split action immediately")
    @MainActor
    func autoSelectEnablesSplitAction() async throws {
        let viewModel = createViewModel()
        
        // When: Adding 1 file to empty dashboard (auto-selected)
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 10, identifier: "split_test")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        
        // Then: Split action is immediately available
        #expect(viewModel.canPerform(action: .split))
        #expect(viewModel.filesForAction(.split).count == 1)
        #expect(viewModel.validationError(for: .split) == nil)
    }
    
    @Test("Auto-selected file enables Edit Pages action immediately")
    @MainActor
    func autoSelectEnablesEditPagesAction() async throws {
        let viewModel = createViewModel()
        
        // When: Adding 1 file to empty dashboard (auto-selected)
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 15, identifier: "edit_pages_test")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        
        // Then: Edit Pages action is immediately available
        #expect(viewModel.canPerform(action: .editPages))
        #expect(viewModel.filesForAction(.editPages).count == 1)
        #expect(viewModel.validationError(for: .editPages) == nil)
    }
    
    @Test("Does NOT auto-select when file loading fails")
    @MainActor
    func noAutoSelectOnLoadFailure() async throws {
        let viewModel = createViewModel()
        
        // Given: Empty dashboard
        #expect(viewModel.files.isEmpty)
        
        // When: Adding invalid URL (will fail to load)
        let invalidURL = URL(fileURLWithPath: "/nonexistent/invalid.pdf")
        await viewModel.addFiles(urls: [invalidURL])
        
        // Then: No files added, no selection
        #expect(viewModel.files.isEmpty)
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("Selection can be manually toggled after auto-select")
    @MainActor
    func canToggleAfterAutoSelect() async throws {
        let viewModel = createViewModel()
        
        // Given: 1 file auto-selected
        let testURL = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "toggle_test")
        defer { PDFTestHelpers.cleanup(url: testURL) }
        
        await viewModel.addFiles(urls: [testURL])
        
        #expect(viewModel.selectedFiles.count == 1)
        let file = viewModel.files[0]
        
        // When: Deselecting the file
        viewModel.deselectFile(file)
        
        // Then: File is deselected
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(!viewModel.isSelected(file))
        
        // When: Re-selecting the file
        viewModel.selectFile(file)
        
        // Then: File is selected again
        #expect(viewModel.selectedFiles.count == 1)
        #expect(viewModel.isSelected(file))
    }
}
