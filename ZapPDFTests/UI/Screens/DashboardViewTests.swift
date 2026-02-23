//
//  DashboardViewTests.swift
//  ZapPDFTests
//
//  Unit tests for DashboardView.
//

import Testing
import SwiftUI
@testable import ZapPDF

@Suite("DashboardView Tests")
struct DashboardViewTests {
    
    // MARK: - Initialization Tests
    
    @Test("DashboardView initializes without error")
    @MainActor
    func initializesWithoutError() async {
        let view = DashboardView()
        
        // View should create successfully
        #expect(view != nil)
    }
}

// MARK: - Dashboard iOS Trailing Toolbar Tests

@Suite("Dashboard iOS Trailing Toolbar Tests")
struct DashboardIOSTrailingToolbarTests {

    @Test("iOS trailing toolbar always includes settings")
    func iOSTrailingToolbarAlwaysIncludesSettings() {
        let emptyStateActions = DashboardView.iOSTrailingToolbarActions(hasFiles: false)
        let withFilesActions = DashboardView.iOSTrailingToolbarActions(hasFiles: true)

        #expect(emptyStateActions.contains(.settings))
        #expect(withFilesActions.contains(.settings))
    }

    @Test("iOS trailing toolbar hides clear all when there are no files")
    func iOSTrailingToolbarHidesClearAllWithoutFiles() {
        let actions = DashboardView.iOSTrailingToolbarActions(hasFiles: false)

        #expect(actions == [.settings])
        #expect(actions.contains(.clearAll) == false)
    }

    @Test("iOS trailing toolbar shows clear all when files exist")
    func iOSTrailingToolbarShowsClearAllWithFiles() {
        let actions = DashboardView.iOSTrailingToolbarActions(hasFiles: true)

        #expect(actions == [.settings, .clearAll])
    }
}

// MARK: - Dashboard iOS Action Layout Tests

@Suite("Dashboard iOS Action Layout Tests")
struct DashboardIOSActionLayoutTests {

    @Test("iPad regular width 1024 uses four columns")
    func iPadRegularWidth1024UsesFourColumns() {
        let columns = DashboardView.iOSActionColumnCount(
            containerWidth: 1024,
            actionCount: 4,
            isPad: true,
            horizontalSizeClass: .regular,
            isAccessibilityTextSize: false
        )

        #expect(columns == 4)
    }

    @Test("iPad regular width 834 uses four columns")
    func iPadRegularWidth834UsesFourColumns() {
        let columns = DashboardView.iOSActionColumnCount(
            containerWidth: 834,
            actionCount: 4,
            isPad: true,
            horizontalSizeClass: .regular,
            isAccessibilityTextSize: false
        )

        #expect(columns == 4)
    }

    @Test("iPad narrow width falls back to two columns")
    func iPadNarrowWidthFallsBackToTwoColumns() {
        let columns = DashboardView.iOSActionColumnCount(
            containerWidth: 700,
            actionCount: 4,
            isPad: true,
            horizontalSizeClass: .regular,
            isAccessibilityTextSize: false
        )

        #expect(columns == 2)
    }

    @Test("iPad accessibility text size falls back to two columns")
    func iPadAccessibilityTextSizeFallsBackToTwoColumns() {
        let columns = DashboardView.iOSActionColumnCount(
            containerWidth: 1024,
            actionCount: 4,
            isPad: true,
            horizontalSizeClass: .regular,
            isAccessibilityTextSize: true
        )

        #expect(columns == 2)
    }

    @Test("iPhone keeps compact two-column behavior")
    func iPhoneKeepsCompactTwoColumnBehavior() {
        let columns = DashboardView.iOSActionColumnCount(
            containerWidth: 390,
            actionCount: 4,
            isPad: false,
            horizontalSizeClass: .compact,
            isAccessibilityTextSize: false
        )

        #expect(columns == 2)
    }
}

// MARK: - SplitOptionsSheet Tests

@Suite("SplitOptionsSheet Tests")
struct SplitOptionsSheetTests {
    
    @Test("SplitOptionsSheet initializes with page count")
    @MainActor
    func initializesWithPageCount() async {
        var splitMode: PDFSplitter.SplitMode = .splitEvery(n: 1)
        let binding = Binding(
            get: { splitMode },
            set: { splitMode = $0 }
        )
        
        let sheet = SplitOptionsSheet(
            pageCount: 10,
            splitMode: binding
        ) {
            // Confirm callback
        }
        
        #expect(sheet.pageCount == 10)
    }
    
