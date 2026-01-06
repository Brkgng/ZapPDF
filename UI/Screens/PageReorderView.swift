//
//  PageReorderView.swift
//  ZapPDF
//
//  Main view for reordering PDF pages with platform-specific layouts.
//

import SwiftUI
import UniformTypeIdentifiers

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
    
    /// Whether the save panel/sheet is showing.
    @State private var showingSaveConfirmation = false
    
    /// Whether discard confirmation is showing.
    @State private var showingDiscardConfirmation = false
    
    /// Result URL after successful save.
    @State private var savedURL: URL?
    
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
        .overlay {
            if viewModel.isSaving {
                savingOverlay
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
                        pdfURL: viewModel.sourceFile.url,
                        selectedIndex: $viewModel.selectedPageIndex,
                        onMove: viewModel.movePages
                    )
                }
            }
            .frame(minWidth: 280, idealWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(L10n.Operation.Reorder.title)
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
            
            Divider()
                .frame(height: 16)
            
            Button(action: viewModel.resetOrder) {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(!viewModel.hasChanges)
            .help(L10n.Help.resetOrder)
            
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
            Button(L10n.Operation.Reorder.saveReordered) {
                showSavePanel()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
        }
    }
    
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(viewModel.sourceFile.url.deletingPathExtension().lastPathComponent)_reordered.pdf"
        panel.title = L10n.SavePanel.reorderTitle
        panel.message = L10n.SavePanel.reorderMessage
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let result = try await viewModel.save(to: url)
                        savedURL = result
                        dismiss()
                    } catch {
                        // Error is already set in viewModel.errorMessage
                    }
                }
            }
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
                        pdfURL: viewModel.sourceFile.url,
                        selectedIndex: $viewModel.selectedPageIndex,
                        onMove: viewModel.movePages
                    )
                    .environment(\.editMode, .constant(.active))
                }
                
                // Bottom toolbar
                if viewModel.hasChanges {
                    iOSBottomToolbar
                }
            }
            .navigationTitle(L10n.Operation.Reorder.title)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Plural.pages(viewModel.pageCount))
                        .font(.headline)
                    Text(L10n.PageReorder.tapDoneToSave)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(L10n.Action.done) {
                    Task {
                        await saveForSharing()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private func saveForSharing() async {
        do {
            let url = try await viewModel.saveToTemporary()
            // Present share sheet
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true) {
                    dismiss()
                }
            }
        } catch {
            // Error shown via viewModel.errorMessage
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
                        Text(L10n.PageReorder.page(page.displayPageNumber))
                            .font(.headline)
                        
                        PageThumbnailView(
                            url: viewModel.sourceFile.url,
                            pageIndex: page.originalIndex,
                            displayNumber: page.displayPageNumber,
                            isSelected: false,
                            size: CGSize(width: previewWidth, height: previewHeight)
                        )
                        
                        if page.originalIndex != selectedIndex {
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
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: viewModel.saveProgress)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                
                Text(L10n.PageReorder.savingProgress(viewModel.saveProgress))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button(L10n.Action.cancel) {
                    viewModel.cancel()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Helpers
    
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
