//
//  PDFRenderer.swift
//  ZapPDF
//
//  Actor for generating PDF page thumbnails with memory-optimized caching.
//

import Foundation
import PDFKit
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cache Wrapper Classes for NSCache

/// Wrapper for CGImage to use with NSCache (requires AnyObject).
final class CGImageWrapper: NSObject {
    let image: CGImage
    
    /// Memory cost in bytes (width × height × 4 bytes per pixel).
    let cost: Int
    
    init(image: CGImage) {
        self.image = image
        self.cost = image.width * image.height * 4
        super.init()
    }
}

/// Cache key wrapper for NSCache (requires NSObject subclass).
final class ThumbnailCacheKey: NSObject {
    let url: URL
    let pageIndex: Int
    let width: Int
    let height: Int
    
    init(url: URL, pageIndex: Int, width: Int, height: Int) {
        self.url = url
        self.pageIndex = pageIndex
        self.width = width
        self.height = height
        super.init()
    }
    
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(pageIndex)
        hasher.combine(width)
        hasher.combine(height)
        return hasher.finalize()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ThumbnailCacheKey else { return false }
        return url == other.url &&
               pageIndex == other.pageIndex &&
               width == other.width &&
               height == other.height
    }
}

// MARK: - PDFRenderer

/// Actor responsible for generating PDF page thumbnails.
///
/// `PDFRenderer` generates thumbnails at a specified size and caches them
/// using `NSCache` for automatic memory management under pressure.
/// All rendering happens off the main thread with proper cancellation support.
///
/// ## Memory Management
/// - Uses `NSCache` which automatically evicts entries under memory pressure
/// - Platform-specific limits: 50 items / 20 MB on iOS, 100 items / 50 MB on macOS
/// - Tracks in-flight tasks to prevent duplicate renders
/// - Supports cooperative cancellation
///
/// Example:
/// ```swift
/// let renderer = PDFRenderer()
/// if let thumbnail = await renderer.thumbnail(for: pdfURL, pageIndex: 0, size: CGSize(width: 200, height: 280)) {
///     // Use the CGImage
/// }
/// ```
actor PDFRenderer {
    
    // MARK: - Platform-Specific Limits
    
    /// Maximum number of cached thumbnails.
    private static var cacheCountLimit: Int {
        #if os(iOS)
        return 50   // Smaller limit for iOS memory constraints
        #else
        return 100  // Larger limit for macOS
        #endif
    }
    
    /// Maximum total memory for cache in bytes.
    private static var cacheCostLimit: Int {
        #if os(iOS)
        return 20 * 1024 * 1024  // 20 MB on iOS
        #else
        return 50 * 1024 * 1024  // 50 MB on macOS
        #endif
    }
    
    // MARK: - Private Properties
    
    /// NSCache for automatic memory management.
    private let cache: NSCache<ThumbnailCacheKey, CGImageWrapper>
    
    /// Tracks cached keys for count (NSCache doesn't expose count).
    private var cachedKeys: Set<ThumbnailCacheKey> = []
    
    /// Tracks in-flight rendering tasks to prevent duplicate work.
    private var inFlightTasks: [ThumbnailCacheKey: Task<CGImage?, Never>] = [:]
    
    // MARK: - Initialization
    
    init() {
        cache = NSCache<ThumbnailCacheKey, CGImageWrapper>()
        cache.countLimit = Self.cacheCountLimit
        cache.totalCostLimit = Self.cacheCostLimit
    }
    
    // MARK: - Public Methods
    
    /// Generate a thumbnail for a specific page of a PDF.
    ///
    /// This method supports cooperative cancellation. If the calling task is cancelled,
    /// rendering will stop early and return `nil`.
    ///
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Zero-based page index
    ///   - size: Desired size for the thumbnail
    /// - Returns: CGImage of the thumbnail, or nil if generation failed or was cancelled
    func thumbnail(
        for url: URL,
        pageIndex: Int = 0,
        size: CGSize
    ) async -> CGImage? {
        let cacheKey = ThumbnailCacheKey(
            url: url,
            pageIndex: pageIndex,
            width: Int(size.width),
            height: Int(size.height)
        )
        
        // 1. Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached.image
        }
        
        // 2. Check if already rendering this exact thumbnail
        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }
        
        // 3. Check cancellation BEFORE starting expensive work
        guard !Task.isCancelled else { return nil }
        
        // 4. Create task that checks for cancellation
        // Note: Using regular Task (not Task.detached) so it inherits cancellation
        let task = Task<CGImage?, Never>(priority: .utility) { [url, pageIndex, size] in
            // Check cancellation at the start
            guard !Task.isCancelled else { return nil }
            
            let result = Self.renderThumbnail(url: url, pageIndex: pageIndex, size: size)
            
            // Check cancellation after rendering
            guard !Task.isCancelled else { return nil }
            
            return result
        }
        
        // Track in-flight task
        inFlightTasks[cacheKey] = task
        
        // Await result
        let result = await task.value
        
        // Cleanup in-flight tracking
        inFlightTasks.removeValue(forKey: cacheKey)
        
        // Only cache if not cancelled and we got a result
        if let image = result, !Task.isCancelled {
            let wrapper = CGImageWrapper(image: image)
            cache.setObject(wrapper, forKey: cacheKey, cost: wrapper.cost)
            cachedKeys.insert(cacheKey)
        }
        
        return result
    }
    
    /// Clear all cached thumbnails.
    func clearCache() {
        cache.removeAllObjects()
        cachedKeys.removeAll()
    }
    
    /// Get the current number of cached thumbnails.
    var cacheCount: Int {
        cachedKeys.count
    }
    
    /// Cancel all in-flight rendering tasks.
    ///
    /// Call this when navigating away from a view that uses many thumbnails
    /// to immediately stop all pending renders.
    func cancelAllInFlight() {
        for task in inFlightTasks.values {
            task.cancel()
        }
        inFlightTasks.removeAll()
    }
    
    /// Get the current number of in-flight tasks (for debugging).
    var inFlightCount: Int {
        inFlightTasks.count
    }
    
    /// Get the page count of a PDF file securely and asynchronously.
    ///
    /// - Parameter url: URL of the PDF file
    /// - Returns: Number of pages, or 0 if failed
    func pageCount(for url: URL) async -> Int {
        // Activate security-scoped access
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return 0
        }
        
        return document.pageCount
    }
    
    /// Generate both a thumbnail and get page count in a single pass.
    ///
    /// This is more efficient than calling `thumbnail` and `pageCount` separately
    /// as it only opens the PDF file once.
    func generatePreviewData(
        for url: URL,
        size: CGSize
    ) async -> (image: CGImage?, pageCount: Int) {
        // Activate security-scoped access
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return (nil, 0)
        }
        
        let pageCount = document.pageCount
        
        // Reuse the internal render logic but with the ALREADY LOADED document
        // We need to refactor renderThumbnail to accept a document or extract the logic
        // For now, to be safe and minimal, we'll implement the rendering inline here
        // or extract a private helper that takes a PDFPage.
        
        // Let's implement inline to avoid touching existing private methods too much
        // and ensure we use the 'document' we just opened.
        
        guard let page = document.page(at: 0) else {
            return (nil, pageCount)
        }
        
        let image = Self.renderPage(page, size: size)
        
        // Cache the result if successful
        if let image = image {
            let cacheKey = ThumbnailCacheKey(
                url: url,
                pageIndex: 0,
                width: Int(size.width),
                height: Int(size.height)
            )
            let wrapper = CGImageWrapper(image: image)
            cache.setObject(wrapper, forKey: cacheKey, cost: wrapper.cost)
            cachedKeys.insert(cacheKey)
        }
        
        return (image, pageCount)
    }
    
    // MARK: - Private Methods
    
    /// Render a thumbnail for a PDF page.
    ///
    /// This method handles security-scoped resource access for sandboxed environments.
    private static func renderThumbnail(url: URL, pageIndex: Int, size: CGSize) -> CGImage? {
        // Check cancellation before expensive file I/O
        guard !Task.isCancelled else { return nil }
        
        // Activate security-scoped access
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return nil
        }
        
        // Check cancellation after file I/O
        guard !Task.isCancelled else { return nil }
        
        guard let page = document.page(at: pageIndex) else {
            return nil
        }
        
        return renderPage(page, size: size)
    }
    
    /// Helper to render a specific PDF page.
    private static func renderPage(_ page: PDFPage, size: CGSize) -> CGImage? {
        // Get page bounds
        let pageBounds = page.bounds(for: .mediaBox)
        
        // Calculate scale to fit within requested size while maintaining aspect ratio
        let scaleX = size.width / pageBounds.width
        let scaleY = size.height / pageBounds.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = pageBounds.width * scale
        let scaledHeight = pageBounds.height * scale
        
        // Check cancellation before creating context
        guard !Task.isCancelled else { return nil }
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(scaledWidth),
            height: Int(scaledHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        
        // Scale and translate for PDF coordinate system
        context.scaleBy(x: scale, y: scale)
        
        // Draw the PDF page
        #if os(macOS)
        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        page.draw(with: .mediaBox, to: context)
        NSGraphicsContext.restoreGraphicsState()
        #else
        // On iOS, use UIGraphics context
        UIGraphicsPushContext(context)
        page.draw(with: .mediaBox, to: context)
        UIGraphicsPopContext()
        #endif
        
        return context.makeImage()
    }
}
