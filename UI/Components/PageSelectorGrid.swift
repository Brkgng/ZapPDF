//
//  PageSelectorGrid.swift
//  ZapPDF
//
//  Visual grid component for selecting individual pages from a PDF.
//

import SwiftUI

/// A grid view for selecting individual pages from a PDF.
///
/// `PageSelectorGrid` displays page thumbnails in a scrollable grid,
/// allowing users to select/deselect individual pages for extraction.
///
/// Example:
/// ```swift
/// PageSelectorGrid(
///     url: pdfFile.url,
///     pageCount: 10,
///     selectedPages: $selectedPages
/// )
/// ```
struct PageSelectorGrid: View {
    
    // MARK: - Properties
    
    /// URL of the PDF file.
    let url: URL
    
    /// Total number of pages in the PDF.
    let pageCount: Int
    
    /// Binding to selected page numbers (1-indexed).
    @Binding var selectedPages: Set<Int>
    
    /// Size of each thumbnail.
    var thumbnailSize: CGSize = CGSize(width: 70, height: 90)
    
    /// Maximum height for the grid container.
    var maxHeight: CGFloat = 200
    
    // MARK: - Private Properties
    
    #if os(macOS)
    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 8)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 60, maximum: 80), spacing: 8)
    ]
    #endif
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with selection info
            HStack {
                Text(L10n.SplitOptions.selectPagesToExtract)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Quick actions
                HStack(spacing: 12) {
                    Button(L10n.Common.all) {
                        selectAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.caption)
                    
                    Button(L10n.Common.none) {
                        clearSelection()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }
            }
            
            // Scrollable grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...pageCount, id: \.self) { pageNumber in
                        pageCell(for: pageNumber)
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Selection summary
            Text(L10n.SplitOptions.selectedOfTotal(selectedPages.count, pageCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func pageCell(for pageNumber: Int) -> some View {
        let isSelected = selectedPages.contains(pageNumber)
        
        Button {
            toggleSelection(pageNumber)
        } label: {
            ZStack {
                // Thumbnail
                SelectablePageThumbnail(
                    url: url,
                    pageIndex: pageNumber - 1, // Convert to 0-indexed
                    displayNumber: pageNumber,
                    isSelected: isSelected,
                    size: thumbnailSize
                )
                
                // Selection checkbox overlay
                VStack {
                    HStack {
                        selectionCheckmark(isSelected: isSelected)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.PageReorder.page(pageNumber))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    @ViewBuilder
    private func selectionCheckmark(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white.opacity(0.8))
                .frame(width: 20, height: 20)
            
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ pageNumber: Int) {
        if selectedPages.contains(pageNumber) {
            selectedPages.remove(pageNumber)
        } else {
            selectedPages.insert(pageNumber)
        }
    }
    
    private func selectAll() {
        selectedPages = Set(1...pageCount)
    }
    
    private func clearSelection() {
        selectedPages.removeAll()
    }
}

// MARK: - SelectablePageThumbnail

/// A simpler page thumbnail for use in the selector grid.
private struct SelectablePageThumbnail: View {
    let url: URL
    let pageIndex: Int
    let displayNumber: Int
    let isSelected: Bool
    let size: CGSize
    
    @State private var thumbnail: CGImage?
    @State private var isLoading: Bool = true
    
    private static let renderer = PDFRenderer()
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
            
            // Thumbnail content
            if let thumbnail = thumbnail {
                thumbnailImage(thumbnail)
            } else if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(displayNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(isSelected ? 1.0 : 0.7)
        .task(id: "\(url.absoluteString)_\(pageIndex)") {
            await loadThumbnail()
        }
        .onDisappear {
            // Release memory when view scrolls out of visible area.
            // The thumbnail will be re-fetched from cache when scrolling back.
            thumbnail = nil
            isLoading = true
        }
    }
    
    @ViewBuilder
    private func thumbnailImage(_ cgImage: CGImage) -> some View {
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(2)
        #else
        let uiImage = UIImage(cgImage: cgImage)
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(2)
        #endif
    }
    
    private func loadThumbnail() async {
        isLoading = true
        
        let scale: CGFloat = 2.0
        let renderSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let result = await Self.renderer.thumbnail(
            for: url,
            pageIndex: pageIndex,
            size: renderSize
        )
        
        // Only update state if task wasn't cancelled (view still visible)
        guard !Task.isCancelled else { return }
        
        self.thumbnail = result
        self.isLoading = false
    }
}

// MARK: - Preview

#Preview("Page Selector Grid") {
    @Previewable @State var selected: Set<Int> = [1, 3, 5]
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    
    return PageSelectorGrid(
        url: mockURL,
        pageCount: 10,
        selectedPages: $selected
    )
    .padding()
}

