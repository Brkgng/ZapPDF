//
//  PageItemTests.swift
//  ZapPDFTests
//
//  Unit tests for PageItem model.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("PageItem Tests")
struct PageItemTests {
    
    // MARK: - Initialization Tests
    
    @Test("PageItem initializes with correct originalIndex")
    func pageItemInitializesWithCorrectOriginalIndex() {
        let page = PageItem(originalIndex: 5)
        
        #expect(page.originalIndex == 5)
        #expect(page.displayPageNumber == 6)  // 1-based
    }
    
    @Test("PageItem has unique ID")
    func pageItemHasUniqueID() {
        let page1 = PageItem(originalIndex: 0)
        let page2 = PageItem(originalIndex: 0)
        
        #expect(page1.id != page2.id)
    }
    
    @Test("displayPageNumber is 1-based")
    func displayPageNumberIsOneBased() {
        let page0 = PageItem(originalIndex: 0)
        let page5 = PageItem(originalIndex: 5)
        let page99 = PageItem(originalIndex: 99)
        
        #expect(page0.displayPageNumber == 1)
        #expect(page5.displayPageNumber == 6)
        #expect(page99.displayPageNumber == 100)
    }
    
    // MARK: - Hashable & Equatable Tests
    
    @Test("PageItems with same ID are equal")
    func pageItemsWithSameIDAreEqual() {
        let sharedID = UUID()
        let page1 = PageItem(id: sharedID, originalIndex: 0)
        let page2 = PageItem(id: sharedID, originalIndex: 5)  // Different index
        
        #expect(page1 == page2)
        #expect(page1.hashValue == page2.hashValue)
    }
    
    @Test("PageItems with different IDs are not equal")
    func pageItemsWithDifferentIDsAreNotEqual() {
        let page1 = PageItem(originalIndex: 0)
        let page2 = PageItem(originalIndex: 0)
        
        #expect(page1 != page2)
    }
    
    // MARK: - Collection Extension Tests
    
    @Test("create generates correct number of pages")
    func createGeneratesCorrectNumberOfPages() {
        let pages = [PageItem].create(pageCount: 5)
        
        #expect(pages.count == 5)
    }
    
    @Test("create generates pages in order")
    func createGeneratesPagesInOrder() {
        let pages = [PageItem].create(pageCount: 5)
        
        for (index, page) in pages.enumerated() {
            #expect(page.originalIndex == index)
        }
    }
    
    @Test("create with zero pages returns empty array")
    func createWithZeroPagesReturnsEmptyArray() {
        let pages = [PageItem].create(pageCount: 0)
        #expect(pages.isEmpty)
    }
    
    @Test("create with negative pages returns empty array")
    func createWithNegativePagesReturnsEmptyArray() {
        let pages = [PageItem].create(pageCount: -5)
        #expect(pages.isEmpty)
    }
    
    @Test("reorderedIndices returns original indices")
    func reorderedIndicesReturnsOriginalIndices() {
        let pages = [PageItem].create(pageCount: 4)
        
        // Original order
        #expect(pages.reorderedIndices == [0, 1, 2, 3])
    }
    
    @Test("reorderedIndices reflects reordering")
    func reorderedIndicesReflectsReordering() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Swap pages 1 and 2
        pages.swapAt(1, 2)
        
