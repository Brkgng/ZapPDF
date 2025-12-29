//
//  DashboardView.swift
//  ZapPDF
//
//  Main dashboard for file selection and action triggering.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - DashboardView

/// Main dashboard view for file selection and PDF operations.
///
/// Provides:
/// - Drag-and-drop zone for adding PDF files
/// - File list with reordering and deletion
/// - Action buttons for available operations
/// - Navigation to ProcessingView when action starts
/// - Paywall sheet when usage exhausted
///
/// Example:
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         DashboardView()
///     }
/// }
/// ```
struct DashboardView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = DashboardViewModel()
    
    @State private var showFilePicker = false
    @State private var isDropTargeted = false
    @State private var selectedAction: UserAction?
    @State private var processingOptions: ProcessingOptions?
    @State private var showProcessingView = false
    @State private var showSplitOptions = false
    @State private var showReorderView = false
    @State private var splitMode: PDFSplitter.SplitMode = .splitEvery(n: 1)
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("ZapPDF")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar {
                    toolbarContent
                }
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImport(result)
                }
                .sheet(isPresented: $viewModel.showPaywall) {
                    PaywallView()
                }
                .navigationDestination(isPresented: $showProcessingView) {
                    if let action = selectedAction, let options = processingOptions {
                        ProcessingView(
                            action: action,
                            files: viewModel.selectedFiles,
                            options: options
                        )
                    }
                }
                .sheet(isPresented: $showSplitOptions) {
                    SplitOptionsSheet(
                        pageCount: viewModel.selectedFiles.first?.pageCount ?? 0,
                        splitMode: $splitMode
                    ) {
                        startAction(.split, options: .split(mode: splitMode))
                    }
                }
                .navigationDestination(isPresented: $showReorderView) {
                    if let file = viewModel.selectedFiles.first {
                        PageReorderView(file: file)
                    }
                }
                .alert("Error", isPresented: hasError) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? "An error occurred")
                }
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.hasFiles {
            fileListContent
        } else {
            emptyStateContent
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateContent: some View {
        FileDropZone(
            isEmpty: true,
            isTargeted: $isDropTargeted
        ) { urls in
            Task {
                await viewModel.addFiles(urls: urls)
            }
        } onPickerRequested: {
            showFilePicker = true
        }
        .padding()
    }
    
    // MARK: - File List Content
    
    private var fileListContent: some View {
        VStack(spacing: 0) {
            // File list
            FileDropZoneWithContent(
                isEmpty: false,
                isTargeted: $isDropTargeted,
                onFilesDropped: { urls in
                    Task {
                        await viewModel.addFiles(urls: urls)
                    }
                },
                onPickerRequested: {
                    showFilePicker = true
                }
            ) {
                fileList
            }
            .padding()
            
            Divider()
            
            // Summary and actions
            bottomBar
        }
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        List {
            ForEach(viewModel.selectedFiles) { file in
                PDFFileRow(pdfFile: file)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeFile(file)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                viewModel.removeFiles(at: indexSet)
            }
            .onMove { source, destination in
                viewModel.reorderFiles(from: source, to: destination)
            }
        }
        .listStyle(.inset)
        #if os(macOS)
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        #endif
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Summary
            HStack {
                Text("\(viewModel.selectedFiles.count) files")
                    .font(.subheadline)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("\(viewModel.totalPageCount) pages")
                    .font(.subheadline)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(viewModel.formattedTotalSize)
                    .font(.subheadline)
                
                Spacer()
                
                Button {
                    viewModel.clearAll()
                } label: {
                    Text("Clear All")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            .foregroundColor(.secondary)
            
            // Action buttons
            actionButtonsRow
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }
    
    // MARK: - Action Buttons Row
    
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Merge button
            StyledActionButton(
                action: .merge,
                isEnabled: viewModel.canPerform(action: .merge)
            ) {
                handleActionTap(.merge)
            }
            
            // Split button
            StyledActionButton(
                action: .split,
                isEnabled: viewModel.canPerform(action: .split)
            ) {
                handleActionTap(.split)
            }
            
            // Reorder button
            StyledActionButton(
                action: .reorder,
                isEnabled: viewModel.canPerform(action: .reorder)
            ) {
                handleActionTap(.reorder)
            }
            
            // Convert button (Pro)
            StyledActionButton(
                action: .convert,
                isEnabled: viewModel.canPerform(action: .convert)
            ) {
                handleActionTap(.convert)
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFilePicker = true
            } label: {
                Label("Add Files", systemImage: "plus")
            }
        }
        
        #if os(iOS)
        if viewModel.hasFiles {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        #endif
    }
    
    // MARK: - Actions
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Start security-scoped access (for file picker, URLs may need access)
            let accessibleURLs = urls.compactMap { url -> URL? in
                guard url.startAccessingSecurityScopedResource() else { return nil }
                return url
            }
            
            Task {
                await viewModel.addFiles(urls: accessibleURLs)
                
                // Stop accessing after files are loaded
                for url in accessibleURLs {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
        case .failure(let error):
            viewModel.errorMessage = "Failed to import files: \(error.localizedDescription)"
        }
    }
    
    private func handleActionTap(_ action: UserAction) {
        Task {
            let canProceed = await viewModel.prepareAction(action)
            
            if canProceed {
                await MainActor.run {
                    selectedAction = action
                    
                    switch action {
                    case .merge:
                        // Show processing directly for merge
                        startAction(.merge, options: .merge(outputFileName: "Merged"))
                        
                    case .split:
                        // Show split options sheet
                        showSplitOptions = true
                        
                    case .reorder:
                        // Show reorder view
                        showReorderView = true
                        
                    case .convert:
                        // TODO: Show convert options sheet in future
                        viewModel.errorMessage = "Convert is coming soon!"
                    }
                }
            }
        }
    }
    
    private func startAction(_ action: UserAction, options: ProcessingOptions) {
        selectedAction = action
        processingOptions = options
        showProcessingView = true
    }
    
    // MARK: - Helpers
    
    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Split Options Sheet

/// Sheet for configuring split options.
struct SplitOptionsSheet: View {
    let pageCount: Int
    @Binding var splitMode: PDFSplitter.SplitMode
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption = 0
    @State private var splitEveryN = 1
    @State private var pageRangeText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Split Mode") {
                    Picker("Split Mode", selection: $selectedOption) {
                        Text("Split Every N Pages").tag(0)
                        Text("Extract Individual Pages").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                if selectedOption == 0 {
                    Section("Pages Per File") {
                        Stepper("Split every \(splitEveryN) page\(splitEveryN == 1 ? "" : "s")",
                                value: $splitEveryN, in: 1...max(1, pageCount))
                        
                        Text("This will create \(estimatedFileCount) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Extract All Pages") {
                        Text("Each page will be saved as a separate PDF file")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("This will create \(pageCount) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("Original PDF has \(pageCount) pages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Split Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Split") {
                        if selectedOption == 0 {
                            splitMode = .splitEvery(n: splitEveryN)
                        } else {
                            splitMode = .extractPages(indices: Array(0..<pageCount))
                        }
                        dismiss()
                        onConfirm()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
    
    private var estimatedFileCount: Int {
        guard splitEveryN > 0 else { return 0 }
        return (pageCount + splitEveryN - 1) / splitEveryN
    }
}

// MARK: - Preview

#Preview("Empty State") {
    DashboardView()
}

#Preview("With Files") {
    DashboardView()
}

#Preview("Split Options") {
    SplitOptionsSheet(
        pageCount: 10,
        splitMode: .constant(.splitEvery(n: 1))
    ) {
        print("Split confirmed")
    }
}
