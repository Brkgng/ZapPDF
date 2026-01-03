//
//  PDFRendererTests.swift
//  ZapPDFTests
//
//  Unit tests for PDFRenderer.
//

import Testing
import Foundation
import CoreGraphics
@testable import ZapPDF

@Suite("PDFRenderer Tests")
struct PDFRendererTests {
    
    // MARK: - Thumbnail Tests
    
    @Test("Generates thumbnail for valid PDF")
    func generatesThumbnailForValidPDF() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "thumbnail_test_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        let thumbnail = await renderer.thumbnail(
            for: url,
            pageIndex: 0,
            size: CGSize(width: 200, height: 280)
        )
        
        #expect(thumbnail != nil)
    }
    
    @Test("Thumbnail has correct size")
    func thumbnailHasCorrectSize() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "size_test_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        let requestedSize = CGSize(width: 200, height: 280)
        
        let thumbnail = await renderer.thumbnail(
            for: url,
            pageIndex: 0,
            size: requestedSize
        )
        
        #expect(thumbnail != nil)
        
        if let image = thumbnail {
            // The thumbnail should fit within the requested size
            // (may be smaller due to aspect ratio preservation)
            #expect(image.width <= Int(requestedSize.width))
            #expect(image.height <= Int(requestedSize.height))
        }
    }
    
    @Test("Cached thumbnail returned on second call")
    func cachedThumbnailReturnedOnSecondCall() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "cache_test_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        let size = CGSize(width: 100, height: 140)
        
        // First call - generates thumbnail
        let thumbnail1 = await renderer.thumbnail(for: url, pageIndex: 0, size: size)
        #expect(thumbnail1 != nil)
        
        // Cache should have 1 item
        let cacheCount = await renderer.cacheCount
        #expect(cacheCount == 1)
        
        // Second call - should return cached
        let thumbnail2 = await renderer.thumbnail(for: url, pageIndex: 0, size: size)
        #expect(thumbnail2 != nil)
        
        // Cache should still have 1 item (same entry)
        let cacheCount2 = await renderer.cacheCount
        #expect(cacheCount2 == 1)
    }
    
    @Test("Clear cache removes cached thumbnails")
    func clearCacheRemovesCachedThumbnails() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "clear_cache_test_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        
        // Generate a thumbnail
        _ = await renderer.thumbnail(
            for: url,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )
        
        // Verify cache has item
        var cacheCount = await renderer.cacheCount
        #expect(cacheCount == 1)
        
        // Clear cache
        await renderer.clearCache()
        
        // Verify cache is empty
        cacheCount = await renderer.cacheCount
        #expect(cacheCount == 0)
    }
    
    // MARK: - Cache Isolation Tests
    
    @Test("Different sizes create different cache entries")
    func differentSizesCreateDifferentCacheEntries() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "size_cache_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        
        // Request same page at different sizes
        _ = await renderer.thumbnail(for: url, pageIndex: 0, size: CGSize(width: 100, height: 140))
        _ = await renderer.thumbnail(for: url, pageIndex: 0, size: CGSize(width: 200, height: 280))
        
        // Should have 2 separate cache entries
        let cacheCount = await renderer.cacheCount
        #expect(cacheCount == 2)
    }
    
    @Test("Different pages create different cache entries")
    func differentPagesCreateDifferentCacheEntries() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 3, identifier: "page_cache_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        let size = CGSize(width: 100, height: 140)
        
        // Request different pages
        _ = await renderer.thumbnail(for: url, pageIndex: 0, size: size)
        _ = await renderer.thumbnail(for: url, pageIndex: 1, size: size)
        _ = await renderer.thumbnail(for: url, pageIndex: 2, size: size)
        
        // Should have 3 separate cache entries
        let cacheCount = await renderer.cacheCount
        #expect(cacheCount == 3)
    }
    
    // MARK: - In-Flight Task Tests
    
    @Test("In-flight count starts at zero")
    func inFlightCountStartsAtZero() async {
        let renderer = PDFRenderer()
        let count = await renderer.inFlightCount
        #expect(count == 0)
    }
    
    @Test("cancelAllInFlight clears in-flight tasks")
    func cancelAllInFlightClearsInFlightTasks() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "cancel_test_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        
        // Generate a thumbnail (will complete quickly for test PDF)
        _ = await renderer.thumbnail(
            for: url,
            pageIndex: 0,
            size: CGSize(width: 100, height: 140)
        )
        
        // Cancel all in-flight (should be empty after completion)
        await renderer.cancelAllInFlight()
        
        let count = await renderer.inFlightCount
        #expect(count == 0)
    }
    
    // MARK: - Concurrent Request Tests
    
    @Test("Concurrent requests for same thumbnail share work")
    func concurrentRequestsForSameThumbnailShareWork() async throws {
        let identifier = UUID().uuidString
        let url = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "concurrent_\(identifier)")
        defer { PDFTestHelpers.cleanup(url: url) }
        
        let renderer = PDFRenderer()
        let size = CGSize(width: 100, height: 140)
        
        // Start multiple concurrent requests for the same thumbnail
        async let thumb1 = renderer.thumbnail(for: url, pageIndex: 0, size: size)
        async let thumb2 = renderer.thumbnail(for: url, pageIndex: 0, size: size)
        async let thumb3 = renderer.thumbnail(for: url, pageIndex: 0, size: size)
        
        // Wait for all
        let results = await [thumb1, thumb2, thumb3]
        
        // All should return valid thumbnails
        for result in results {
            #expect(result != nil)
        }
        
        // Only one cache entry should exist (not 3)
        let cacheCount = await renderer.cacheCount
        #expect(cacheCount == 1)
    }
}