        #expect(pages.reorderedIndices == [0, 2, 1, 3])
    }

    // MARK: - Manual Reorder Detection Tests

    @Test("isManuallyReordered returns false for original order")
    func isManuallyReorderedReturnsFalseForOriginalOrder() {
        let pages = [PageItem].create(pageCount: 5)

        for index in pages.indices {
            #expect(pages.isManuallyReordered(at: index) == false)
        }
    }

    @Test("isManuallyReordered returns false for deletion-only shifts")
    func isManuallyReorderedReturnsFalseForDeletionOnlyShift() {
        var pages = [PageItem].create(pageCount: 4)
        pages.remove(at: 1)  // [0,2,3]

        for index in pages.indices {
            #expect(pages.isManuallyReordered(at: index) == false)
        }
    }

    @Test("isManuallyReordered returns true for pages that were manually moved")
    func isManuallyReorderedReturnsTrueForManualMove() {
        var pages = [PageItem].create(pageCount: 4)
        pages.swapAt(1, 2)  // [0,2,1,3]

        #expect(pages.isManuallyReordered(at: 0) == false)
        #expect(pages.isManuallyReordered(at: 1) == true)
        #expect(pages.isManuallyReordered(at: 2) == true)
        #expect(pages.isManuallyReordered(at: 3) == false)
    }

    @Test("isManuallyReordered handles reorder plus deletion")
    func isManuallyReorderedHandlesReorderPlusDeletion() {
        var pages = [PageItem].create(pageCount: 5)
        pages.swapAt(1, 2)  // [0,2,1,3,4]
        pages.remove(at: 0) // [2,1,3,4]

        #expect(pages.isManuallyReordered(at: 0) == true)
        #expect(pages.isManuallyReordered(at: 1) == true)
        #expect(pages.isManuallyReordered(at: 2) == false)
        #expect(pages.isManuallyReordered(at: 3) == false)
    }

    @Test("isManuallyReordered returns false for invalid indices")
    func isManuallyReorderedReturnsFalseForInvalidIndices() {
        let pages = [PageItem].create(pageCount: 3)

        #expect(pages.isManuallyReordered(at: -1) == false)
        #expect(pages.isManuallyReordered(at: pages.count) == false)
    }
    
    @Test("hasChanges returns false for original order")
    func hasChangesReturnsFalseForOriginalOrder() {
        let pages = [PageItem].create(pageCount: 5)
        
        #expect(pages.hasChanges == false)
    }
    
    @Test("hasChanges returns true after reordering")
    func hasChangesReturnsTrueAfterReordering() {
        var pages = [PageItem].create(pageCount: 5)
        
        // Swap first two pages
        pages.swapAt(0, 1)
        
        #expect(pages.hasChanges == true)
    }
    
    @Test("hasChanges returns true when page moved to end")
    func hasChangesReturnsTrueWhenPageMovedToEnd() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Move first page to end
        let first = pages.removeFirst()
        pages.append(first)
        
        // [1, 2, 3, 0] instead of [0, 1, 2, 3]
        #expect(pages.hasChanges == true)
        #expect(pages.reorderedIndices == [1, 2, 3, 0])
    }
    
    @Test("hasChanges returns false if moved back to original")
    func hasChangesReturnsFalseIfMovedBackToOriginal() {
        var pages = [PageItem].create(pageCount: 3)
        
        // Swap and swap back
        pages.swapAt(0, 1)
        pages.swapAt(0, 1)
        
        #expect(pages.hasChanges == false)
    }
    
    @Test("empty array has no changes")
    func emptyArrayHasNoChanges() {
        let pages: [PageItem] = []
        
        #expect(pages.hasChanges == false)
        #expect(pages.reorderedIndices.isEmpty)
    }
    
    @Test("single page array has no changes when unchanged")
    func singlePageArrayHasNoChangesWhenUnchanged() {
        let pages = [PageItem].create(pageCount: 1)
        
        #expect(pages.hasChanges == false)
    }
    
    // MARK: - Move Operations Tests
    
    @Test("move operation updates reorderedIndices correctly")
    func moveOperationUpdatesReorderedIndicesCorrectly() {
        var pages = [PageItem].create(pageCount: 5)
        
        // Move page at index 3 to index 1
        let page = pages.remove(at: 3)
        pages.insert(page, at: 1)
        
        // Original [0,1,2,3,4] -> [0,3,1,2,4]
        #expect(pages.reorderedIndices == [0, 3, 1, 2, 4])
    }
    
    @Test("reverse order has changes")
    func reverseOrderHasChanges() {
        var pages = [PageItem].create(pageCount: 4)
        pages.reverse()
        
        #expect(pages.hasChanges == true)
        #expect(pages.reorderedIndices == [3, 2, 1, 0])
    }
}
