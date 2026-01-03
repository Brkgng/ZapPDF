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
    @State private var isMergeHelpHovered = false
    @State private var draggingFileID: UUID?  // For macOS drag-and-drop
    
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
                            files: viewModel.filesForAction(action),
                            options: options
                        )
                    }
                }
                .sheet(isPresented: $showSplitOptions) {
                    if let file = viewModel.filesForAction(.split).first {
                        SplitOptionsSheet(
                            pageCount: file.pageCount,
                            fileURL: file.url,
                            splitMode: $splitMode
                        ) {
                            startAction(.split, options: .split(mode: splitMode))
                        }
                    }
                }
                .navigationDestination(isPresented: $showReorderView) {
                    if let file = viewModel.filesForAction(.reorder).first {
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
    
    #if os(macOS)
    // macOS: ScrollView with onDrag/onDrop for reliable drag-and-drop
    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.files) { file in
                    PDFFileRow(
                        pdfFile: file,
                        isSelected: viewModel.isSelected(file),
                        showSelectionCheckbox: true,
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                viewModel.selectFile(file)
                            } else {
                                viewModel.deselectFile(file)
                            }
                        },
                        onDelete: {
                            viewModel.removeFile(file)
                        }
                    )
                    .onDrag {
                        draggingFileID = file.id
                        return NSItemProvider(object: file.id.uuidString as NSString)
                    } preview: {
                        // Invisible drag preview
                        Color.clear.frame(width: 1, height: 1)
                    }
                    .onDrop(of: [.text], delegate: FileDropDelegate(
                        item: file,
                        files: viewModel.files,
                        draggingFileID: $draggingFileID,
                        onMove: { source, dest in
                            viewModel.reorderFiles(from: source, to: dest)
                        }
                    ))
                    .opacity(draggingFileID == file.id ? 0.5 : 1.0)
                    .contextMenu {
                        Button {
                            viewModel.toggleSelection(for: file)
                        } label: {
                            Label(
                                viewModel.isSelected(file) ? "Deselect" : "Select",
                                systemImage: viewModel.isSelected(file) ? "circle" : "checkmark.circle"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            viewModel.removeFile(file)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    #else
    // iOS: List with onMove for native reordering
    private var fileList: some View {
        List {
            ForEach(viewModel.files) { file in
                PDFFileRow(
                    pdfFile: file,
                    isSelected: viewModel.isSelected(file),
                    showSelectionCheckbox: true,
                    onSelectionChanged: { isSelected in
                        if isSelected {
                            viewModel.selectFile(file)
                        } else {
                            viewModel.deselectFile(file)
                        }
                    },
                    onDelete: {
                        viewModel.removeFile(file)
                    }
                )
                .contextMenu {
                    Button {
                        viewModel.toggleSelection(for: file)
                    } label: {
                        Label(
                            viewModel.isSelected(file) ? "Deselect" : "Select",
                            systemImage: viewModel.isSelected(file) ? "circle" : "checkmark.circle"
                        )
                    }
                    
                    Divider()
                    
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
    }
    #endif
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Summary
            HStack {
                // Selection count
                Text("\(viewModel.selectedCount) of \(viewModel.files.count) selected")
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
            // Merge button with instant hover help
            StyledActionButton(
                action: .merge,
                isEnabled: viewModel.canPerform(action: .merge)
            ) {
                handleActionTap(.merge)
            }
            .onHover { hovering in
                isMergeHelpHovered = hovering && viewModel.filesForAction(.merge).count >= 2
            }
            .overlay(alignment: .top) {
                if isMergeHelpHovered {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Files merge in displayed order. Drag to reorder.")
                            .multilineTextAlignment(.leading)
                    }
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: -50) // Position above the button
                    .allowsHitTesting(false) // Critical: prevents tooltip from intercepting clicks
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
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
        
        #if os(macOS)
        if viewModel.hasFiles {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        viewModel.selectAll()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    
                    Button {
                        viewModel.deselectAll()
                    } label: {
                        Label("Deselect All", systemImage: "circle")
                    }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
            }
        }
        #endif
        
        #if os(iOS)
        if viewModel.hasFiles {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        viewModel.selectAll()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        viewModel.deselectAll()
                    } label: {
                        Label("Deselect All", systemImage: "circle")
                    }
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
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
///
/// Provides three split modes:
/// - Split Every N Pages: Divide PDF into chunks
/// - Extract Page Ranges: Custom ranges like "1-5, 10-15"
/// - Select Specific Pages: Visual page picker
struct SplitOptionsSheet: View {
    let pageCount: Int
    let fileURL: URL?
    @Binding var splitMode: PDFSplitter.SplitMode
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Split modes: 0 = splitEvery, 1 = byRange, 2 = selectPages
    @State private var selectedModeIndex = 0
    
    // Mode 0: Split Every N
    @State private var splitEveryN = 1
    
    // Mode 1: Page Ranges
    @State private var pageRangeText = ""
    @State private var rangeError: String?
    
    // Mode 2: Select Pages
    @State private var selectedPages: Set<Int> = []
    
    // Convenience initializer for backwards compatibility
    init(
        pageCount: Int,
        splitMode: Binding<PDFSplitter.SplitMode>,
        onConfirm: @escaping () -> Void
    ) {
        self.pageCount = pageCount
        self.fileURL = nil
        self._splitMode = splitMode
        self.onConfirm = onConfirm
    }
    
    // Full initializer with URL for visual page selector
    init(
        pageCount: Int,
        fileURL: URL,
        splitMode: Binding<PDFSplitter.SplitMode>,
        onConfirm: @escaping () -> Void
    ) {
        self.pageCount = pageCount
        self.fileURL = fileURL
        self._splitMode = splitMode
        self.onConfirm = onConfirm
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Source file info
                    sourceFileInfo
                    
                    Divider()
                    
                    // Split mode picker
                    splitModePicker
                    
                    Divider()
                    
                    // Mode-specific options
                    modeOptionsSection
                    
                    Divider()
                    
                    // Output preview
                    outputPreviewSection
                }
                .padding()
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
                        performSplit()
                    }
                    .disabled(!canSplit)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
    }
    
    // MARK: - Source File Info
    
    private var sourceFileInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Source PDF")
                    .font(.headline)
                Text("\(pageCount) pages")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Split Mode Picker
    
    private var splitModePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Split Mode")
                .font(.headline)
            
            #if os(macOS)
            // macOS: Radio button style for clarity
            VStack(alignment: .leading, spacing: 8) {
                modeRadioButton(
                    index: 0,
                    icon: "rectangle.split.3x1",
                    title: "Split Every N Pages",
                    subtitle: "Divide into equal chunks"
                )
                
                modeRadioButton(
                    index: 1,
                    icon: "number",
                    title: "Extract Page Ranges",
                    subtitle: "Specify ranges like 1-5, 10-15"
                )
                
                modeRadioButton(
                    index: 2,
                    icon: "hand.tap",
                    title: "Select Specific Pages",
                    subtitle: "Pick individual pages visually"
                )
            }
            #else
            // iOS: Segmented picker for compact display
            Picker("Split Mode", selection: $selectedModeIndex) {
                Text("Every N").tag(0)
                Text("Ranges").tag(1)
                Text("Select").tag(2)
            }
            .pickerStyle(.segmented)
            
            // Mode description
            Text(modeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            #endif
        }
    }
    
    @ViewBuilder
    private func modeRadioButton(index: Int, icon: String, title: String, subtitle: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedModeIndex = index
            }
        } label: {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(selectedModeIndex == index ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if selectedModeIndex == index {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedModeIndex == index ? .accentColor : .secondary)
                    .frame(width: 24)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedModeIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var modeDescription: String {
        switch selectedModeIndex {
        case 0: return "Divide PDF into chunks of N pages each"
        case 1: return "Enter page ranges like 1-5, 10, 15-20"
        case 2: return "Tap pages to select them"
        default: return ""
        }
    }
    
    // MARK: - Mode Options Section
    
    @ViewBuilder
    private var modeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
            
            switch selectedModeIndex {
            case 0:
                splitEveryOptions
            case 1:
                pageRangeOptions
            case 2:
                selectPagesOptions
            default:
                EmptyView()
            }
        }
    }
    
    // Mode 0: Split Every N
    private var splitEveryOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pages per file:")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Stepper("\(splitEveryN)", value: $splitEveryN, in: 1...max(1, pageCount))
                    .labelsHidden()
                    .frame(width: 100)
                
                Text("\(splitEveryN) page\(splitEveryN == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // Mode 1: Page Ranges
    private var pageRangeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("e.g., 1-5, 10, 15-20", text: $pageRangeText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: pageRangeText) { _, newValue in
                    validateRanges(newValue)
                }
            
            if let error = rangeError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if !pageRangeText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Valid range")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text("Enter page numbers and ranges separated by commas")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Mode 2: Select Pages
    @ViewBuilder
    private var selectPagesOptions: some View {
        if let url = fileURL {
            PageSelectorGrid(
                url: url,
                pageCount: pageCount,
                selectedPages: $selectedPages
            )
        } else {
            // Fallback to simple list if no URL provided
            simplePageSelector
        }
    }
    
    private var simplePageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select pages:")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("All") {
                    selectedPages = Set(1...pageCount)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)
                
                Button("None") {
                    selectedPages.removeAll()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...pageCount, id: \.self) { page in
                        Button {
                            if selectedPages.contains(page) {
                                selectedPages.remove(page)
                            } else {
                                selectedPages.insert(page)
                            }
                        } label: {
                            Text("\(page)")
                                .font(.caption.weight(.medium))
                                .frame(width: 32, height: 32)
                                .background(
                                    selectedPages.contains(page)
                                        ? Color.accentColor
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    selectedPages.contains(page) ? .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Text("\(selectedPages.count) pages selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Output Preview Section
    
    private var outputPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)
                Text("Output Preview")
                    .font(.headline)
            }
            
            if outputFiles.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("No output files will be created")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(outputFiles.prefix(5).enumerated()), id: \.offset) { index, file in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(file.name)
                                .font(.caption.monospaced())
                            
                            Spacer()
                            
                            Text(file.pageDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if outputFiles.count > 5 {
                        Text("... and \(outputFiles.count - 5) more files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Text("Total: \(outputFiles.count) file\(outputFiles.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSplit: Bool {
        switch selectedModeIndex {
        case 0:
            return splitEveryN > 0 && pageCount > 0
        case 1:
            return rangeError == nil && !pageRangeText.isEmpty
        case 2:
            return !selectedPages.isEmpty
        default:
            return false
        }
    }
    
    private struct OutputFile {
        let name: String
        let pageDescription: String
    }
    
    private var outputFiles: [OutputFile] {
        switch selectedModeIndex {
        case 0:
            guard splitEveryN > 0 else { return [] }
            var files: [OutputFile] = []
            var start = 1
            var partNum = 1
            while start <= pageCount {
                let end = min(start + splitEveryN - 1, pageCount)
                let desc = start == end ? "Page \(start)" : "Pages \(start)-\(end)"
                files.append(OutputFile(name: "part\(partNum).pdf", pageDescription: desc))
                start = end + 1
                partNum += 1
            }
            return files
            
        case 1:
            guard let ranges = try? PageRangeParser.parse(pageRangeText, maxPage: pageCount) else {
                return []
            }
            return ranges.enumerated().map { index, range in
                let desc = range.lowerBound == range.upperBound
                    ? "Page \(range.lowerBound)"
                    : "Pages \(range.lowerBound)-\(range.upperBound)"
                return OutputFile(name: "range\(index + 1).pdf", pageDescription: desc)
            }
            
        case 2:
            guard !selectedPages.isEmpty else { return [] }
            let sortedPages = selectedPages.sorted()
            let pageList = sortedPages.count <= 5
                ? sortedPages.map(String.init).joined(separator: ", ")
                : "\(sortedPages.prefix(3).map(String.init).joined(separator: ", "))..."
            return [OutputFile(name: "extracted.pdf", pageDescription: "Pages: \(pageList)")]
            
        default:
            return []
        }
    }
    
    // MARK: - Actions
    
    private func validateRanges(_ text: String) {
        guard !text.isEmpty else {
            rangeError = nil
            return
        }
        
        do {
            _ = try PageRangeParser.parse(text, maxPage: pageCount)
            rangeError = nil
        } catch let error as PageRangeParseError {
            rangeError = error.localizedDescription
        } catch {
            rangeError = "Invalid format"
        }
    }
    
    private func performSplit() {
        switch selectedModeIndex {
        case 0:
            splitMode = .splitEvery(n: splitEveryN)
            
        case 1:
            if let ranges = try? PageRangeParser.parse(pageRangeText, maxPage: pageCount) {
                splitMode = .byPageRange(ranges: ranges)
            }
            
        case 2:
            let sortedPages = selectedPages.sorted()
            splitMode = .extractPages(indices: sortedPages)
            
        default:
            break
        }
        
        dismiss()
        onConfirm()
    }
}

// MARK: - macOS File Drop Delegate

#if os(macOS)
/// Drop delegate for file reordering on macOS.
struct FileDropDelegate: DropDelegate {
    let item: PDFFile
    let files: [PDFFile]
    @Binding var draggingFileID: UUID?
    let onMove: (IndexSet, Int) -> Void
    
    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingFileID,
              draggingID != item.id,
              let fromIndex = files.firstIndex(where: { $0.id == draggingID }),
              let toIndex = files.firstIndex(where: { $0.id == item.id })
        else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingFileID = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
#endif

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
