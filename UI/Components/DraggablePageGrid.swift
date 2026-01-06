//
//  DraggablePageGrid.swift
//  ZapPDF
//
//  Reorderable grid of page thumbnails with cross-platform drag-and-drop.
//

import SwiftUI
import UniformTypeIdentifiers

/// A grid view that displays page thumbnails and supports drag-and-drop reordering.
///
/// `DraggablePageGrid` provides platform-specific drag-and-drop implementations:
/// - **macOS**: Uses `onDrag` and `onDrop` modifiers for traditional drag behavior
/// - **iOS**: Uses `List` with `onMove` for long-press drag reordering
///
/// Thumbnails are dynamically sized based on available container width.
///
/// Example:
/// ```swift
/// DraggablePageGrid(
///     pages: viewModel.pages,
///     pdfURL: viewModel.sourceFile.url,
///     selectedIndex: $viewModel.selectedPageIndex,
///     onMove: { source, destination in
///         viewModel.movePages(from: source, to: destination)
///     }
/// )
/// ```
struct DraggablePageGrid: View {
    
    // MARK: - Properties
    
    /// The pages to display.
    let pages: [PageItem]
    
    /// URL of the source PDF for thumbnail loading.
    let pdfURL: URL
    
    /// Currently selected page index (binding).
    @Binding var selectedIndex: Int?
    
    /// Callback when pages are moved.
    let onMove: (IndexSet, Int) -> Void
    
    // MARK: - Configuration Constants
    
    /// Minimum thumbnail width.
    private let minThumbnailWidth: CGFloat = 100
    
    /// Maximum thumbnail width.
    private let maxThumbnailWidth: CGFloat = 160
    
    /// Spacing between grid items.
    private let gridSpacing: CGFloat = 16
    
    /// A4 aspect ratio (width / height).
    private let aspectRatio: CGFloat = 0.707
    
    // MARK: - Private State
    
    @State private var draggingItem: PageItem?
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            #if os(macOS)
            macOSGrid(in: geometry)
            #else
            iOSGrid(in: geometry)
            #endif
        }
    }
    
    // MARK: - Size Calculation
    
    /// Calculate thumbnail size based on container width.
    private func calculateThumbnailSize(for containerWidth: CGFloat) -> CGSize {
        let padding: CGFloat = gridSpacing * 2
        let availableWidth = containerWidth - padding
        
        // Calculate number of columns that fit
        let columnCount = max(2, Int(availableWidth / (minThumbnailWidth + gridSpacing)))
        
        // Calculate actual thumbnail width
        let totalSpacing = CGFloat(columnCount - 1) * gridSpacing
        let thumbnailWidth = (availableWidth - totalSpacing) / CGFloat(columnCount)
        let clampedWidth = min(max(thumbnailWidth, minThumbnailWidth), maxThumbnailWidth)
        
        // Calculate height maintaining aspect ratio
        let thumbnailHeight = clampedWidth / aspectRatio
        
        return CGSize(width: clampedWidth, height: thumbnailHeight)
    }
    
    /// Calculate number of columns based on container width.
    private func calculateColumnCount(for containerWidth: CGFloat) -> Int {
        let padding: CGFloat = gridSpacing * 2
        let availableWidth = containerWidth - padding
        return max(2, Int(availableWidth / (minThumbnailWidth + gridSpacing)))
    }
    
    // MARK: - macOS Implementation
    
    #if os(macOS)
    private func macOSGrid(in geometry: GeometryProxy) -> some View {
        let size = calculateThumbnailSize(for: geometry.size.width)
        let columnCount = calculateColumnCount(for: geometry.size.width)
        let gridColumns = Array(repeating: GridItem(.fixed(size.width), spacing: gridSpacing), count: columnCount)
        
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageCell(page: page, index: index, size: size)
                        .onDrag {
                            self.draggingItem = page
                            return NSItemProvider(object: page.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: PageDropDelegate(
                            item: page,
                            pages: pages,
                            draggingItem: $draggingItem,
                            onMove: onMove
                        ))
                }
            }
            .padding(gridSpacing)
        }
    }
    #endif
    
    // MARK: - iOS Implementation
    
    #if os(iOS)
    private func iOSGrid(in geometry: GeometryProxy) -> some View {
        let size = calculateThumbnailSize(for: geometry.size.width)
        let columnCount = calculateColumnCount(for: geometry.size.width)
        let gridColumns = Array(repeating: GridItem(.fixed(size.width), spacing: gridSpacing), count: columnCount)
        
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageCell(page: page, index: index, size: size)
                        .draggable(page.id.uuidString) {
                            // Drag preview
                            PageThumbnailView(
                                url: pdfURL,
                                pageIndex: page.originalIndex,
                                displayNumber: page.displayPageNumber,
                                isSelected: true,
                                size: size
                            )
                            .opacity(0.8)
                        }
                }
            }
            .padding(gridSpacing)
        }
        .dropDestination(for: String.self) { items, location in
            return false
        }
    }
    #endif
    
    // MARK: - Common Views
    
    private func pageCell(page: PageItem, index: Int, size: CGSize) -> some View {
        PageThumbnailView(
            url: pdfURL,
            pageIndex: page.originalIndex,
            displayNumber: page.displayPageNumber,
            isSelected: selectedIndex == index,
            size: size
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = index
            }
        }
        .opacity(draggingItem?.id == page.id ? 0.5 : 1.0)
        .accessibilityHint(L10n.Accessibility.dragHandle)
    }
}

// MARK: - macOS Drop Delegate

#if os(macOS)
struct PageDropDelegate: DropDelegate {
    let item: PageItem
    let pages: [PageItem]
    @Binding var draggingItem: PageItem?
    let onMove: (IndexSet, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = pages.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = pages.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
#endif

// MARK: - iOS List-based Alternative

/// Alternative iOS implementation using List for better native drag-and-drop.
struct DraggablePageList: View {
    let pages: [PageItem]
    let pdfURL: URL
    @Binding var selectedIndex: Int?
    let onMove: (IndexSet, Int) -> Void
    
    var body: some View {
        List {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                HStack {
                    PageThumbnailView(
                        url: pdfURL,
                        pageIndex: page.originalIndex,
                        displayNumber: page.displayPageNumber,
                        isSelected: selectedIndex == index,
                        size: CGSize(width: 60, height: 85)
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.PageReorder.page(page.displayPageNumber))
                            .font(.headline)
                        Text(L10n.PageReorder.originalPosition(page.originalIndex + 1))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIndex = index
                }
                .listRowBackground(
                    selectedIndex == index
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Draggable Grid - macOS") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockPages = [PageItem].create(pageCount: 6)
    
    DraggablePageGrid(
        pages: mockPages,
        pdfURL: mockURL,
        selectedIndex: .constant(1),
        onMove: { _, _ in }
    )
    .frame(width: 400, height: 500)
}

#Preview("Draggable List - iOS") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockPages = [PageItem].create(pageCount: 6)
    
    DraggablePageList(
        pages: mockPages,
        pdfURL: mockURL,
        selectedIndex: .constant(1),
        onMove: { _, _ in }
    )
    .frame(height: 400)
}
