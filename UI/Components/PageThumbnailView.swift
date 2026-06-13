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
///     pdfFile: pdfFile,
///     pageIndex: page.originalIndex,
///     displayNumber: page.displayPageNumber,
///     isSelected: selectedIndex == index
/// )
/// ```
struct PageThumbnailView: View {
    
    // MARK: - Properties
    
    /// The PDF file to display a page thumbnail for.
    let pdfFile: PDFFile
    
    /// 0-based page index to render.
    let pageIndex: Int
    
    /// 1-based display number for badge.
    let displayNumber: Int
    
    /// Whether this page is currently selected.
    var isSelected: Bool = false
    
    /// Size of the thumbnail.
    var size: CGSize = CGSize(width: 80, height: 110)
    
    /// The rotation to apply to the page.
    var rotation: PageRotation = .none

    /// Reuses an already opened PDF while the reorder screen is visible.
    var thumbnailSession: PDFThumbnailSession? = nil
    
    // MARK: - Private State
    
    @State private var thumbnail: CGImage?
    @State private var isLoading: Bool = true
    @State private var loadingTask: Task<Void, Never>?
    
    private static let renderer = PDFRenderer.shared
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background with selection state
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
            
            // Thumbnail content
            if let thumbnail = thumbnail {
                thumbnailImage(thumbnail)
                    .rotationEffect(.degrees(Double(rotation.degrees)))
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(Double(rotation.degrees)))
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
        .task(id: "\(pdfFile.id)_\(pageIndex)") {
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
            let result: CGImage?
            if let thumbnailSession {
                result = await thumbnailSession.thumbnail(pageIndex: pageIndex, size: renderSize)
            } else {
                result = await Self.renderer.thumbnail(
                    for: pdfFile,
                    pageIndex: pageIndex,
                    size: renderSize
                )
            }
            
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
    let mockFile = PDFFile(url: mockURL, fileName: "sample.pdf", pageCount: 5, fileSize: 1024)
    
    HStack(spacing: 12) {
        PageThumbnailView(
            pdfFile: mockFile,
            pageIndex: 0,
            displayNumber: 1,
            isSelected: false,
            rotation: .none
        )
        
        PageThumbnailView(
            pdfFile: mockFile,
            pageIndex: 1,
            displayNumber: 2,
            isSelected: true
        )
        
        PageThumbnailView(
            pdfFile: mockFile,
            pageIndex: 2,
            displayNumber: 3,
            isSelected: false
        )
    }
    .padding()
}
