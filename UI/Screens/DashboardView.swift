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

#if os(iOS)
import VisionKit
#endif

#if os(macOS)
import AppKit
import Combine

private enum DashboardInternalDragType {
    static let reorderFileID = UTType(exportedAs: "com.zappdf.internal.reorder-file-id")

    static func makeReorderProvider(fileID: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = Data(fileID.uuidString.utf8)

        provider.registerDataRepresentation(
            forTypeIdentifier: reorderFileID.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }

        return provider
    }
}
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
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #endif

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
    @State private var showLargeMergeConfirmation = false
    @State private var largeMergeSummary: MergePreflightSummary?
    @State private var showUndoToast = false
    @State private var clearedFiles: [PDFFile] = []
    @State private var clearedSelection: Set<UUID> = []
    @State private var showSettings = false
    @State private var showFileShareSheet = false
    @State private var fileShareItems: [Any] = []
    @State private var temporaryShareDirectories: [URL] = []
    #if os(iOS)
    @State private var iOSActionGridWidth: CGFloat = 0
    #endif

    #if os(macOS)
    private let dragStateResetTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    #endif

    #if os(iOS)
    @State private var showScanner = false
    @State private var showPhotoImporter = false
    @State private var isProcessingScan = false
    @State private var scanProgress: Double? = nil
    @State private var showScanSuccessToast = false
    @State private var scanSuccessToastID: UUID?
    @State private var lastScanURL: URL?
    #endif

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
                        .frame(
                            minWidth: PaywallPresentationMetrics.minWidth,
                            minHeight: PaywallPresentationMetrics.minHeight,
                        )
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
                        #if os(iOS)
                        SplitOptionsSheet(
                            pageCount: file.pageCount,
                            fileURL: file.url,
                            fileName: file.fileName,
                            splitMode: $splitMode
                        ) {
                            startAction(.split, options: .split(mode: splitMode))
                        }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        #else
                        SplitOptionsSheet(
                            pageCount: file.pageCount,
                            fileURL: file.url,
                            fileName: file.fileName,
                            splitMode: $splitMode
                        ) {
                            startAction(.split, options: .split(mode: splitMode))
                        }
                        #endif
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
                .confirmationDialog(
                    L10n.Dashboard.largeMergeTitle,
                    isPresented: $showLargeMergeConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.Action.continue) {
                        largeMergeSummary = nil
                        startMerge()
                    }
                    Button(L10n.Action.cancel, role: .cancel) {
                        largeMergeSummary = nil
                    }
                } message: {
                    if let summary = largeMergeSummary {
                        Text(L10n.Dashboard.largeMergeConfirmation(
                            pages: summary.totalPages,
                            size: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file)
                        ))
                    }
                }
                .task {
                    await viewModel.loadSubscriptionState()
                }
                .onReceive(NotificationCenter.default.publisher(for: .filesCleared)) { notification in
                    handleFilesCleared(notification)
                }
                #if os(macOS)
                .onReceive(dragStateResetTimer) { _ in
                    clearStaleDragStateIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    draggingFileID = nil
                }
                #endif
                .overlay(alignment: .bottom) {
                    if showUndoToast {
                        undoToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                #if os(iOS)
                .overlay(alignment: .bottom) {
                    if showScanSuccessToast {
                        scanSuccessToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .fullScreenCover(isPresented: $showScanner) {
                    DocumentScannerView(
                        isPresented: $showScanner,
                        onScanCompleted: handleScanCompleted,
                        onCancelled: { },
                        onError: handleScanError
                    )
                    .ignoresSafeArea()
                }
                .sheet(isPresented: $showPhotoImporter) {
                    PhotoImporterView(
                        isPresented: $showPhotoImporter,
                        onItemProvidersSelected: handlePhotoProvidersSelected
                    )
                }
                .sheet(isPresented: $showFileShareSheet, onDismiss: cleanupTemporaryShareFiles) {
                    ShareSheet(items: fileShareItems) { _ in
                        cleanupTemporaryShareFiles()
                    }
                }
                .overlay {
                    if isProcessingScan {
                        ScanProcessingOverlay(progress: scanProgress)
                    }
                }
                #endif
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

    #if os(macOS)
    private func clearStaleDragStateIfNeeded() {
        guard draggingFileID != nil else { return }
        guard NSEvent.pressedMouseButtons == 0 else { return }
        draggingFileID = nil
    }
    #endif

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
                        return DashboardInternalDragType.makeReorderProvider(fileID: file.id)
                    } preview: {
                        // Invisible drag preview
                        Color.clear.frame(width: 1, height: 1)
                    }
                    .if(draggingFileID != nil) { row in
                        row.onDrop(of: [DashboardInternalDragType.reorderFileID], delegate: FileDropDelegate(
                            item: file,
                            files: viewModel.files,
                            draggingFileID: $draggingFileID,
                            onMove: { source, dest in
                                viewModel.reorderFiles(from: source, to: dest)
                            }
                        ))
                    }
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

                        Button {
                            shareFile(file)
                        } label: {
                            Label(L10n.ContextMenu.share, systemImage: "square.and.arrow.up")
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
                // Hide inline delete on iOS to avoid duplicate affordances with swipe-to-delete.
                PDFFileRow(
                    pdfFile: file,
                    isSelected: viewModel.isSelected(file),
                    showDeleteButton: false,
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

                    Button {
                        shareFile(file)
                    } label: {
                        Label(L10n.ContextMenu.share, systemImage: "square.and.arrow.up")
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

                #if os(macOS)
                ClearAllButton {
                    showClearConfirmation = true
                }
                #endif
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
    private static let orderedDashboardActions: [UserAction] = [.merge, .split, .editPages, .flatten]

    enum IOSHorizontalLayoutClass: Equatable {
        case compact
        case regular
    }

    static func iOSActionColumnCount(
        containerWidth: CGFloat,
        actionCount: Int,
        isPad: Bool,
        horizontalSizeClass: IOSHorizontalLayoutClass,
        isAccessibilityTextSize: Bool
    ) -> Int {
        let count = max(1, actionCount)
        guard isPad else {
            return min(2, count)
        }

        let isWideEnough = containerWidth >= 744
        if isAccessibilityTextSize || horizontalSizeClass != .regular || !isWideEnough {
            return min(2, count)
        }

        return min(4, count)
    }

    private var actionButtonsRow: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                let columns = Self.iOSActionColumnCount(
                    containerWidth: iOSActionGridWidth,
                    actionCount: Self.orderedDashboardActions.count,
                    isPad: true,
                    horizontalSizeClass: horizontalSizeClass == .regular ? .regular : .compact,
                    isAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
                )
                let gridItems = Array(
                    repeating: GridItem(.flexible(minimum: 0), spacing: buttonSpacing),
                    count: columns
                )

                LazyVGrid(columns: gridItems, spacing: buttonSpacing) {
                    actionButtons(isPadLayout: true)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .task(id: geometry.size.width) {
                                iOSActionGridWidth = geometry.size.width
                            }
                    }
                }
            } else {
                // iPhone: keep existing adaptive behavior.
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 220), spacing: buttonSpacing)
                ], spacing: buttonSpacing) {
                    actionButtons()
                }
            }
            #else
            // macOS: Horizontal Toolbar Style
            // Uses equal-width buttons that don't compress vertically
            HStack(spacing: buttonSpacing) {
                actionButtons()
            }
            .frame(maxHeight: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #endif
        }
    }

    @ViewBuilder
    private func actionButtons(isPadLayout: Bool = false) -> some View {
        ForEach(Self.orderedDashboardActions, id: \.self) { action in
            StyledActionButton(
                action: action,
                isEnabled: viewModel.canPerform(action: action)
            ) {
                handleActionTap(action)
            }
            #if os(iOS)
            .frame(maxWidth: .infinity)
            .if(isPadLayout) { button in
                button.frame(minHeight: 56)
            }
            #else
            .frame(minWidth: 100)
            #endif
        }
    }

    // MARK: - iOS Toolbar Actions

    enum IOSTrailingToolbarAction: Hashable {
        case settings
        case clearAll
    }

    static func iOSTrailingToolbarActions(hasFiles: Bool) -> [IOSTrailingToolbarAction] {
        var actions: [IOSTrailingToolbarAction] = [.settings]
        if hasFiles {
            actions.append(.clearAll)
        }
        return actions
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
                    viewModel.handleUpgradeTap()
                }
            )
        }
        #else
        ToolbarItem(placement: .topBarLeading) {
            SubscriptionStatusBadge(
                isPro: viewModel.isPro,
                remainingActions: viewModel.remainingFreeActions,
                freeActionLimit: viewModel.freeActionLimit,
                presentationStyle: .compactToolbar,
                onUpgradeTapped: {
                    viewModel.handleUpgradeTap()
                }
            )
        }
        #endif

        #if os(iOS)
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showFilePicker = true
                } label: {
                    Label(L10n.Dashboard.addFiles, systemImage: "doc.badge.plus")
                }

                if DocumentScanner.isSupported {
                    Button {
                        showScanner = true
                    } label: {
                        Label(L10n.Scanner.scanDocument, systemImage: "doc.viewfinder")
                    }
                }

                Button {
                    showPhotoImporter = true
                } label: {
                    Label(L10n.Scanner.importFromPhotos, systemImage: "photo.on.rectangle")
                }
            } label: {
                Label(L10n.Dashboard.addFiles, systemImage: "plus")
            }
            .disabled(isProcessingScan)
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFilePicker = true
            } label: {
                Label(L10n.Dashboard.addFiles, systemImage: "plus")
            }
        }
        #endif

        #if os(iOS)
        ToolbarItemGroup(placement: .secondaryAction) {
            let actions = Self.iOSTrailingToolbarActions(hasFiles: viewModel.hasFiles)

            if actions.contains(.settings) {
                Button {
                    showSettings = true
                } label: {
                    Label(L10n.Settings.title, systemImage: "gearshape")
                }
            }

            if actions.contains(.clearAll) {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label(L10n.Dashboard.clearAll, systemImage: "trash")
                }
            }
        }
        #endif

        #if os(macOS)
        ToolbarItem(placement: .secondaryAction) {
            SettingsLink {
                Label(L10n.Settings.title, systemImage: "gearshape")
            }
            .help(L10n.Settings.title)
        }

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
            ToolbarItem(placement: .secondaryAction) {
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
            // PDFFile.init handles security-scoped access internally via
            // withSecurityScopeAsync, so we pass URLs through directly.
            // Do NOT filter URLs based on startAccessingSecurityScopedResource()
            // — it returns false when the file is already accessible (no scope
            // needed), which does NOT mean the file is inaccessible.
            Task {
                await viewModel.addFiles(urls: urls)
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
                        if let summary = viewModel.mergePreflightSummary(),
                           summary.risk == .warn {
                            largeMergeSummary = summary
                            showLargeMergeConfirmation = true
                        } else {
                            startMerge()
                        }

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

    private func startMerge() {
        startAction(.merge, options: .merge(outputFileName: L10n.Dashboard.mergedOutputName))
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

    // MARK: - File Sharing

    private func shareFile(_ file: PDFFile) {
        Task {
            do {
                let shareableFile: ShareableFile
                if file.origin == .internalScan {
                    shareableFile = ShareableFile(url: file.url, cleanupDirectory: nil)
                } else {
                    shareableFile = try await Task.detached(priority: .userInitiated) {
                        try Self.prepareShareableFile(for: file)
                    }.value
                }

                presentShareableFile(shareableFile)
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func presentShareableFile(_ shareableFile: ShareableFile) {
        #if os(iOS)
        if let cleanupDirectory = shareableFile.cleanupDirectory {
            temporaryShareDirectories.append(cleanupDirectory)
        }
        fileShareItems = [shareableFile.url]
        showFileShareSheet = true
        #else
        guard let contentView = NSApp.keyWindow?.contentView else {
            cleanupTemporaryShareDirectory(shareableFile.cleanupDirectory)
            return
        }

        if let cleanupDirectory = shareableFile.cleanupDirectory {
            temporaryShareDirectories.append(cleanupDirectory)
            scheduleTemporaryShareCleanup(for: cleanupDirectory)
        }

        let picker = NSSharingServicePicker(items: [shareableFile.url])
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        #endif
    }

    private struct ShareableFile: Sendable {
        let url: URL
        let cleanupDirectory: URL?
    }

    private nonisolated static func prepareShareableFile(for file: PDFFile) throws -> ShareableFile {
        try file.withResolvedAccess { accessURL in
            let fileManager = FileManager.default
            let shareDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("ZapPDFShare-\(UUID().uuidString)", isDirectory: true)
            let shareURL = shareDirectory.appendingPathComponent(file.fileName, isDirectory: false)

            try fileManager.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: accessURL, to: shareURL)

            return ShareableFile(url: shareURL, cleanupDirectory: shareDirectory)
        }
    }

    private func cleanupTemporaryShareFiles() {
        let directories = temporaryShareDirectories
        temporaryShareDirectories.removeAll()
        fileShareItems = []

        for directory in directories {
            cleanupTemporaryShareDirectory(directory)
        }
    }

    private func cleanupTemporaryShareDirectory(_ directory: URL?) {
        guard let directory else { return }

        try? FileManager.default.removeItem(at: directory)
        temporaryShareDirectories.removeAll { $0 == directory }
    }

    #if os(macOS)
    private func scheduleTemporaryShareCleanup(for directory: URL) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(300))
            cleanupTemporaryShareDirectory(directory)
        }
    }
    #endif

    // MARK: - Scan Success Toast

    #if os(iOS)
    private var scanSuccessToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.green)

            Text(L10n.Scanner.scanAdded)
                .font(.subheadline)

            Spacer()

            if let url = lastScanURL {
                Button {
                    fileShareItems = [url]
                    showFileShareSheet = true
                } label: {
                    Text(L10n.ContextMenu.share)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func presentScanSuccessToast(for url: URL) {
        let toastID = UUID()
        scanSuccessToastID = toastID
        lastScanURL = url

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showScanSuccessToast = true
        }

        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                guard scanSuccessToastID == toastID else { return }

                withAnimation(.easeOut(duration: 0.2)) {
                    showScanSuccessToast = false
                }
                scanSuccessToastID = nil
                lastScanURL = nil
            }
        }
    }
    #endif

    // MARK: - Scanning (iOS)

    #if os(iOS)
    private func handleScanCompleted(_ scan: VNDocumentCameraScan) {
        isProcessingScan = true
        scanProgress = nil  // Start with indeterminate progress

        Task {
            // Ensure state is always reset, even if an unexpected error occurs
            defer {
                isProcessingScan = false
                scanProgress = nil
            }

            do {
                let result = try await DocumentScanner.shared.convertScanToPDF(scan) { progress in
                    // Update progress on main actor
                    Task { @MainActor in
                        scanProgress = progress
                    }
                }
                await viewModel.addFiles(urls: [result.pdfURL], origin: .internalScan)

                presentScanSuccessToast(for: result.pdfURL)

                // Show warning if some pages failed
                if !result.isComplete {
                    viewModel.errorMessage = L10n.Scanner.partialSuccess(
                        result.successfulPages,
                        result.successfulPages + result.failedPageIndices.count
                    )
                }
            } catch {
                if let scanError = error as? DocumentScannerError,
                   scanError == .cancelled {
                    // User cancelled, no error needed
                } else {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handlePhotoProvidersSelected(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }

        isProcessingScan = true
        scanProgress = nil  // Start with indeterminate progress

        Task {
            // Ensure state is always reset, even if an unexpected error occurs
            defer {
                isProcessingScan = false
                scanProgress = nil
            }

            do {
                let result = try await DocumentScanner.shared.convertImageProvidersToPDF(providers) { progress in
                    // Update progress on main actor
                    Task { @MainActor in
                        scanProgress = progress
                    }
                }
                await viewModel.addFiles(urls: [result.pdfURL], origin: .internalScan)

                if !result.isComplete {
                    viewModel.errorMessage = L10n.Scanner.partialSuccess(
                        result.successfulPages,
                        result.successfulPages + result.failedPageIndices.count
                    )
                }
            } catch {
                // Match cancellation pattern from handleScanCompleted
                if let scanError = error as? DocumentScannerError,
                   scanError == .cancelled {
                    // User cancelled, no error needed
                } else {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleScanError(_ error: Error) {
        viewModel.errorMessage = L10n.Scanner.errorCamera(error.localizedDescription)
    }
    #endif
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

        let initialState = Self.makeInitialState(from: splitMode.wrappedValue, pageCount: pageCount)
        self._selectedModeIndex = State(initialValue: initialState.modeIndex)
        self._splitEveryN = State(initialValue: initialState.splitEveryN)
        self._pageRangeText = State(initialValue: initialState.pageRangeText)
        self._rangeError = State(initialValue: nil)
        self._selectedPages = State(initialValue: initialState.selectedPages)
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

        let initialState = Self.makeInitialState(from: splitMode.wrappedValue, pageCount: pageCount)
        self._selectedModeIndex = State(initialValue: initialState.modeIndex)
        self._splitEveryN = State(initialValue: initialState.splitEveryN)
        self._pageRangeText = State(initialValue: initialState.pageRangeText)
        self._rangeError = State(initialValue: nil)
        self._selectedPages = State(initialValue: initialState.selectedPages)
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
        .onAppear {
            syncFromSplitMode()
            splitEveryN = Self.clampedSplitEveryN(splitEveryN, pageCount: pageCount)
        }
        .onChange(of: splitEveryN) { _, newValue in
            splitEveryN = Self.clampedSplitEveryN(newValue, pageCount: pageCount)
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 700)
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
                .allowsHitTesting(false)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .focusable(false)
        #endif
        .accessibilityIdentifier(Self.modeOptionAccessibilityIdentifier(for: index))
        .accessibilityValue(
            Self.modeOptionAccessibilityValue(isSelected: selectedModeIndex == index)
        )
    }

    private var modeDescription: String {
        Self.modeDescription(for: selectedModeIndex)
    }

    static func modeDescription(for index: Int) -> String {
        switch index {
        case 0: return L10n.SplitOptions.modeDescSplitEvery
        case 1: return L10n.SplitOptions.modeDescPageRange
        case 2: return L10n.SplitOptions.modeDescSelectPages
        default: return ""
        }
    }

    static func modeOptionAccessibilityIdentifier(for index: Int) -> String {
        switch index {
        case 0:
            return "splitMode.option.splitEvery"
        case 1:
            return "splitMode.option.extractRanges"
        case 2:
            return "splitMode.option.selectPages"
        default:
            return "splitMode.option.unknown.\(index)"
        }
    }

    static func modeOptionAccessibilityValue(isSelected: Bool) -> String {
        isSelected ? "selected" : "unselected"
    }

    static func clampedSplitEveryN(_ value: Int, pageCount: Int) -> Int {
        let maxValue = max(1, pageCount)
        return min(max(value, 1), maxValue)
    }

    static func rangesText(from ranges: [ClosedRange<Int>]) -> String {
        ranges.map { range in
            if range.lowerBound == range.upperBound {
                return "\(range.lowerBound)"
            }
            return "\(range.lowerBound)-\(range.upperBound)"
        }
        .joined(separator: ", ")
    }

    static func sanitizedSelectedPages(_ indices: [Int], pageCount: Int) -> Set<Int> {
        guard pageCount > 0 else { return [] }
        return Set(indices.filter { 1...pageCount ~= $0 })
    }

    struct InitialState: Equatable {
        let modeIndex: Int
        let splitEveryN: Int
        let pageRangeText: String
        let selectedPages: Set<Int>
    }

    static func makeInitialState(from mode: PDFSplitter.SplitMode, pageCount: Int) -> InitialState {
        switch mode {
        case .splitEvery(let n):
            return InitialState(
                modeIndex: 0,
                splitEveryN: clampedSplitEveryN(n, pageCount: pageCount),
                pageRangeText: "",
                selectedPages: []
            )
        case .byPageRange(let ranges):
            return InitialState(
                modeIndex: 1,
                splitEveryN: clampedSplitEveryN(1, pageCount: pageCount),
                pageRangeText: rangesText(from: ranges),
                selectedPages: []
            )
        case .extractPages(let indices):
            return InitialState(
                modeIndex: 2,
                splitEveryN: clampedSplitEveryN(1, pageCount: pageCount),
                pageRangeText: "",
                selectedPages: sanitizedSelectedPages(indices, pageCount: pageCount)
            )
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

                TextField(
                    L10n.SplitOptions.pageCount(splitEveryN),
                    value: $splitEveryN,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(width: 70)

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

            SplitOutputListView(items: outputFiles, showsTotalCount: true)
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

    private var sourceBaseName: String {
        let baseName = URL(fileURLWithPath: fileName)
            .deletingPathExtension()
            .lastPathComponent
        return baseName.isEmpty ? fileName : baseName
    }

    private func previewNames(for segments: [[Int]]) -> [String] {
        var stemOccurrences: [String: Int] = [:]
        return segments.map { segment in
            let pageToken = SplitOutputNaming.pageToken(from: segment)
            let canonicalStem = SplitOutputNaming.makeStem(
                baseName: sourceBaseName,
                pageToken: pageToken,
                timestamp: nil,
                duplicateIndex: nil
            )
            let occurrence = (stemOccurrences[canonicalStem] ?? 0) + 1
            stemOccurrences[canonicalStem] = occurrence

            let finalStem = SplitOutputNaming.makeStem(
                baseName: sourceBaseName,
                pageToken: pageToken,
                timestamp: nil,
                duplicateIndex: occurrence
            )
            return "\(finalStem).pdf"
        }
    }

    private var outputFiles: [SplitOutputListView.Item] {
        switch selectedModeIndex {
        case 0:
            guard splitEveryN > 0 else { return [] }
            var segments: [[Int]] = []
            var start = 1
            while start <= pageCount {
                let end = min(start + splitEveryN - 1, pageCount)
                segments.append(Array(start...end))
                start = end + 1
            }
            let names = previewNames(for: segments)
            return segments.enumerated().map { index, segment in
                let rangeStart = segment.first ?? 1
                let rangeEnd = segment.last ?? rangeStart
                let desc = rangeStart == rangeEnd
                    ? L10n.SplitOptions.pageRange(rangeStart)
                    : L10n.SplitOptions.pagesRange(rangeStart, rangeEnd)
                return .init(name: names[index], detail: desc)
            }

        case 1:
            guard let ranges = try? PageRangeParser.parse(pageRangeText, maxPage: pageCount) else {
                return []
            }
            let segments = ranges.map { Array($0) }
            let names = previewNames(for: segments)
            return ranges.enumerated().map { index, range in
                let desc = range.lowerBound == range.upperBound
                    ? L10n.SplitOptions.pageRange(range.lowerBound)
                    : L10n.SplitOptions.pagesRange(range.lowerBound, range.upperBound)
                return .init(name: names[index], detail: desc)
            }

        case 2:
            guard !selectedPages.isEmpty else { return [] }
            let sortedPages = selectedPages.sorted()
            let name = previewNames(for: [sortedPages]).first ?? "\(sourceBaseName).pdf"
            let pageList = sortedPages.count <= 5
                ? sortedPages.map(String.init).joined(separator: ", ")
                : "\(sortedPages.prefix(3).map(String.init).joined(separator: ", "))..."
            return [.init(name: name, detail: L10n.SplitOptions.pagesLabel(pageList))]

        default:
            return []
        }
    }

    // MARK: - Actions

    private func syncFromSplitMode() {
        let initialState = Self.makeInitialState(from: splitMode, pageCount: pageCount)
        selectedModeIndex = initialState.modeIndex
        splitEveryN = initialState.splitEveryN
        pageRangeText = initialState.pageRangeText
        selectedPages = initialState.selectedPages
        validateRanges(pageRangeText)
    }

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

    private func isInternalReorderDrag(_ info: DropInfo) -> Bool {
        guard draggingFileID != nil else { return false }
        return info.hasItemsConforming(to: [DashboardInternalDragType.reorderFileID])
    }

    func validateDrop(info: DropInfo) -> Bool {
        isInternalReorderDrag(info)
    }

    func dropEntered(info: DropInfo) {
        guard isInternalReorderDrag(info) else {
            return
        }

        guard let draggingID = draggingFileID else {
            return
        }

        guard draggingID != item.id else {
            return
        }

        guard let fromIndex = files.firstIndex(where: { $0.id == draggingID }),
              let toIndex = files.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard isInternalReorderDrag(info) else {
            return false
        }

        draggingFileID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isInternalReorderDrag(info) else {
            return nil
        }

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
    ) { }
}
