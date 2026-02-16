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
#if os(iOS)
import UIKit
#endif

@Suite("Dashboard Clear & Undo Tests")
struct DashboardClearUndoTests {
    
    // MARK: - Helper
    
    @MainActor
    private func createViewModel() -> DashboardViewModel {
        DashboardViewModel(usageManager: MockUsageManager())
    }

    #if os(iOS)
    @MainActor
    private func createIOSViewModel(cleanupDelay: Duration = .milliseconds(150)) -> DashboardViewModel {
        DashboardViewModel(
            usageManager: MockUsageManager(),
            scannedFileCleanupDelay: cleanupDelay
        )
    }

    @available(iOS 17.0, *)
    private func createInternalScanPDFURL(identifier: String) async throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 595, height: 842))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
        }

        let result = try await DocumentScanner.shared.convertImagesToPDF(
            [image],
            fileName: "dashboard_internal_\(identifier)_\(UUID().uuidString.prefix(8))",
            progress: nil
        )
        return result.pdfURL
    }
    #endif
    
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

    #if os(iOS)
    @Test("Removing internal scan file deletes it from disk")
    @MainActor
    @available(iOS 17.0, *)
    func removingInternalScanDeletesDiskFile() async throws {
        let viewModel = createIOSViewModel(cleanupDelay: .milliseconds(100))
        let internalURL = try await createInternalScanPDFURL(identifier: "remove")

        await viewModel.addFiles(urls: [internalURL], origin: .internalScan)
        let file = try #require(viewModel.files.first)
        #expect(FileManager.default.fileExists(atPath: internalURL.path))

        viewModel.removeFile(file)
        #expect(!FileManager.default.fileExists(atPath: internalURL.path))
    }

    @Test("Removing external file does not delete original file")
    @MainActor
    func removingExternalFileKeepsOriginal() async throws {
        let viewModel = createIOSViewModel(cleanupDelay: .milliseconds(100))
        let externalURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "external_keep")
        defer { PDFTestHelpers.cleanup(url: externalURL) }

        await viewModel.addFiles(urls: [externalURL], origin: .external)
        let file = try #require(viewModel.files.first)

        viewModel.removeFile(file)
        #expect(FileManager.default.fileExists(atPath: externalURL.path))
    }

    @Test("Clear all without undo eventually deletes internal scan files")
    @MainActor
    @available(iOS 17.0, *)
    func clearAllWithoutUndoDeletesInternalFiles() async throws {
        let viewModel = createIOSViewModel(cleanupDelay: .milliseconds(150))
        let internalURL = try await createInternalScanPDFURL(identifier: "clear_without_undo")

        await viewModel.addFiles(urls: [internalURL], origin: .internalScan)
        viewModel.clearAll()

        let deadline = ContinuousClock.now + .seconds(2)
        while FileManager.default.fileExists(atPath: internalURL.path) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(!FileManager.default.fileExists(atPath: internalURL.path))
    }

    @Test("Clear all with restore preserves internal scan files")
    @MainActor
    @available(iOS 17.0, *)
    func clearAllWithRestoreKeepsInternalFiles() async throws {
        let viewModel = createIOSViewModel(cleanupDelay: .milliseconds(150))
        let internalURL = try await createInternalScanPDFURL(identifier: "clear_with_restore")
        defer { _ = DocumentScanner.cleanupScannedFile(at: internalURL) }

        await viewModel.addFiles(urls: [internalURL], origin: .internalScan)
        let filesToRestore = viewModel.files
        let selectionToRestore = viewModel.selectedFileIDs

        viewModel.clearAll()
        viewModel.restoreFiles(filesToRestore, selection: selectionToRestore)

        try await Task.sleep(for: .milliseconds(350))
        #expect(FileManager.default.fileExists(atPath: internalURL.path))
    }
    #endif
}
