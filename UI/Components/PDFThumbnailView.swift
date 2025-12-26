//
//  PDFThumbnailView.swift
//  ZapPDF
//
//  Async thumbnail view for PDF files with loading and error states.
//

import SwiftUI

/// A view that displays a PDF thumbnail with async loading and caching.
///
/// `PDFThumbnailView` loads thumbnails asynchronously using `PDFRenderer`
/// and displays loading/error states appropriately. It automatically cancels
/// any pending thumbnail generation when the view disappears.
///
/// Example:
/// ```swift
/// PDFThumbnailView(pdfFile: selectedFile)
///     .frame(width: 120, height: 160)
///
/// PDFThumbnailView(pdfFile: selectedFile, size: CGSize(width: 80, height: 100), showPageCount: false)
/// ```
struct PDFThumbnailView: View {
    
    // MARK: - Properties
    
    /// The PDF file to display a thumbnail for.
    let pdfFile: PDFFile
    
    /// Size of the thumbnail to generate.
    var size: CGSize = CGSize(width: 120, height: 160)
    
    /// Whether to show a page count badge overlay.
    var showPageCount: Bool = true
    
    /// Corner radius for the thumbnail.
    var cornerRadius: CGFloat = 8
    
    // MARK: - Private State
    
    @State private var thumbnail: CGImage?
    @State private var isLoading: Bool = true
    @State private var loadingTask: Task<Void, Never>?
    
    /// Shared renderer instance for thumbnail generation.
    private static let renderer = PDFRenderer()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.1))
            
            // Content
            if let thumbnail = thumbnail {
                thumbnailImage(thumbnail)
            } else if isLoading {
                loadingView
            } else {
                errorPlaceholder
            }
            
            // Page count badge
            if showPageCount && pdfFile.pageCount > 0 {
                pageCountBadge
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: pdfFile.id) {
            await loadThumbnail()
        }
        .onDisappear {
            cancelLoading()
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        #else
        let uiImage = UIImage(cgImage: cgImage)
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(pdfFile.fileName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
    }
    
    private var pageCountBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(pdfFile.pageCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(4)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadThumbnail() async {
        isLoading = true
        
        // Store the task so we can cancel it if needed
        let task = Task {
            let result = await Self.renderer.thumbnail(
                for: pdfFile.url,
                pageIndex: 0,
                size: size
            )
            
            // Check if task was cancelled before updating state
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
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

// MARK: - Preview

#Preview("Loading State") {
    // For preview, we create a mock URL
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockFile = PDFFile(
        url: mockURL,
        fileName: "Sample Document.pdf",
        pageCount: 5,
        fileSize: 1024 * 1024
    )
    
    return PDFThumbnailView(pdfFile: mockFile)
        .padding()
}

#Preview("Different Sizes") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockFile = PDFFile(
        url: mockURL,
        fileName: "Sample.pdf",
        pageCount: 10,
        fileSize: 2048 * 1024
    )
    
    return HStack(spacing: 20) {
        PDFThumbnailView(pdfFile: mockFile, size: CGSize(width: 60, height: 80))
        PDFThumbnailView(pdfFile: mockFile, size: CGSize(width: 120, height: 160))
        PDFThumbnailView(pdfFile: mockFile, size: CGSize(width: 180, height: 240), showPageCount: false)
    }
    .padding()
}
