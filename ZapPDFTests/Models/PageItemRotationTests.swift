//
//  PageItemRotationTests.swift
//  ZapPDFTests
//
//  Unit tests for PageRotation enum and rotation-related PageItem functionality.
//

import Testing
@testable import ZapPDF

@Suite("PageRotation Tests")
struct PageRotationTests {
    
    // MARK: - Rotation Enum Tests
    
    @Test("Rotate clockwise cycles through all states")
    func rotateClockwiseCyclesThroughAllStates() {
        var rotation = PageRotation.none
        
        rotation.rotateClockwise()
        #expect(rotation == .clockwise90)
        
        rotation.rotateClockwise()
        #expect(rotation == .clockwise180)
        
        rotation.rotateClockwise()
        #expect(rotation == .clockwise270)
        
        rotation.rotateClockwise()
        #expect(rotation == .none)  // Wraps back to none
    }
    
    @Test("Rotate counter-clockwise cycles through all states")
    func rotateCounterClockwiseCyclesThroughAllStates() {
        var rotation = PageRotation.none
        
        rotation.rotateCounterClockwise()
        #expect(rotation == .clockwise270)
        
        rotation.rotateCounterClockwise()
        #expect(rotation == .clockwise180)
        
        rotation.rotateCounterClockwise()
        #expect(rotation == .clockwise90)
        
        rotation.rotateCounterClockwise()
        #expect(rotation == .none)  // Wraps back to none
    }
    
    @Test("Degrees property returns correct values")
    func degreesPropertyReturnsCorrectValues() {
        #expect(PageRotation.none.degrees == 0)
        #expect(PageRotation.clockwise90.degrees == 90)
        #expect(PageRotation.clockwise180.degrees == 180)
        #expect(PageRotation.clockwise270.degrees == 270)
    }
    
    @Test("Four clockwise rotations returns to original")
    func fourClockwiseRotationsReturnsToOriginal() {
        var rotation = PageRotation.none
        
        for _ in 0..<4 {
            rotation.rotateClockwise()
        }
        
        #expect(rotation == .none)
    }
    
    @Test("Four counter-clockwise rotations returns to original")
    func fourCounterClockwiseRotationsReturnsToOriginal() {
        var rotation = PageRotation.none
        
        for _ in 0..<4 {
            rotation.rotateCounterClockwise()
        }
        
        #expect(rotation == .none)
    }
}

@Suite("PageItem Rotation Integration Tests")
struct PageItemRotationIntegrationTests {
    
    // MARK: - hasChanges with Rotation
    
    @Test("hasChanges returns true when page is rotated")
    func hasChangesReturnsTrueWhenRotated() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Initially no changes
        #expect(pages.hasChanges == false)
        
        // Rotate first page
        pages[0].rotation = .clockwise90
        
        // Now has changes
        #expect(pages.hasChanges == true)
    }
    
    @Test("hasChanges returns true for rotation even with original order")
    func hasChangesReturnsTrueForRotationEvenWithOriginalOrder() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Keep original order but rotate middle page
        pages[2].rotation = .clockwise180
        
        #expect(pages.hasChanges == true)
    }
    
    @Test("hasChanges returns false when rotation is reset to none")
    func hasChangesReturnsFalseWhenRotationResetToNone() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Rotate then reset
        pages[1].rotation = .clockwise90
        pages[1].rotation = .none
        
        #expect(pages.hasChanges == false)
    }
    
    // MARK: - rotationsMap Tests
    
    @Test("rotationsMap returns only rotated pages")
    func rotationsMapReturnsOnlyRotatedPages() {
        var pages = [PageItem].create(pageCount: 5)
        
        // Rotate pages 1 and 3 (0-indexed)
        pages[1].rotation = .clockwise90
        pages[3].rotation = .clockwise270
        
        let rotations = pages.rotationsMap
        
        #expect(rotations.count == 2)
        #expect(rotations[1] == .clockwise90)
        #expect(rotations[3] == .clockwise270)
        #expect(rotations[0] == nil)
        #expect(rotations[2] == nil)
    }
    
    @Test("rotationsMap is empty when no rotations")
    func rotationsMapIsEmptyWhenNoRotations() {
        let pages = [PageItem].create(pageCount: 4)
        
        #expect(pages.rotationsMap.isEmpty)
    }
    
    @Test("rotationsMap uses original indices as keys")
    func rotationsMapUsesOriginalIndicesAsKeys() {
        var pages = [PageItem].create(pageCount: 4)
        
        // Reorder: move page 0 to end
        let movedPage = pages.remove(at: 0)
        pages.append(movedPage)
        
        // Rotate the moved page (now at index 3, but originalIndex is 0)
        pages[3].rotation = .clockwise90
        
        let rotations = pages.rotationsMap
        
        #expect(rotations.count == 1)
        #expect(rotations[0] == .clockwise90)  // Key is originalIndex (0), not current position (3)
    }
    
    // MARK: - isRotated Property
    
    @Test("isRotated returns correct value")
    func isRotatedReturnsCorrectValue() {
        var page = PageItem(originalIndex: 0)
        
        #expect(page.isRotated == false)
        
        page.rotation = .clockwise90
        #expect(page.isRotated == true)
        
        page.rotation = .none
        #expect(page.isRotated == false)
    }
}
