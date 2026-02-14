//
//  PageReorderView.swift
//  ZapPDF
//
//  Main view for reordering PDF pages with platform-specific layouts.
//

import SwiftUI

/// Main view for reordering pages in a PDF document.
///
/// `PageReorderView` provides platform-specific layouts:
/// - **macOS**: Split view with preview panel on left, draggable grid on right
/// - **iOS**: Full-screen grid with navigation toolbar
///
/// Example:
/// ```swift
/// PageReorderView(file: selectedPDF)
/// ```
struct PageReorderView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: PageReorderViewModel
    @Environment(\.dismiss) private var dismiss
    
    /// Whether to show processing flow for saving edits.
    @State private var showProcessingView = false
    
    /// Processing options for edit pages operation.
    @State private var processingOptions: ProcessingOptions?
    
    /// Whether discard confirmation is showing.
    @State private var showingDiscardConfirmation = false
    
    // MARK: - Initialization
    
    init(file: PDFFile) {
        _viewModel = StateObject(wrappedValue: PageReorderViewModel(file: file))
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .task {
            await viewModel.loadPages()
        }
        .navigationDestination(isPresented: $showProcessingView) {
            if let options = processingOptions {
                ProcessingView(
                    action: .editPages,
                    files: [viewModel.sourceFile],
                    options: options
                )
            }
        }
        .alert(L10n.PageReorder.discardChangesTitle, isPresented: $showingDiscardConfirmation) {
            Button(L10n.PageReorder.discard, role: .destructive) {
                dismiss()
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.PageReorder.discardChangesMessage)
        }
        .alert(L10n.Common.errorTitle, isPresented: hasError) {
            Button(L10n.Action.ok) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? L10n.Common.errorOccurred)
        }
    }
    
    // MARK: - macOS Layout
    
    #if os(macOS)
    private var macOSLayout: some View {
        HSplitView {
            // Left: Preview Panel
            previewPanel
                .frame(minWidth: 300, idealWidth: 400)
            
            // Right: Page Grid
            VStack(spacing: 0) {
                // Toolbar area
                macOSToolbar
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Grid
                if viewModel.isLoadingPages {
                    loadingView
                } else {
                    DraggablePageGrid(
                        pages: viewModel.pages,
                        pdfFile: viewModel.sourceFile,
                        selectedIndex: $viewModel.selectedPageIndex,
                        onMove: viewModel.movePages,
                        onRotate: { index, clockwise in
                            viewModel.rotatePage(at: index, clockwise: clockwise)
                        },
                        onDelete: { index in
                            viewModel.deletePage(at: index)
                        }
                    )
                }
            }
            .frame(minWidth: 280, idealWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(L10n.Operation.EditPages.title)
    }
    
    private var macOSToolbar: some View {
        HStack {
            // Undo/Redo
            Button(action: viewModel.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .help(L10n.Help.undo)
            .keyboardShortcut("z", modifiers: .command)
            
            Button(action: viewModel.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .help(L10n.Help.redo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            

            
            Button(action: viewModel.rotateSelectedPageCounterClockwise) {
                Image(systemName: "rotate.left")
            }
            .disabled(!viewModel.canRotateSelectedPage)
            .help(L10n.Help.rotateLeft)
            .keyboardShortcut("l", modifiers: .command)
            
            Button(action: viewModel.rotateSelectedPageClockwise) {
                Image(systemName: "rotate.right")
            }
            .disabled(!viewModel.canRotateSelectedPage)
            .help(L10n.Help.rotateRight)
            .keyboardShortcut("r", modifiers: .command)
            
            Divider()
                .frame(height: 16)
            
            Button(action: viewModel.deleteSelectedPage) {
                Image(systemName: "trash")
            }
            .disabled(!viewModel.canDeleteSelectedPage)
            .help(L10n.Help.deletePage)
            .keyboardShortcut(.delete, modifiers: [])
            
            Spacer()
            
            // Page count
            Text(L10n.Plural.pages(viewModel.pageCount))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Save button
            Button(L10n.Operation.EditPages.save) {
                startEditProcessing()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasChanges)
        }
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoadingPages {
                    loadingView
                } else {
                    // Use the list-based approach for better iOS drag experience
                    DraggablePageList(
                        pages: viewModel.pages,
                        pdfFile: viewModel.sourceFile,
                        selectedIndex: $viewModel.selectedPageIndex,
                        onMove: viewModel.movePages,
                        onRotate: { index, clockwise in
                            viewModel.rotatePage(at: index, clockwise: clockwise)
                        },
                        onDelete: { index in
                            viewModel.deletePage(at: index)
                        }
                    )
                    .environment(\.editMode, .constant(.active))
                }
                
                // Bottom toolbar
                if viewModel.hasChanges {
                    iOSBottomToolbar
                }
            }
            .navigationTitle(L10n.Operation.EditPages.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel) {
                        if viewModel.hasChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: viewModel.undo) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!viewModel.canUndo)
                        
                        Button(action: viewModel.redo) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!viewModel.canRedo)
                    }
                }
            }
        }
    }
    
    private var iOSBottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Rotation controls (only visible when page is selected)
                if viewModel.canRotateSelectedPage {
                    HStack(spacing: 20) {
                        Button(action: viewModel.rotateSelectedPageCounterClockwise) {
                            Image(systemName: "rotate.left")
                                .font(.title3)
                        }
                        
                        Button(action: viewModel.rotateSelectedPageClockwise) {
                            Image(systemName: "rotate.right")
                                .font(.title3)
                        }
                        
                        Button(action: viewModel.deleteSelectedPage) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.Plural.pages(viewModel.pageCount))
                        .font(.headline)
                    Text(L10n.PageReorder.tapDoneToSave)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(L10n.Action.done) {
                    startEditProcessing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasChanges)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
    }
    #endif
    
    // MARK: - Common Views
    
    private var previewPanel: some View {
        GeometryReader { geometry in
            VStack {
                if let selectedIndex = viewModel.selectedPageIndex,
                   selectedIndex < viewModel.pages.count {
                    let page = viewModel.pages[selectedIndex]
                    
                    // Calculate responsive preview size
                    let maxWidth = geometry.size.width - 48
                    let maxHeight = geometry.size.height - 120
                    let aspectRatio: CGFloat = 0.707 // A4
                    
                    // Fit within bounds maintaining aspect ratio
                    let widthFromHeight = maxHeight * aspectRatio
                    let previewWidth = min(maxWidth, widthFromHeight)
                    let previewHeight = previewWidth / aspectRatio
                    
                    VStack(spacing: 16) {
                        Text(L10n.PageReorder.pageOf(selectedIndex + 1, viewModel.pages.count))
                            .font(.headline)
                        
                        PageThumbnailView(
                            pdfFile: viewModel.sourceFile,
                            pageIndex: page.originalIndex,
                            displayNumber: selectedIndex + 1,
                            isSelected: false,
                            size: CGSize(width: previewWidth, height: previewHeight),
                            rotation: page.rotation
                        )
                        
                        if viewModel.pages.isManuallyReordered(at: selectedIndex) {
                            Label(L10n.PageReorder.movedFrom(page.originalIndex + 1), systemImage: "arrow.triangle.swap")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L10n.PageReorder.selectPageToPreview)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.gray.opacity(0.05))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L10n.PageReorder.loadingPages)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func startEditProcessing() {
        guard viewModel.hasChanges else { return }
        
        processingOptions = .editPages(
            file: viewModel.sourceFile,
            newOrder: viewModel.pages.reorderedIndices,
            rotations: viewModel.pages.rotationsMap,
            outputFileName: nil
        )
        showProcessingView = true
    }
    
    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Preview

#Preview("PageReorderView") {
    let mockURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    let mockFile = PDFFile(
        url: mockURL,
        fileName: "Sample.pdf",
        pageCount: 10,
        fileSize: 1024 * 100
    )
    
    PageReorderView(file: mockFile)
}
