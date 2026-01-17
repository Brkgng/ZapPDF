//
//  ProcessingViewModelTests.swift
//  ZapPDFTests
//
//  Unit tests for ProcessingViewModel.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("ProcessingViewModel Tests")
struct ProcessingViewModelTests {
    
    // MARK: - Helper
    
    @MainActor
    private func createViewModel(usageManager: MockUsageManager = MockUsageManager()) -> ProcessingViewModel {
        ProcessingViewModel(usageManager: usageManager)
    }
    
    // MARK: - Initial State Tests
    
    @Test("Initial state is idle")
    @MainActor
    func initialStateIsIdle() {
        let viewModel = createViewModel()
        
        #expect(viewModel.state == .idle)
    }
    
    // MARK: - Merge Operation Tests
    
    @Test("Execute merge transitions to processing")
    @MainActor
    func executeMergeTransitionsToProcessing() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [50, 50])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        let files = try await urls.asyncMap { try await PDFFile(url: $0) }
        
        // Start execution in background
        Task {
            await viewModel.execute(
                action: .merge,
                files: files,
                options: .merge(outputFileName: "test_merge")
            )
        }
        
        // Poll for state to change from idle
        var retries = 0
        while viewModel.state == .idle && retries < 100 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            retries += 1
        }
        
        // State should be processing or completed (fast machines may complete quickly)
        let isProcessingOrCompleted: Bool
        switch viewModel.state {
        case .processing, .completed:
            isProcessingOrCompleted = true
        default:
            isProcessingOrCompleted = false
        }
        
        #expect(isProcessingOrCompleted == true)
    }
    
    @Test("Execute merge transitions to completed")
    @MainActor
    func executeMergeTransitionsToCompleted() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        let files = try await urls.asyncMap { try await PDFFile(url: $0) }
        
        await viewModel.execute(
            action: .merge,
            files: files,
            options: .merge(outputFileName: "test_merge")
        )
        
        if case .completed(let resultURLs) = viewModel.state {
            #expect(resultURLs.count == 1)
            // Clean up result
            PDFTestHelpers.cleanup(url: resultURLs[0])
        } else {
            Issue.record("Expected completed state but got \(viewModel.state)")
        }
    }
    
    @Test("Execute with empty files transitions to failed")
    @MainActor
    func executeWithEmptyFilesTransitionsToFailed() async {
        let viewModel = createViewModel()
        
        await viewModel.execute(
            action: .merge,
            files: [],
            options: .merge()
        )
        
        if case .failed = viewModel.state {
            // Expected
        } else {
            Issue.record("Expected failed state but got \(viewModel.state)")
        }
    }
    
    // MARK: - Split Operation Tests
    
    @Test("Execute split with valid options completes")
    @MainActor
    func executeSplitWithValidOptions() async throws {
        let viewModel = createViewModel()
        let identifier = "split_test_\(UUID().uuidString)"
        let url = try PDFTestHelpers.createTestPDF(pageCount: 6, identifier: identifier)
        defer { PDFTestHelpers.cleanup(url: url) }
        
        // Ensure file exists and is valid
        let file = try await PDFFile(url: url)
        
        await viewModel.execute(
            action: .split,
            files: [file],
            options: .split(mode: .splitEvery(n: 2))
        )
        
        if case .completed(let resultURLs) = viewModel.state {
            #expect(resultURLs.count == 3) // 6 pages / 2 = 3 files
            PDFTestHelpers.cleanup(urls: resultURLs)
        } else {
            Issue.record("Expected completed state but got \(viewModel.state)")
        }
    }
    
    // MARK: - Cancel Tests
    
    @Test("Cancel transitions to cancelled")
    @MainActor
    func cancelTransitionsToCancelled() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [200, 200, 200])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        let files = try await urls.asyncMap { try await PDFFile(url: $0) }
        
        // Start a long operation
        Task {
            await viewModel.execute(
                action: .merge,
                files: files,
                options: .merge()
            )
        }
        
        // Wait for processing to start
        var retries = 0
        while viewModel.state == .idle && retries < 100 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            retries += 1
        }
        
        #expect(viewModel.state != .idle, "Task failed to start testing")
        
        // Cancel immediately once started
        viewModel.cancel()
        
        // Wait for cancellation to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        #expect(viewModel.state == .cancelled)
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset returns to idle")
    @MainActor
    func resetReturnsToIdle() async throws {
        let viewModel = createViewModel()
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        let files = try await urls.asyncMap { try await PDFFile(url: $0) }
        
        await viewModel.execute(
            action: .merge,
            files: files,
            options: .merge()
        )
        
        // Clean up any result files
        if case .completed(let resultURLs) = viewModel.state {
            PDFTestHelpers.cleanup(urls: resultURLs)
        }
        
        viewModel.reset()
        
        #expect(viewModel.state == .idle)
    }
    
    // MARK: - Usage Tracking Tests
    
    @Test("Records action on success")
    @MainActor
    func recordsActionOnSuccess() async throws {
        let mockUsageManager = MockUsageManager()
        let viewModel = createViewModel(usageManager: mockUsageManager)
        let urls = try PDFTestHelpers.createTestPDFs(counts: [2, 3])
        defer { PDFTestHelpers.cleanup(urls: urls) }
        
        let files = try await urls.asyncMap { try await PDFFile(url: $0) }
        
        await viewModel.execute(
            action: .merge,
            files: files,
            options: .merge()
        )
        
        // Clean up result
        if case .completed(let resultURLs) = viewModel.state {
            PDFTestHelpers.cleanup(urls: resultURLs)
        }
        
        let wasRecordCalled = await mockUsageManager.wasRecordActionCalled()
        #expect(wasRecordCalled == true)
    }
}

// MARK: - Array Extension for Async Map

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}
