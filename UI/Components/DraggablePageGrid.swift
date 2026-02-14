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
///     pdfFile: viewModel.sourceFile,
///     selectedIndex: $viewModel.selectedPageIndex,
///     onMove: { source, destination in
///         viewModel.movePages(from: source, to: destination)
///     },
///     onRotate: { index, clockwise in
///         viewModel.rotatePage(at: index, clockwise: clockwise)
///     },
///     onDelete: { index in
///         viewModel.deletePage(at: index)
///     }
/// )
/// ```
struct DraggablePageGrid: View {
    
    // MARK: - Properties
    
    /// The pages to display.
    let pages: [PageItem]
    
    /// The source PDF file for thumbnail loading.
    let pdfFile: PDFFile
    
    /// Currently selected page index (binding).
    @Binding var selectedIndex: Int?
    
    /// Callback when pages are moved.
    let onMove: (IndexSet, Int) -> Void
    
    /// Callback when a page should be rotated. Parameters: (index, clockwise).
    var onRotate: ((Int, Bool) -> Void)?
    
    /// Callback when a page should be deleted.
    var onDelete: ((Int) -> Void)?
    
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
                                pdfFile: pdfFile,
                                pageIndex: page.originalIndex,
                                displayNumber: index + 1,
                                isSelected: true,
                                size: size,
                                rotation: page.rotation
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
            pdfFile: pdfFile,
            pageIndex: page.originalIndex,
            displayNumber: index + 1,
            isSelected: selectedIndex == index,
            size: size,
            rotation: page.rotation
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = index
            }
        }
        .contextMenu {
            Button {
                onRotate?(index, false)  // counter-clockwise
            } label: {
                Label(L10n.PageReorder.rotateLeft, systemImage: "rotate.left")
            }
            
            Button {
                onRotate?(index, true)  // clockwise
            } label: {
                Label(L10n.PageReorder.rotateRight, systemImage: "rotate.right")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete?(index)
            } label: {
                Label(L10n.Action.delete, systemImage: "trash")
            }
            .disabled(pages.count <= 1)
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
    let pdfFile: PDFFile
    @Binding var selectedIndex: Int?
    let onMove: (IndexSet, Int) -> Void
    
    /// Callback when a page should be rotated. Parameters: (index, clockwise).
    var onRotate: ((Int, Bool) -> Void)?
    
    /// Callback when a page should be deleted.
    var onDelete: ((Int) -> Void)?
    
    var body: some View {
        List {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                HStack {
                    PageThumbnailView(
                        pdfFile: pdfFile,
                        pageIndex: page.originalIndex,
                        displayNumber: index + 1,
                        isSelected: selectedIndex == index,
                        size: CGSize(width: 60, height: 85),
                        rotation: page.rotation
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.PageReorder.page(index + 1))
                            .font(.headline)
                        Text(L10n.PageReorder.originalPosition(page.originalIndex + 1))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Show rotation indicator if rotated
                        if page.rotation != .none {
                            Text(L10n.PageReorder.rotatedBy(page.rotation.degrees))
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIndex = index
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete?(index)
                    } label: {
                        Label(L10n.Action.delete, systemImage: "trash")
                    }
                    .disabled(pages.count <= 1)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        onRotate?(index, true)  // clockwise
                    } label: {
                        Label(L10n.PageReorder.rotateRight, systemImage: "rotate.right")
                    }
                    .tint(.blue)
                    
                    Button {
                        onRotate?(index, false)  // counter-clockwise
                    } label: {
                        Label(L10n.PageReorder.rotateLeft, systemImage: "rotate.left")
                    }
                    .tint(.indigo)
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
    let mockFile = PDFFile(url: mockURL, fileName: "sample.pdf", pageCount: 6, fileSize: 1024)
    let mockPages = [PageItem].create(pageCount: 6)
    
    DraggablePageGrid(
        pages: mockPages,
        pdfFile: mockFile,
        selectedIndex: .constant(1),
        onMove: { _, _ in }
    )
    .frame(width: 400, height: 500)
}

#Preview("Draggable List - iOS") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockFile = PDFFile(url: mockURL, fileName: "sample.pdf", pageCount: 6, fileSize: 1024)
    let mockPages = [PageItem].create(pageCount: 6)
    
    DraggablePageList(
        pages: mockPages,
        pdfFile: mockFile,
        selectedIndex: .constant(1),
        onMove: { _, _ in }
    )
    .frame(height: 400)
}
