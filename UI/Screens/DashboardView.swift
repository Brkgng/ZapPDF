//
//  DashboardView.swift
//  ZapPDF
//
//  Main dashboard for file selection and action triggering.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif
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
    
    @EnvironmentObject private var viewModel: DashboardViewModel
    
    @State private var showFilePicker = false
    @State private var isDropTargeted = false
    @State private var selectedAction: UserAction?
    @State private var processingOptions: ProcessingOptions?
    @State private var showProcessingView = false
    @State private var showSplitOptions = false
    @State private var showReorderView = false
    @State private var splitMode: PDFSplitter.SplitMode = .splitEvery(n: 1)
    @State private var draggingFileID: UUID?  // For macOS drag-and-drop
    @State private var showClearConfirmation = false
    @State private var showUndoToast = false
    @State private var clearedFiles: [PDFFile] = []
    @State private var clearedSelection: Set<UUID> = []
    @State private var showSettings = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Dashboard.title)
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
                        #if os(macOS)
                        .frame(minWidth: 400, minHeight: 600)
                        #endif
                }
                #if os(iOS)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                #endif
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
                            fileName: file.fileName,
                            splitMode: $splitMode
                        ) {
                            startAction(.split, options: .split(mode: splitMode))
                        }
                    }
                }
                .navigationDestination(isPresented: $showReorderView) {
                    if let file = viewModel.filesForAction(.editPages).first {
                        PageReorderView(file: file)
                    }
                }
                .alert(L10n.Common.errorTitle, isPresented: hasError) {
                    Button(L10n.Action.ok) {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? L10n.Common.errorOccurred)
                }
                .confirmationDialog(
                    L10n.Dashboard.clearAllTitle,
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.Dashboard.clearFiles(viewModel.files.count), role: .destructive) {
                        viewModel.clearAll()
                    }
                    Button(L10n.Action.cancel, role: .cancel) { }
                } message: {
                    Text(L10n.Dashboard.clearAllMessage)
                }
                .task {
                    await viewModel.loadSubscriptionState()
                }
                .onReceive(NotificationCenter.default.publisher(for: .filesCleared)) { notification in
                    handleFilesCleared(notification)
                }
                .overlay(alignment: .bottom) {
                    if showUndoToast {
                        undoToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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
                                viewModel.isSelected(file) ? L10n.Common.deselect : L10n.Common.select,
                                systemImage: viewModel.isSelected(file) ? "circle" : "checkmark.circle"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            viewModel.removeFile(file)
                        } label: {
                            Label(L10n.Action.remove, systemImage: "trash")
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
                            viewModel.isSelected(file) ? L10n.Common.deselect : L10n.Common.select,
                            systemImage: viewModel.isSelected(file) ? "circle" : "checkmark.circle"
                        )
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        viewModel.removeFile(file)
                    } label: {
                        Label(L10n.Action.remove, systemImage: "trash")
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
                Text(L10n.Dashboard.selectedOfTotal(viewModel.selectedCount, viewModel.files.count))
                    .font(.subheadline)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(L10n.Dashboard.totalPages(viewModel.totalPageCount))
                    .font(.subheadline)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(viewModel.formattedTotalSize)
                    .font(.subheadline)
                
                Spacer()
                
                ClearAllButton {
                    showClearConfirmation = true
                }
            }
            .foregroundColor(.secondary)
            
            // Merge order hint - show when merge is available
            if viewModel.filesForAction(.merge).count >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(L10n.Common.mergeOrderHint)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
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
    
    private let buttonSpacing: CGFloat = 12
    
    private var actionButtonsRow: some View {
        Group {
            #if os(iOS)
            // iOS: Adaptive Grid Layout
            // Uses adaptive columns to fill width, handling 5 items gracefully
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 220), spacing: buttonSpacing)
            ], spacing: buttonSpacing) {
                actionButtons
            }
            #else
            // macOS: Horizontal Toolbar Style
            // Uses equal-width buttons that don't compress vertically
            HStack(spacing: buttonSpacing) {
                actionButtons
            }
            .frame(maxHeight: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #endif
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        // Shared modifier for button content sizing
        let buttonModifier = { (view: StyledActionButton) -> AnyView in
            #if os(iOS)
            // iOS: Fill grid cell
            return AnyView(view.frame(maxWidth: .infinity))
            #else
            // macOS: Intrinsic size with min-width for uniformity, but no infinite stretch
            return AnyView(view.frame(minWidth: 100))
            #endif
        }
        
        // Merge button
        buttonModifier(StyledActionButton(
            action: .merge,
            isEnabled: viewModel.canPerform(action: .merge)
        ) {
            handleActionTap(.merge)
        })
        
        // Split button
        buttonModifier(StyledActionButton(
            action: .split,
            isEnabled: viewModel.canPerform(action: .split)
        ) {
            handleActionTap(.split)
        })
        
        // Edit Pages button
        buttonModifier(StyledActionButton(
            action: .editPages,
            isEnabled: viewModel.canPerform(action: .editPages)
        ) {
            handleActionTap(.editPages)
        })
        
        // Flatten button
        buttonModifier(StyledActionButton(
            action: .flatten,
            isEnabled: viewModel.canPerform(action: .flatten)
        ) {
            handleActionTap(.flatten)
        })
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Subscription status badge
        #if os(macOS)
        ToolbarItem(placement: .navigation) {
            SubscriptionStatusBadge(
                isPro: viewModel.isPro,
                remainingActions: viewModel.remainingFreeActions,
                freeActionLimit: viewModel.freeActionLimit,
                onUpgradeTapped: {
                    viewModel.showPaywall = true
                }
            )
        }
        #else
        ToolbarItem(placement: .topBarLeading) {
            SubscriptionStatusBadge(
                isPro: viewModel.isPro,
                remainingActions: viewModel.remainingFreeActions,
                freeActionLimit: viewModel.freeActionLimit,
                onUpgradeTapped: {
                    viewModel.showPaywall = true
                }
            )
        }
        #endif
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFilePicker = true
            } label: {
                Label(L10n.Dashboard.addFiles, systemImage: "plus")
            }
        }
        
        #if os(iOS)
        ToolbarItem(placement: .secondaryAction) {
            Button {
                showSettings = true
            } label: {
                Label(L10n.Settings.title, systemImage: "gearshape")
            }
        }
        #endif
        
        #if os(macOS)
        if viewModel.hasFiles {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        viewModel.selectAll()
                    } label: {
                        Label(L10n.Action.selectAll, systemImage: "checkmark.circle")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    
                    Button {
                        viewModel.deselectAll()
                    } label: {
                        Label(L10n.Action.deselectAll, systemImage: "circle")
                    }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                } label: {
                    Label(L10n.Common.selection, systemImage: "checklist")
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
                        Label(L10n.Action.selectAll, systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        viewModel.deselectAll()
                    } label: {
                        Label(L10n.Action.deselectAll, systemImage: "circle")
                    }
                } label: {
                    Label(L10n.Common.selection, systemImage: "checklist")
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
            viewModel.errorMessage = L10n.Dashboard.failedToImport(error.localizedDescription)
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
                        startAction(.merge, options: .merge(outputFileName: L10n.Dashboard.mergedOutputName))
                        
                    case .split:
                        // Show split options sheet
                        showSplitOptions = true
                        
                    case .editPages:
                        // Show page editor view
                        showReorderView = true
                        
                    case .flatten:
                        // Show processing directly for flatten
                        startAction(.flatten, options: .flatten())
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
    
    // MARK: - Undo Toast
    
    private var undoToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(L10n.Dashboard.undoMessage(clearedFiles.count))
                .font(.subheadline)
            
            Spacer()
            
            Button {
                undoClear()
            } label: {
                Text(L10n.Action.undo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private func handleFilesCleared(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let previousFiles = userInfo["previousFiles"] as? [PDFFile],
              let previousSelection = userInfo["previousSelection"] as? Set<UUID>,
              !previousFiles.isEmpty
        else { return }
        
        // Store data for undo
        clearedFiles = previousFiles
        clearedSelection = previousSelection
        
        // Show toast with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showUndoToast = true
        }
        
        // Auto-dismiss after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showUndoToast = false
                }
            }
        }
    }
    
    private func undoClear() {
        viewModel.restoreFiles(clearedFiles, selection: clearedSelection)
        
        withAnimation(.easeOut(duration: 0.2)) {
            showUndoToast = false
        }
        
        // Trigger haptic
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
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
    let fileName: String
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
        fileName: String = "Source PDF",
        splitMode: Binding<PDFSplitter.SplitMode>,
        onConfirm: @escaping () -> Void
    ) {
        self.pageCount = pageCount
        self.fileURL = nil
        self.fileName = fileName
        self._splitMode = splitMode
        self.onConfirm = onConfirm
    }
    
    // Full initializer with URL for visual page selector
    init(
        pageCount: Int,
        fileURL: URL,
        fileName: String,
        splitMode: Binding<PDFSplitter.SplitMode>,
        onConfirm: @escaping () -> Void
    ) {
        self.pageCount = pageCount
        self.fileURL = fileURL
        self.fileName = fileName
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
            .navigationTitle(L10n.SplitOptions.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.SplitOptions.split) {
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
                Text(fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(L10n.Plural.pages(pageCount))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Split Mode Picker
    
    private var splitModePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.SplitOptions.splitMode)
                .font(.headline)
            
            #if os(macOS)
            // macOS: Radio button style for clarity
            VStack(alignment: .leading, spacing: 8) {
                modeRadioButton(
                    index: 0,
                    icon: "rectangle.split.3x1",
                    title: L10n.Operation.Split.splitEvery,
                    subtitle: L10n.SplitOptions.divideIntoChunks
                )
                
                modeRadioButton(
                    index: 1,
                    icon: "number",
                    title: L10n.Operation.Split.extractRanges,
                    subtitle: L10n.SplitOptions.specifyRanges
                )
                
                modeRadioButton(
                    index: 2,
                    icon: "hand.tap",
                    title: L10n.Operation.Split.selectPages,
                    subtitle: L10n.SplitOptions.pickPagesVisually
                )
            }
            #else
            // iOS: Segmented picker for compact display
            Picker(L10n.SplitOptions.splitMode, selection: $selectedModeIndex) {
                Text(L10n.SplitOptions.everyN).tag(0)
                Text(L10n.SplitOptions.ranges).tag(1)
                Text(L10n.SplitOptions.select).tag(2)
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
        case 0: return L10n.SplitOptions.modeDescSplitEvery
        case 1: return L10n.SplitOptions.modeDescPageRange
        case 2: return L10n.SplitOptions.modeDescSelectPages
        default: return ""
        }
    }
    
    // MARK: - Mode Options Section
    
    @ViewBuilder
    private var modeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.SplitOptions.options)
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
                Text(L10n.SplitOptions.pagesPerFile)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Stepper("\(splitEveryN)", value: $splitEveryN, in: 1...max(1, pageCount))
                    .labelsHidden()
                    .frame(width: 100)
                
                Text(L10n.SplitOptions.pageCount(splitEveryN))
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
            TextField(L10n.SplitOptions.rangePlaceholder, text: $pageRangeText)
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
                    Text(L10n.SplitOptions.validRange)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text(L10n.SplitOptions.enterPageRanges)
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
                Text(L10n.SplitOptions.selectPagesToExtract)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(L10n.Common.all) {
                    selectedPages = Set(1...pageCount)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)
                
                Button(L10n.Common.none) {
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
            
            Text(L10n.SplitOptions.pagesSelected(selectedPages.count))
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
                Text(L10n.SplitOptions.outputPreview)
                    .font(.headline)
            }
            
            if outputFiles.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text(L10n.SplitOptions.noOutput)
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
                        Text(L10n.Dashboard.moreFiles(outputFiles.count - 5))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Text(L10n.SplitOptions.totalFiles(outputFiles.count))
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
                let desc = start == end ? L10n.SplitOptions.pageRange(start) : L10n.SplitOptions.pagesRange(start, end)
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
                    ? L10n.SplitOptions.pageRange(range.lowerBound)
                    : L10n.SplitOptions.pagesRange(range.lowerBound, range.upperBound)
                return OutputFile(name: "range\(index + 1).pdf", pageDescription: desc)
            }
            
        case 2:
            guard !selectedPages.isEmpty else { return [] }
            let sortedPages = selectedPages.sorted()
            let pageList = sortedPages.count <= 5
                ? sortedPages.map(String.init).joined(separator: ", ")
                : "\(sortedPages.prefix(3).map(String.init).joined(separator: ", "))..."
            return [OutputFile(name: "extracted.pdf", pageDescription: L10n.SplitOptions.pagesLabel(pageList))]
            
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
            rangeError = L10n.Common.invalidFormat
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