    @Test("SplitOptionsSheet accepts zero pages")
    @MainActor
    func acceptsZeroPages() async {
        var splitMode: PDFSplitter.SplitMode = .splitEvery(n: 1)
        let binding = Binding(
            get: { splitMode },
            set: { splitMode = $0 }
        )
        
        let sheet = SplitOptionsSheet(
            pageCount: 0,
            splitMode: binding
        ) {}
        
        #expect(sheet.pageCount == 0)
    }
    
    @Test("SplitOptionsSheet accepts large page counts")
    @MainActor
    func acceptsLargePageCounts() async {
        var splitMode: PDFSplitter.SplitMode = .splitEvery(n: 1)
        let binding = Binding(
            get: { splitMode },
            set: { splitMode = $0 }
        )
        
        let sheet = SplitOptionsSheet(
            pageCount: 1000,
            splitMode: binding
        ) {}
        
        #expect(sheet.pageCount == 1000)
    }

    @Test("SplitOptionsSheet mode description mapping covers all modes")
    func modeDescriptionMappingCoversAllModes() {
        #expect(SplitOptionsSheet.modeDescription(for: 0) == L10n.SplitOptions.modeDescSplitEvery)
        #expect(SplitOptionsSheet.modeDescription(for: 1) == L10n.SplitOptions.modeDescPageRange)
        #expect(SplitOptionsSheet.modeDescription(for: 2) == L10n.SplitOptions.modeDescSelectPages)
    }

    @Test("SplitOptionsSheet mode accessibility identifiers are stable")
    func modeAccessibilityIdentifiersAreStable() {
        #expect(SplitOptionsSheet.modeOptionAccessibilityIdentifier(for: 0) == "splitMode.option.splitEvery")
        #expect(SplitOptionsSheet.modeOptionAccessibilityIdentifier(for: 1) == "splitMode.option.extractRanges")
        #expect(SplitOptionsSheet.modeOptionAccessibilityIdentifier(for: 2) == "splitMode.option.selectPages")
    }

    @Test("SplitOptionsSheet mode accessibility values reflect selection state")
    func modeAccessibilityValuesReflectSelectionState() {
        #expect(SplitOptionsSheet.modeOptionAccessibilityValue(isSelected: true) == "selected")
        #expect(SplitOptionsSheet.modeOptionAccessibilityValue(isSelected: false) == "unselected")
    }

    @Test("SplitOptionsSheet clamps split every N below lower bound")
    func clampsSplitEveryNBelowLowerBound() {
        #expect(SplitOptionsSheet.clampedSplitEveryN(0, pageCount: 10) == 1)
    }

    @Test("SplitOptionsSheet clamps split every N above page count")
    func clampsSplitEveryNAbovePageCount() {
        #expect(SplitOptionsSheet.clampedSplitEveryN(999, pageCount: 10) == 10)
    }

    @Test("SplitOptionsSheet keeps valid split every N unchanged")
    func keepsValidSplitEveryNUnchanged() {
        #expect(SplitOptionsSheet.clampedSplitEveryN(7, pageCount: 10) == 7)
    }

    @Test("SplitOptionsSheet derives initial state for split every mode")
    func derivesInitialStateForSplitEveryMode() {
        let state = SplitOptionsSheet.makeInitialState(from: .splitEvery(n: 12), pageCount: 10)

        #expect(state.modeIndex == 0)
        #expect(state.splitEveryN == 10)
        #expect(state.pageRangeText.isEmpty)
        #expect(state.selectedPages.isEmpty)
    }

    @Test("SplitOptionsSheet derives initial state for page range mode")
    func derivesInitialStateForPageRangeMode() {
        let state = SplitOptionsSheet.makeInitialState(
            from: .byPageRange(ranges: [1...3, 5...5, 9...10]),
            pageCount: 20
        )

        #expect(state.modeIndex == 1)
        #expect(state.pageRangeText == "1-3, 5, 9-10")
        #expect(state.selectedPages.isEmpty)
    }

