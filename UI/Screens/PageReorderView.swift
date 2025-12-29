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
        .alert("Discard Changes?", isPresented: $showingDiscardConfirmation) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Error", isPresented: hasError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
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
                        onMove: viewModel.movePages,
                        columns: 2
                    )
                }
            }
            .frame(minWidth: 220, idealWidth: 280)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Reorder Pages")
    }
    
    private var macOSToolbar: some View {
        HStack {
            // Undo/Redo
            Button(action: viewModel.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .help("Undo (⌘Z)")
            .keyboardShortcut("z", modifiers: .command)
            
            Button(action: viewModel.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .help("Redo (⌘⇧Z)")
            .keyboardShortcut("z", modifiers: [.command, .shift])
            
            Divider()
                .frame(height: 16)
            
            Button(action: viewModel.resetOrder) {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(!viewModel.hasChanges)
            .help("Reset to Original Order")
            
            Spacer()
            
            // Page count
            Text("\(viewModel.pageCount) pages")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Save button
            Button("Save Reordered") {
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
        panel.title = "Save Reordered PDF"
        panel.message = "Choose where to save the reordered PDF"
        
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
            .navigationTitle("Reorder Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
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
                    Text("\(viewModel.pageCount) pages")
                        .font(.headline)
                    Text("Tap Done to save changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
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
        VStack {
            if let selectedIndex = viewModel.selectedPageIndex,
               selectedIndex < viewModel.pages.count {
                let page = viewModel.pages[selectedIndex]
                
                VStack(spacing: 16) {
                    Text("Page \(page.displayPageNumber)")
                        .font(.headline)
                    
                    PageThumbnailView(
                        url: viewModel.sourceFile.url,
                        pageIndex: page.originalIndex,
                        displayNumber: page.displayPageNumber,
                        isSelected: false,
                        size: CGSize(width: 300, height: 400)
                    )
                    
                    if page.originalIndex != selectedIndex {
                        Label("Moved from position \(page.originalIndex + 1)", systemImage: "arrow.triangle.swap")
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
                    Text("Select a page to preview")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading pages...")
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
                
                Text("Saving... \(Int(viewModel.saveProgress * 100))%")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Cancel") {
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
