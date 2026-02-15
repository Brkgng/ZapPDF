//
//  ProcessingView.swift
//  ZapPDF
//
//  Progress tracking screen with cancellation and completion handling.
//

import SwiftUI
import UniformTypeIdentifiers
import StoreKit
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - ProcessingView

/// Progress tracking view for PDF operations.
///
/// Displays state-driven UI based on processing state:
/// - Idle: Starting message
/// - Processing: Progress bar with cancel button
/// - Completed: Success with save/share options
/// - Failed: Error message with retry option
/// - Cancelled: Auto-dismisses
///
/// Example:
/// ```swift
/// ProcessingView(
///     action: .merge,
///     files: selectedFiles,
///     options: .merge(outputFileName: "Combined")
/// )
/// ```
struct ProcessingView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = ProcessingViewModel()
    
    let action: UserAction
    let files: [PDFFile]
    let options: ProcessingOptions
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var showCancelConfirmation = false
    @State private var showShareSheet = false
    @State private var showFileSaveSuccess = false
    @State private var savedOutputURLs: [URL] = []
    @State private var saveErrorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    // Fixed header (Icon + Title) - Non-scrollable
                    stateHeader
                    
                    // Flexible content area (Preview, etc.)
                    GeometryReader { innerGeometry in
                        ScrollView {
                            stateFlexibleContent(
                                availableWidth: innerGeometry.size.width,
                                availableHeight: innerGeometry.size.height
                            )
                            .frame(minHeight: innerGeometry.size.height, alignment: .top)
                        }
                    }
                    
                    // Action buttons (always visible, pinned to bottom)
                    actionButtons
                        .layoutPriority(1)
                }
            }
            .padding(24)
            .navigationTitle(action.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // No close button needed here as we rely on the NavigationStack's back button
            }
            .task {
                await viewModel.execute(
                    action: action,
                    files: files,
                    options: options
                )
            }
            .confirmationDialog(
                L10n.Processing.cancelConfirmTitle,
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Processing.cancelOperation, role: .destructive) {
                    viewModel.cancel()
                }
                Button(L10n.Action.continue, role: .cancel) {}
            } message: {
                Text(L10n.Processing.cancelConfirmMessage)
            }
            .alert(saveSuccessTitle, isPresented: $showFileSaveSuccess) {
                Button(L10n.Action.ok) {
                    dismiss()
                }
                #if os(macOS)
                if !savedOutputURLs.isEmpty {
                    Button(L10n.Processing.revealInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting(savedOutputURLs)
                        dismiss()
                    }
                }
                #endif
            } message: {
                Text(saveSuccessMessage)
            }
            #if os(macOS)
            .alert(
                L10n.Common.saveFailed,
                isPresented: .init(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button(L10n.Action.retry) {
                    if case .completed(let urls) = viewModel.state {
                        saveFileOnMacOS(urls: urls)
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? L10n.Common.unableToSave)
            }
            #endif
            .onChange(of: viewModel.state) { oldState, newState in
                if case .cancelled = newState {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - State Content
    
    // MARK: - State Header
    
    @ViewBuilder
    private var stateHeader: some View {
        if case .completed = viewModel.state {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text(L10n.Processing.completed)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - State Flexible Content
    
    @ViewBuilder
    private func stateFlexibleContent(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        switch viewModel.state {
        case .idle:
            idleContent
            
        case .processing(let progress, let message):
            processingContent(progress: progress, message: message)
            
        case .completed(let resultURLs):
            completedFlexibleContent(
                resultURLs: resultURLs,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )
            
        case .failed(let errorMessage):
            failedContent(errorMessage: errorMessage)
            
        case .cancelled:
            // Will auto-dismiss
            ProgressView()
        }
    }
    
    // MARK: - Idle Content
    
    private var idleContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(L10n.Processing.preparing)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Processing Content
    
    private func processingContent(progress: Double, message: String) -> some View {
        VStack(spacing: 24) {
            // Animated icon
            Image(systemName: action.iconName)
                .font(.system(size: 64))
                .foregroundColor(action.accentColor)
                .symbolEffect(.pulse)
            
            // Message
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if message == L10n.Processing.finalizingFile {
                Text(L10n.Processing.largePDFWriteHint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(action.accentColor)
                
                Text(L10n.Processing.progress(progress))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Completed Content
    
    // MARK: - Completed Content
    
    private func completedFlexibleContent(
        resultURLs: [URL],
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        VStack(spacing: 12) {
            if resultURLs.isEmpty {
                SplitOutputListView(items: [], showsTotalCount: false)
            } else if action == .split {
                SplitOutputListView(
                    items: Self.splitOutputItems(from: resultURLs),
                    showsTotalCount: true
                )
                .frame(maxWidth: min(availableWidth * 0.9, 760), alignment: .leading)
            } else if resultURLs.count == 1, let firstURL = resultURLs.first {
                // Preview thumbnail for single-file outputs (Merge, Flatten, Edit Pages)
                // Calculate preview size: use available space with reasonable margins
                let aspectRatio: CGFloat = 0.75  // 3:4 ratio (portrait).
                
                // Use up to 80% of width
                let previewWidthFromContainer = availableWidth * 0.8
                
                // Keep some breathing room so preview fits without scrolling.
                let previewHeightFromSpace = max(180, availableHeight - 32)
                
                let previewWidthFromHeight = previewHeightFromSpace * aspectRatio
                
                // Take the smaller to fit both constraints
                let finalWidth = min(previewWidthFromHeight, previewWidthFromContainer)
                let finalHeight = finalWidth / aspectRatio
                
                OutputPreviewView(
                    url: firstURL,
                    size: CGSize(width: finalWidth, height: finalHeight)
                )
            } else {
                SplitOutputListView(
                    items: Self.splitOutputItems(from: resultURLs),
                    showsTotalCount: true
                )
                .frame(maxWidth: min(availableWidth * 0.9, 760), alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Failed Content
    
    private func failedContent(errorMessage: String) -> some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            // Title
            Text(L10n.Processing.somethingWentWrong)
                .font(.title2)
                .fontWeight(.bold)
            
            // Error message
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
            
        case .processing:
            Button {
                showCancelConfirmation = true
            } label: {
                Text(L10n.Action.cancel)
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
        case .completed(let resultURLs):
            completedActionButtons(resultURLs: resultURLs)
            
        case .failed:
            VStack(spacing: 12) {
                // Retry button
                Button {
                    Task {
                        await viewModel.execute(
                            action: action,
                            files: files,
                            options: options
                        )
                    }
                } label: {
                    Text(L10n.Action.retry)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(action.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text(L10n.Action.close)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
        case .cancelled:
            EmptyView()
        }
    }
    
    // MARK: - Completed Action Buttons
    
    @ViewBuilder
    private func completedActionButtons(resultURLs: [URL]) -> some View {
        VStack(spacing: 12) {
            // Summary and File Info (pinned to bottom with buttons)
            VStack(spacing: 4) {
                if resultURLs.count == 1 {
                    Text(L10n.Processing.readyToSave)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(L10n.Processing.filesCreated(resultURLs.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let firstURL = resultURLs.first,
                   let fileSize = try? FileManager.default.attributesOfItem(atPath: firstURL.path)[.size] as? Int64 {
                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            #if os(macOS)
            // macOS: Save button using NSSavePanel
            Button {
                saveFileOnMacOS(urls: resultURLs)
            } label: {
                Label(Self.saveButtonTitle(for: resultURLs.count), systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(action.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            #else
            // iOS: Share button
            Button {
                showShareSheet = true
            } label: {
                Label(L10n.Processing.share, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(action.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: resultURLs) { completed in
                    if completed {
                        attemptReviewPrompt()
                    }
                }
            }
            #endif
        }
    }
    
    // MARK: - Helper Properties
    
    private var saveSuccessTitle: String {
        Self.saveSuccessTitle(for: savedOutputURLs.count)
    }

    private var saveSuccessMessage: String {
        Self.saveSuccessMessage(for: savedOutputURLs.count)
    }

    static func saveButtonTitle(for outputCount: Int) -> String {
        outputCount > 1 ? L10n.Action.saveFiles : L10n.Action.saveFile
    }

    static func saveSuccessTitle(for savedCount: Int) -> String {
        savedCount > 1 ? L10n.Processing.filesSaved : L10n.Processing.fileSaved
    }

    static func saveSuccessMessage(for savedCount: Int) -> String {
        savedCount > 1
            ? L10n.Processing.filesSavedMessage(savedCount)
            : L10n.Processing.fileSavedMessage
    }

    static func splitOutputItems(from resultURLs: [URL]) -> [SplitOutputListView.Item] {
        resultURLs.map { url in
            .init(name: url.lastPathComponent, detail: splitOutputDetail(for: url))
        }
    }

    private static func splitOutputDetail(for url: URL) -> String {
        if let document = PDFDocument(url: url) {
            return L10n.Plural.pages(document.pageCount)
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }

        return L10n.Processing.previewNotAvailable
    }
    
    private func attemptReviewPrompt() {
        Task {
            // slight delay to ensure sheet/save panel interaction is fully finished
            try? await Task.sleep(for: .seconds(0.5))
            
            if await AppStoreReviewManager.shared.shouldShowAndMarkReviewPrompt() {
                requestReview()
            }
        }
    }
    
    // MARK: - macOS File Saving
    
    #if os(macOS)
    private func saveFileOnMacOS(urls: [URL]) {
        guard !urls.isEmpty else { return }

        if urls.count == 1, let singleURL = urls.first {
            saveSingleFileOnMacOS(url: singleURL)
            return
        }

        saveMultipleFilesOnMacOS(urls: urls)
    }

    private func saveSingleFileOnMacOS(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    let fileManager = FileManager.default

                    if fileManager.fileExists(atPath: destinationURL.path) {
                        _ = try fileManager.replaceItemAt(
                            destinationURL,
                            withItemAt: url,
                            backupItemName: nil,
                            options: []
                        )
                    } else {
                        try fileManager.moveItem(at: url, to: destinationURL)
                    }

                    savedOutputURLs = [destinationURL]
                    showFileSaveSuccess = true

                    // Trigger review prompt on success
                    attemptReviewPrompt()
                } catch {
                    saveErrorMessage = L10n.Processing.couldNotSaveFile(error.localizedDescription)
                }
            }
        }
    }

    private func saveMultipleFilesOnMacOS(urls: [URL]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = L10n.Processing.selectDestinationFolder
        panel.prompt = L10n.Action.saveFiles

        panel.begin { response in
            guard response == .OK, let destinationDirectory = panel.url else { return }

            do {
                let saved = try destinationDirectory.withSecurityScope {
                    try OutputFileSaver().saveAll(
                        urls,
                        to: destinationDirectory,
                        conflictPolicy: .autoRename
                    )
                }

                savedOutputURLs = saved
                showFileSaveSuccess = true

                // Trigger review prompt on success
                attemptReviewPrompt()
            } catch {
                saveErrorMessage = L10n.Processing.couldNotSaveFile(error.localizedDescription)
            }
        }
    }
    #endif
}

// MARK: - iOS Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview("Processing") {
    ProcessingView(
        action: .merge,
        files: [],
        options: .merge(outputFileName: "Combined")
    )
}

#Preview("Completed") {
    // This preview won't show completed state without mocking
    ProcessingView(
        action: .split,
        files: [],
        options: .split(mode: .splitEvery(n: 1))
    )
}
