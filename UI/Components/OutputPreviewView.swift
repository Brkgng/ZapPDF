//
//  OutputPreviewView.swift
//  ZapPDF
//
//  Preview component for displaying output PDF thumbnail on completion screen.
//

import SwiftUI
import PDFKit

/// A view that displays a preview thumbnail of an output PDF file.
///
/// `OutputPreviewView` shows the first page of a completed PDF operation result,
/// providing visual confirmation before saving. It loads thumbnails asynchronously
/// using the shared `PDFRenderer` actor.
///
/// Example:
/// ```swift
/// OutputPreviewView(url: outputPDFURL)
///     .frame(width: 180, height: 240)
/// ```
struct OutputPreviewView: View {
    
    // MARK: - Properties
    
    /// URL of the output PDF file to preview.
    let url: URL
    
    /// Size of the preview thumbnail.
    var size: CGSize = CGSize(width: 180, height: 240)
    
    /// Corner radius for the preview.
    var cornerRadius: CGFloat = 12
    
    // MARK: - Private State
    
    @Environment(\.displayScale) private var displayScale
    
    @State private var thumbnail: CGImage?
    @State private var isLoading: Bool = true
    @State private var pageCount: Int = 0
    @State private var loadingTask: Task<Void, Never>?
    @State private var debouncedSize: CGSize = .zero
    @State private var debounceTask: Task<Void, Never>?
    
    /// Shared renderer instance for thumbnail generation.
    private static let renderer = PDFRenderer.shared
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background with shadow
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.95))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Content
            if let thumbnail = thumbnail {
                thumbnailImage(thumbnail)
            } else if isLoading {
                loadingView
            } else {
                errorPlaceholder
            }
            
            // Page count badge
            if pageCount > 0 {
                pageCountBadge
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: url.absoluteString) {
            // Initial load
            debouncedSize = size
            await loadPreview()
        }
        .onChange(of: size) { _, newSize in
            // Debounce size changes to avoid re-rendering during resize drag
            debounceTask?.cancel()
            debounceTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled && newSize != debouncedSize {
                        debouncedSize = newSize
                        await loadPreview()
                    }
                } catch {
                    // Cancelled - ignore
                }
            }
        }
        .onDisappear {
            cancelLoading()
            debounceTask?.cancel()
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))
            .padding(4)
        #else
        let uiImage = UIImage(cgImage: cgImage)
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))
            .padding(4)
        #endif
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.0)
            Text(L10n.Processing.previewLoading)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(L10n.Processing.previewNotAvailable)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
        .padding()
    }
    
    private var pageCountBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(L10n.Processing.outputPages(pageCount))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(8)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPreview() async {
        // Cancel any existing load to prevent race conditions
        cancelLoading()
        
        isLoading = true
        
        let scale = displayScale
        let renderSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        // Use detached task to ensure we don't block main thread
        // while allowing concurrent execution
        let task = Task {
            // Check cancellation
            guard !Task.isCancelled else { return }
            
            // Generate both thumbnail and page count in a single pass
            // This is efficient (opens file once) and secure
            let (thumbnailResult, pageCountResult) = await Self.renderer.generatePreviewData(
                for: url,
                size: renderSize
            )
            
            if !Task.isCancelled {
                // Update state on main actor
                await MainActor.run {
                    self.thumbnail = thumbnailResult
                    self.pageCount = pageCountResult
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

#Preview("Output Preview - Loading") {
    let mockURL = URL(fileURLWithPath: "/tmp/output.pdf")
    
    return OutputPreviewView(url: mockURL)
        .padding()
}

#Preview("Output Preview - Different Sizes") {
    let mockURL = URL(fileURLWithPath: "/tmp/output.pdf")
    
    return HStack(spacing: 20) {
        OutputPreviewView(url: mockURL, size: CGSize(width: 120, height: 160))
        OutputPreviewView(url: mockURL, size: CGSize(width: 180, height: 240))
    }
    .padding()
}
