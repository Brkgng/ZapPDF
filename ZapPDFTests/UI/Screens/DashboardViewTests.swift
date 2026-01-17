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
        #expect(viewModel.canPerform(action: .convert) == true)
        
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
        #expect(viewModel.canPerform(action: .convert) == false)
    }
}
