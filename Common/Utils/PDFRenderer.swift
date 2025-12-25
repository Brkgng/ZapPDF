//
//  PDFRenderer.swift
//  ZapPDF
//
//  Actor for generating PDF page thumbnails with caching.
//

import Foundation
import PDFKit
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Actor responsible for generating PDF page thumbnails.
///
/// `PDFRenderer` generates thumbnails at a specified size and caches them
/// in memory for efficient reuse. All rendering happens off the main thread.
///
/// Example:
/// ```swift
/// let renderer = PDFRenderer()
/// if let thumbnail = await renderer.thumbnail(for: pdfURL, pageIndex: 0, size: CGSize(width: 200, height: 280)) {
///     // Use the CGImage
/// }
/// ```
actor PDFRenderer {
    
    // MARK: - Cache Key
    
    private struct CacheKey: Hashable {
        let url: URL
        let pageIndex: Int
        let width: Int
        let height: Int
    }
    
    // MARK: - Private Properties
    
    private var cache: [CacheKey: CGImage] = [:]
    private let maxCacheSize = 100
    
    // MARK: - Public Methods
    
    /// Generate a thumbnail for a specific page of a PDF.
    ///
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageIndex: Zero-based page index
    ///   - size: Desired size for the thumbnail
    /// - Returns: CGImage of the thumbnail, or nil if generation failed
    func thumbnail(
        for url: URL,
        pageIndex: Int = 0,
        size: CGSize
    ) async -> CGImage? {
        let cacheKey = CacheKey(
            url: url,
            pageIndex: pageIndex,
            width: Int(size.width),
            height: Int(size.height)
        )
        
        // Check cache first
        if let cached = cache[cacheKey] {
            return cached
        }
        
        // Generate thumbnail off main thread
        let result = await Task.detached(priority: .utility) { [url, pageIndex, size] in
            return Self.renderThumbnail(url: url, pageIndex: pageIndex, size: size)
        }.value
        
        // Cache the result
        if let image = result {
            addToCache(key: cacheKey, image: image)
        }
        
        return result
    }
    
    /// Clear all cached thumbnails.
    func clearCache() {
        cache.removeAll()
    }
    
    /// Get the current number of cached thumbnails.
    var cacheCount: Int {
        cache.count
    }
    
    // MARK: - Private Methods
    
    private func addToCache(key: CacheKey, image: CGImage) {
        // Simple LRU-ish eviction: remove oldest entries if cache is too large
        if cache.count >= maxCacheSize {
            // Remove first 20% of entries
            let removeCount = maxCacheSize / 5
            let keysToRemove = Array(cache.keys.prefix(removeCount))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        cache[key] = image
    }
    
    /// Render a thumbnail for a PDF page.
    private static func renderThumbnail(url: URL, pageIndex: Int, size: CGSize) -> CGImage? {
        // Try to access the URL with security scope
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return nil
        }
        
        guard let page = document.page(at: pageIndex) else {
            return nil
        }
        
        // Get page bounds
        let pageBounds = page.bounds(for: .mediaBox)
        
        // Calculate scale to fit within requested size while maintaining aspect ratio
        let scaleX = size.width / pageBounds.width
        let scaleY = size.height / pageBounds.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = pageBounds.width * scale
        let scaledHeight = pageBounds.height * scale
        
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
