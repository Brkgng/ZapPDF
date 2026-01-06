//
//  PageThumbnailView.swift
//  ZapPDF
//
//  Thumbnail view for individual PDF pages in the reorder interface.
//

import SwiftUI

/// A view that displays a single PDF page thumbnail for reordering.
///
/// `PageThumbnailView` is designed for the page reorder interface,
/// showing page thumbnails with selection state and page number badges.
///
/// Example:
/// ```swift
/// PageThumbnailView(
///     url: pdfFile.url,
///     pageIndex: page.originalIndex,
///     displayNumber: page.displayPageNumber,
///     isSelected: selectedIndex == index
/// )
/// ```
struct PageThumbnailView: View {
    
    // MARK: - Properties
    
    /// URL of the PDF file.
    let url: URL
    
    /// 0-based page index to render.
    let pageIndex: Int
    
    /// 1-based display number for badge.
    let displayNumber: Int
    
    /// Whether this page is currently selected.
    var isSelected: Bool = false
    
    /// Size of the thumbnail.
    var size: CGSize = CGSize(width: 80, height: 110)
    
    // MARK: - Private State
    
    @State private var thumbnail: CGImage?
    @State private var isLoading: Bool = true
    @State private var loadingTask: Task<Void, Never>?
    
    private static let renderer = PDFRenderer()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background with selection state
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
            
            // Thumbnail content
            if let thumbnail = thumbnail {
                thumbnailImage(thumbnail)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Page number badge
            pageNumberBadge
        }
        .frame(width: size.width, height: size.height)
        .overlay(selectionOverlay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.PageReorder.page(displayNumber))
        .accessibilityHint(isSelected ? L10n.Accessibility.selectedTapHint : L10n.Accessibility.tapToSelectHint)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .task(id: "\(url.absoluteString)_\(pageIndex)") {
            await loadThumbnail()
        }
        .onDisappear {
            // Cancel any pending load and release memory
            loadingTask?.cancel()
            loadingTask = nil
            thumbnail = nil  // Release memory when scrolled out
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func thumbnailImage(_ cgImage: CGImage) -> some View {
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(4)
        #else
        let uiImage = UIImage(cgImage: cgImage)
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(4)
        #endif
    }
    
    private var pageNumberBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(displayNumber)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 18)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.accentColor : Color.black.opacity(0.6))
                    )
                    .padding(4)
            }
        }
    }
    
    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, lineWidth: 3)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadThumbnail() async {
        isLoading = true
        
        // Render at 2x for Retina displays
        let scale: CGFloat = 2.0
        let renderSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let task = Task {
            let result = await Self.renderer.thumbnail(
                for: url,
                pageIndex: pageIndex,
                size: renderSize
            )
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.thumbnail = result
                    self.isLoading = false
                }
            }
        }
        
        loadingTask = task
        await task.value
    }
}

// MARK: - Preview

#Preview("Page Thumbnails") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    
    HStack(spacing: 12) {
        PageThumbnailView(
            url: mockURL,
            pageIndex: 0,
            displayNumber: 1,
            isSelected: false
        )
        
        PageThumbnailView(
            url: mockURL,
            pageIndex: 1,
            displayNumber: 2,
            isSelected: true
        )
        
        PageThumbnailView(
            url: mockURL,
            pageIndex: 2,
            displayNumber: 3,
            isSelected: false
        )
    }
    .padding()
}