    @Test("SplitOptionsSheet derives initial state for extract pages mode")
    func derivesInitialStateForExtractPagesMode() {
        let state = SplitOptionsSheet.makeInitialState(
            from: .extractPages(indices: [0, 1, 3, 3, 12]),
            pageCount: 10
        )

        #expect(state.modeIndex == 2)
        #expect(state.selectedPages == Set([1, 3]))
        #expect(state.pageRangeText.isEmpty)
    }
}

// MARK: - DashboardViewModel Integration Tests

@Suite("DashboardView ViewModel Integration Tests")
struct DashboardViewModelIntegrationTests {
    
    @Test("ViewModel starts with no files")
    @MainActor
    func viewModelStartsEmpty() async {
        let viewModel = DashboardViewModel()
        
        #expect(viewModel.selectedFiles.isEmpty)
        #expect(viewModel.hasFiles == false)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("ViewModel validates merge action correctly")
    @MainActor
    func validatesMergeAction() async throws {
        let viewModel = DashboardViewModel()
        
        // With no files, can't merge
        #expect(viewModel.canPerform(action: .merge) == false)
        
        // Add files
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        // With 2 files, can merge
        #expect(viewModel.canPerform(action: .merge) == true)
    }
    
    @Test("ViewModel validates split action correctly")
    @MainActor
    func validatesSplitAction() async throws {
        let viewModel = DashboardViewModel()
        
        // With no files, can't split
        #expect(viewModel.canPerform(action: .split) == false)
        
        // Add one file (use unique identifier to avoid parallel test collisions)
        let identifier1 = "split_validation_\(UUID().uuidString)"
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: identifier1)
        defer { PDFTestHelpers.cleanup(url: url) }
        
        await viewModel.addFiles(urls: [url])
        
        // With 1 file (auto-selected), can split
        #expect(viewModel.canPerform(action: .split) == true)
        
        // Add another file
        let identifier2 = "split_validation_second_\(UUID().uuidString)"
        let url2 = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: identifier2)
        defer { PDFTestHelpers.cleanup(url: url2) }
        
        await viewModel.addFiles(urls: [url2])
        
        // With 2 files selected, can't split (only works with 1)
        // Select all files to test "more than 1 file" case
        viewModel.selectAll()
        #expect(viewModel.canPerform(action: .split) == false)
    }
    
    @Test("ClearAll resets state")
    @MainActor
    func clearAllResetsState() async throws {
        let viewModel = DashboardViewModel()
        
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3)
        defer { PDFTestHelpers.cleanup(url: url) }
        
        await viewModel.addFiles(urls: [url])
        #expect(viewModel.hasFiles == true)
        
        viewModel.clearAll()
        
        #expect(viewModel.hasFiles == false)
        #expect(viewModel.selectedFiles.isEmpty)
    }
}

// MARK: - Action Button State Tests

@Suite("Dashboard Action Button State Tests")
struct DashboardActionButtonStateTests {
    
    @Test("All actions disabled with no files")
    @MainActor
    func allActionsDisabledWithNoFiles() async {
        let viewModel = DashboardViewModel()
        
        for action in UserAction.allCases {
            #expect(viewModel.canPerform(action: action) == false,
                   "Action \(action) should be disabled with no files")
        }
    }
    
    @Test("Single file enables single-file actions")
    @MainActor
    func singleFileEnablesSingleFileActions() async throws {
        let viewModel = DashboardViewModel()
        
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5)
        defer { PDFTestHelpers.cleanup(url: url) }
        
        await viewModel.addFiles(urls: [url])
        
        // Single-file actions should be enabled
        #expect(viewModel.canPerform(action: .split) == true)
        #expect(viewModel.canPerform(action: .editPages) == true)
        #expect(viewModel.canPerform(action: .flatten) == true)
        
        // Multi-file actions should be disabled
        #expect(viewModel.canPerform(action: .merge) == false)
    }
    
    @Test("Multiple files enable merge")
    @MainActor
    func multipleFilesEnableMerge() async throws {
        let viewModel = DashboardViewModel()
        
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3, 4])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        await viewModel.addFiles(urls: urls)
        
        // Merge should be enabled
        #expect(viewModel.canPerform(action: .merge) == true)
        
        // Single-file actions should be disabled
        #expect(viewModel.canPerform(action: .split) == false)
        #expect(viewModel.canPerform(action: .editPages) == false)
        #expect(viewModel.canPerform(action: .flatten) == false)
    }
}
