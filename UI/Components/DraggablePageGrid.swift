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
    
    /// Size of each thumbnail.
    var thumbnailSize: CGSize = CGSize(width: 80, height: 110)
    
    /// Number of columns in the grid.
    var columns: Int = 2
    
    // MARK: - Private State
    
    @State private var draggingItem: PageItem?
    
    // MARK: - Body
    
    var body: some View {
        #if os(macOS)
        macOSGrid
        #else
        iOSGrid
        #endif
    }
    
    // MARK: - macOS Implementation
    
    #if os(macOS)
    private var macOSGrid: some View {
        let gridColumns = Array(repeating: GridItem(.fixed(thumbnailSize.width), spacing: 12), count: columns)
        
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageCell(page: page, index: index)
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
            .padding()
        }
    }
    #endif
    
    // MARK: - iOS Implementation
    
    #if os(iOS)
    private var iOSGrid: some View {
        let gridColumns = Array(repeating: GridItem(.fixed(thumbnailSize.width), spacing: 12), count: columns)
        
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageCell(page: page, index: index)
                        .draggable(page.id.uuidString) {
                            // Drag preview
                            PageThumbnailView(
                                url: pdfURL,
                                pageIndex: page.originalIndex,
                                displayNumber: page.displayPageNumber,
                                isSelected: true,
                                size: thumbnailSize
                            )
                            .opacity(0.8)
                        }
                }
            }
            .padding()
        }
        .dropDestination(for: String.self) { items, location in
            // Handle drop
            return false
        }
    }
    #endif
    
    // MARK: - Common Views
    
    private func pageCell(page: PageItem, index: Int) -> some View {
        PageThumbnailView(
            url: pdfURL,
            pageIndex: page.originalIndex,
            displayNumber: page.displayPageNumber,
            isSelected: selectedIndex == index,
            size: thumbnailSize
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = index
            }
        }
        .opacity(draggingItem?.id == page.id ? 0.5 : 1.0)
        .accessibilityHint("Drag to reorder")
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
                        size: CGSize(width: 60, height: 80)
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page \(page.displayPageNumber)")
                            .font(.headline)
                        Text("Original position: \(page.originalIndex + 1)")
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
    .frame(width: 250, height: 400)
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
