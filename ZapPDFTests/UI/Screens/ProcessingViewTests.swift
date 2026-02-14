//
//  ProcessingViewTests.swift
//  ZapPDFTests
//
//  Unit tests for ProcessingView.
//

import Testing
import SwiftUI
@testable import ZapPDF

@Suite("ProcessingView Tests")
struct ProcessingViewTests {
    
    // MARK: - Initialization Tests
    
    @Test("ProcessingView initializes with parameters")
    @MainActor
    func initializesWithParameters() async {
        let view = ProcessingView(
            action: .merge,
            files: [],
            options: .merge(outputFileName: "Test")
        )
        
        #expect(view.action == .merge)
        #expect(view.files.isEmpty)
    }
    
    @Test("ProcessingView accepts all action types")
    @MainActor
    func acceptsAllActionTypes() async {
        for action in UserAction.allCases {
            let view = ProcessingView(
                action: action,
                files: [],
                options: ProcessingOptions()
            )
            
            #expect(view.action == action)
        }
    }
}

// MARK: - ProcessingState Tests

@Suite("ProcessingState Tests")
struct ProcessingStateTests {
    
    @Test("ProcessingState idle is default")
    func idleIsDefault() {
        let state = ProcessingState.idle
        #expect(state == .idle)
    }
    
    @Test("ProcessingState processing contains progress")
    func processingContainsProgress() {
        let state = ProcessingState.processing(progress: 0.5, message: "Test")
        
        if case .processing(let progress, let message) = state {
            #expect(progress == 0.5)
            #expect(message == "Test")
        } else {
            Issue.record("State should be processing")
        }
    }
    
    @Test("ProcessingState completed contains URLs")
    func completedContainsURLs() {
        let urls = [URL(fileURLWithPath: "/tmp/test.pdf")]
        let state = ProcessingState.completed(resultURLs: urls)
        
        if case .completed(let resultURLs) = state {
            #expect(resultURLs.count == 1)
            #expect(resultURLs.first?.lastPathComponent == "test.pdf")
        } else {
            Issue.record("State should be completed")
        }
    }
    
    @Test("ProcessingState failed contains message")
    func failedContainsMessage() {
        let state = ProcessingState.failed(message: "Something went wrong")
        
        if case .failed(let errorMessage) = state {
            #expect(errorMessage == "Something went wrong")
        } else {
            Issue.record("State should be failed")
        }
    }
    
    @Test("ProcessingState cancelled exists")
    func cancelledExists() {
        let state = ProcessingState.cancelled
        #expect(state == .cancelled)
    }
    
    @Test("ProcessingState conforms to Equatable")
    func stateEquatable() {
        #expect(ProcessingState.idle == ProcessingState.idle)
        #expect(ProcessingState.cancelled == ProcessingState.cancelled)
        #expect(ProcessingState.idle != ProcessingState.cancelled)
        
        // Different progress values should not be equal
        let progress1 = ProcessingState.processing(progress: 0.5, message: "Test")
        let progress2 = ProcessingState.processing(progress: 0.6, message: "Test")
        #expect(progress1 != progress2)
        
        // Same progress values should be equal
        let progress3 = ProcessingState.processing(progress: 0.5, message: "Test")
        #expect(progress1 == progress3)
    }
}

// MARK: - ProcessingOptions Tests

@Suite("ProcessingOptions Tests")
struct ProcessingOptionsTests {
    
    @Test("ProcessingOptions merge creates correctly")
    func mergeOptionsCreation() {
        let options = ProcessingOptions.merge(outputFileName: "Combined")
        
        #expect(options.mergeOptions?.outputFileName == "Combined")
        #expect(options.splitMode == nil)
    }
    
    @Test("ProcessingOptions split creates correctly")
    func splitOptionsCreation() {
        let options = ProcessingOptions.split(mode: .splitEvery(n: 5))
        
        if case .splitEvery(let n) = options.splitMode {
            #expect(n == 5)
        } else {
            Issue.record("Split mode should be splitEvery")
        }
        
        #expect(options.mergeOptions == nil)
    }
    
    @Test("ProcessingOptions edit pages creates correctly")
    func editPagesOptionsCreation() {
        let file = PDFFile(
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            fileName: "test.pdf",
            pageCount: 4,
            fileSize: 1024
        )
        
        let options = ProcessingOptions.editPages(
            file: file,
            newOrder: [1, 0, 2, 3],
            rotations: [1: .clockwise90],
            outputFileName: "edited_output"
        )
        
        #expect(options.editPagesOptions?.file.fileName == "test.pdf")
        #expect(options.editPagesOptions?.newOrder == [1, 0, 2, 3])
        #expect(options.editPagesOptions?.rotations[1] == .clockwise90)
        #expect(options.editPagesOptions?.outputFileName == "edited_output")
        #expect(options.mergeOptions == nil)
        #expect(options.splitMode == nil)
        #expect(options.flattenOptions == nil)
    }
    
    @Test("ProcessingOptions default initializer works")
    func defaultInitializer() {
        let options = ProcessingOptions()
        
        #expect(options.mergeOptions == nil)
        #expect(options.splitMode == nil)
        #expect(options.flattenOptions == nil)
        #expect(options.editPagesOptions == nil)
    }
}

// MARK: - ViewModel Integration Tests

@Suite("ProcessingViewModel Integration Tests")
struct ProcessingViewModelIntegrationTests {
    
    @Test("ProcessingViewModel initial state is idle")
    @MainActor
    func initialStateIsIdle() async {
        let viewModel = ProcessingViewModel()
        
        #expect(viewModel.state == .idle)
    }
    
    @Test("ProcessingViewModel cancel sets cancelled state")
    @MainActor
    func cancelSetsCancelledState() async {
        let viewModel = ProcessingViewModel()
        
        viewModel.cancel()
        
        #expect(viewModel.state == .cancelled)
    }
    
    @Test("ProcessingViewModel reset sets idle state")
    @MainActor
    func resetSetsIdleState() async {
        let viewModel = ProcessingViewModel()
        
        viewModel.cancel()
        #expect(viewModel.state == .cancelled)
        
        viewModel.reset()
        #expect(viewModel.state == .idle)
    }
}

// MARK: - Share Sheet Tests (iOS only)

#if os(iOS)
@Suite("ShareSheet Tests")
struct ShareSheetTests {
    
    @Test("ShareSheet initializes with items")
    @MainActor
    func initializesWithItems() async {
        let items: [Any] = [URL(fileURLWithPath: "/tmp/test.pdf")]
        let sheet = ShareSheet(items: items)
        
        #expect(sheet.items.count == 1)
    }
}
#endif
