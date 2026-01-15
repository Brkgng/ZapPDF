//
//  PageReorderViewModelTests.swift
//  ZapPDFTests
//
//  Unit tests for PageReorderViewModel.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("PageReorderViewModel Tests", .serialized)
struct PageReorderViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test("ViewModel initializes with file")
    @MainActor
    func viewModelInitializesWithFile() async {
        let file = PDFFile(
            url: URL(fileURLWithPath: "/test.pdf"),
            fileName: "test.pdf",
            pageCount: 5,
            fileSize: 1000
        )
        
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        #expect(viewModel.sourceFile.fileName == "test.pdf")
        #expect(viewModel.pages.isEmpty)
        #expect(viewModel.hasChanges == false)
        #expect(viewModel.canUndo == false)
        #expect(viewModel.canRedo == false)
    }
    
    // MARK: - Load Pages Tests
    
    @Test("loadPages creates page items")
    @MainActor
    func loadPagesCreatesPageItems() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 5, identifier: "load_pages_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 5, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        #expect(viewModel.pages.count == 5)
        #expect(viewModel.isLoadingPages == false)
    }
    
    @Test("loadPages sets error for invalid file")
    @MainActor
    func loadPagesSetsErrorForInvalidFile() async {
        let file = PDFFile(
            url: URL(fileURLWithPath: "/nonexistent.pdf"),
            fileName: "nonexistent.pdf",
            pageCount: 5,
            fileSize: 1000
        )
        
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        #expect(viewModel.pages.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }
    
    // MARK: - Move Pages Tests
    
    @Test("movePages updates page order")
    @MainActor
    func movePagesUpdatesPageOrder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "move_pages_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        // Move page 0 to position 2
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        
        #expect(viewModel.pages.reorderedIndices == [1, 0, 2, 3])
        #expect(viewModel.hasChanges == true)
    }
    
    @Test("movePages enables undo")
    @MainActor
    func movePagesEnablesUndo() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "undo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        #expect(viewModel.canUndo == false)
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        
        #expect(viewModel.canUndo == true)
    }
    
    // MARK: - Undo/Redo Tests
    
    @Test("undo restores previous order")
    @MainActor
    func undoRestoresPreviousOrder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "undo_restore_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        let originalOrder = viewModel.pages.reorderedIndices
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        
        #expect(viewModel.pages.reorderedIndices != originalOrder)
        
        viewModel.undo()
        
        #expect(viewModel.pages.reorderedIndices == originalOrder)
        #expect(viewModel.canUndo == false)
        #expect(viewModel.canRedo == true)
    }
    
    @Test("redo restores undone change")
    @MainActor
    func redoRestoresUndoneChange() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "redo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        let orderAfterMove = viewModel.pages.reorderedIndices
        
        viewModel.undo()
        viewModel.redo()
        
        #expect(viewModel.pages.reorderedIndices == orderAfterMove)
        #expect(viewModel.canRedo == false)
    }
    
    @Test("new move clears redo stack")
    @MainActor
    func newMoveClearsRedoStack() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "clear_redo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        viewModel.undo()
        
        #expect(viewModel.canRedo == true)
        
        viewModel.movePages(from: IndexSet(integer: 1), to: 3)
        
        #expect(viewModel.canRedo == false)
    }
    
    @Test("multiple undo operations work correctly")
    @MainActor
    func multipleUndoOperationsWorkCorrectly() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "multi_undo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        let originalOrder = viewModel.pages.reorderedIndices
        
        // Make 3 moves
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        viewModel.movePages(from: IndexSet(integer: 1), to: 3)
        viewModel.movePages(from: IndexSet(integer: 2), to: 0)
        
        // Undo all 3
        viewModel.undo()
        viewModel.undo()
        viewModel.undo()
        
        #expect(viewModel.pages.reorderedIndices == originalOrder)
        #expect(viewModel.canUndo == false)
    }
    
    // MARK: - Reset Order Tests
    
    @Test("resetOrder restores original order")
    @MainActor
    func resetOrderRestoresOriginalOrder() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "reset_order_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 3)
        viewModel.movePages(from: IndexSet(integer: 1), to: 0)
        
        viewModel.resetOrder()
        
        #expect(viewModel.pages.reorderedIndices == [0, 1, 2, 3])
        #expect(viewModel.hasChanges == false)
    }
    
    @Test("resetOrder enables undo")
    @MainActor
    func resetOrderEnablesUndo() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "reset_undo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        let orderBeforeReset = viewModel.pages.reorderedIndices
        
        viewModel.resetOrder()
        
        #expect(viewModel.canUndo == true)
        
        viewModel.undo()
        
        #expect(viewModel.pages.reorderedIndices == orderBeforeReset)
    }
    
    // MARK: - Selection Tests
    
    @Test("selectedPage returns correct page")
    @MainActor
    func selectedPageReturnsCorrectPage() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "selection_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.selectedPageIndex = 1
        
        #expect(viewModel.selectedPage?.originalIndex == 1)
    }
    
    @Test("selectedPage returns nil for invalid index")
    @MainActor
    func selectedPageReturnsNilForInvalidIndex() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "invalid_selection_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.selectedPageIndex = 10  // Out of range
        
        #expect(viewModel.selectedPage == nil)
    }
    
    // MARK: - Save Tests (Validation Only)
    
    @Test("save throws error when no changes")
    @MainActor
    func saveThrowsErrorWhenNoChanges() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "no_changes_save_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("output.pdf")
        
        await #expect(throws: PageReorderError.self) {
            try await viewModel.save(to: destination)
        }
    }
    
    @Test("save succeeds with changes")
    @MainActor
    func saveSucceedsWithChanges() async throws {
        let testId = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "save_success_\(testId)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let mockUsageManager = MockUsageManager()
        let viewModel = PageReorderViewModel(file: file, usageManager: mockUsageManager)
        
        await viewModel.loadPages()
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)
        
        // Use saveToTemporary which doesn't require a specific destination
        let result = try await viewModel.saveToTemporary()
        defer { PDFTestHelpers.cleanup(url: result) }
        
        #expect(FileManager.default.fileExists(atPath: result.path))
        
        // Verify usage was recorded
        let wasRecorded = await mockUsageManager.wasRecordActionCalled()
        #expect(wasRecorded == true)
    }
    
    // MARK: - Delete Page Tests
    
    @Test("deletePage removes page at index")
    @MainActor
    func deletePageRemovesPageAtIndex() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "delete_page_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        #expect(viewModel.pages.count == 4)
        
        // Delete page at index 1
        viewModel.deletePage(at: 1)
        
        #expect(viewModel.pages.count == 3)
        #expect(viewModel.hasChanges == true)
    }
    
    @Test("deletePage enables undo")
    @MainActor
    func deletePageEnablesUndo() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "delete_undo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        viewModel.deletePage(at: 0)
        
        #expect(viewModel.canUndo == true)
        
        // Undo should restore the page
        viewModel.undo()
        #expect(viewModel.pages.count == 3)
    }
    
    @Test("deletePage adjusts selection when deleted page was selected")
    @MainActor
    func deletePageAdjustsSelection() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 4, identifier: "delete_selection_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 4, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        viewModel.selectedPageIndex = 2
        
        // Delete the selected page
        viewModel.deletePage(at: 2)
        
        // Selection should move to previous page
        #expect(viewModel.selectedPageIndex == 1)
    }
    
    @Test("deletePage prevents deleting last page")
    @MainActor
    func deletePagePreventsLastPage() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "delete_last_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 1, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        #expect(viewModel.pages.count == 1)
        
        // Try to delete the only page
        viewModel.deletePage(at: 0)
        
        // Should still have 1 page and error message
        #expect(viewModel.pages.count == 1)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("canDeleteSelectedPage returns correct value")
    @MainActor
    func canDeleteSelectedPageReturnsCorrectValue() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "can_delete_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 2, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        // No selection - cannot delete
        viewModel.selectedPageIndex = nil
        #expect(viewModel.canDeleteSelectedPage == false)
        
        // With selection - can delete
        viewModel.selectedPageIndex = 0
        #expect(viewModel.canDeleteSelectedPage == true)
        
        // Delete one page - only 1 left, cannot delete
        viewModel.deletePage(at: 1)
        #expect(viewModel.canDeleteSelectedPage == false)
    }
    
    // MARK: - Rotation Tests
    
    @Test("rotateSelectedPageClockwise rotates selected page")
    @MainActor
    func rotateSelectedPageClockwiseRotatesSelectedPage() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "rotate_clockwise_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        viewModel.selectedPageIndex = 1
        
        viewModel.rotateSelectedPageClockwise()
        
        #expect(viewModel.pages[1].rotation == .clockwise90)
        #expect(viewModel.hasChanges == true)
    }
    
    @Test("rotateSelectedPageCounterClockwise rotates selected page")
    @MainActor
    func rotateSelectedPageCounterClockwiseRotatesSelectedPage() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "rotate_ccw_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        viewModel.selectedPageIndex = 0
        
        viewModel.rotateSelectedPageCounterClockwise()
        
        #expect(viewModel.pages[0].rotation == .clockwise270)
        #expect(viewModel.hasChanges == true)
    }
    
    @Test("rotatePage enables undo")
    @MainActor
    func rotatePageEnablesUndo() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "rotate_undo_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        #expect(viewModel.canUndo == false)
        
        viewModel.rotatePage(at: 1, clockwise: true)
        
        #expect(viewModel.canUndo == true)
    }
    
    @Test("undo reverts rotation")
    @MainActor
    func undoRevertsRotation() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "undo_rotation_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 3, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        viewModel.rotatePage(at: 0, clockwise: true)
        #expect(viewModel.pages[0].rotation == .clockwise90)
        
        viewModel.undo()
        
        #expect(viewModel.pages[0].rotation == .none)
        #expect(viewModel.hasChanges == false)
    }
    
    @Test("canRotateSelectedPage returns correct value")
    @MainActor
    func canRotateSelectedPageReturnsCorrectValue() async throws {
        let url = try PDFTestHelpers.createTestPDF(pageCount: 2, identifier: "can_rotate_test")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let file = PDFFile(url: url, fileName: "test.pdf", pageCount: 2, fileSize: 1000)
        let viewModel = PageReorderViewModel(file: file, usageManager: MockUsageManager())
        
        await viewModel.loadPages()
        
        // No selection - cannot rotate
        viewModel.selectedPageIndex = nil
        #expect(viewModel.canRotateSelectedPage == false)
        
        // With selection - can rotate
        viewModel.selectedPageIndex = 0
        #expect(viewModel.canRotateSelectedPage == true)
    }
}


// MARK: - PageReorderError Tests

@Suite("PageReorderError Tests")
struct PageReorderErrorTests {
    
    @Test("errors have localized descriptions")
    func errorsHaveLocalizedDescriptions() {
        let errors: [PageReorderError] = [
            .noChanges,
            .invalidPageOrder,
            .saveFailed(URL(fileURLWithPath: "/test.pdf")),
            .cancelled
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}
