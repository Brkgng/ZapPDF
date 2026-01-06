//
//  ProcessingView.swift
//  ZapPDF
//
//  Progress tracking screen with cancellation and completion handling.
//

import SwiftUI
import UniformTypeIdentifiers
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
    @State private var showCancelConfirmation = false
    @State private var showShareSheet = false
    @State private var showFileSaveSuccess = false
    @State private var savedFileURL: URL?
    @State private var saveErrorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // State-based content
                stateContent
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(32)
            .navigationTitle(action.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if canDismiss {
                        Button(L10n.Action.close) {
                            dismiss()
                        }
                    }
                }
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
            .alert(L10n.Processing.fileSaved, isPresented: $showFileSaveSuccess) {
                Button(L10n.Action.ok) {
                    dismiss()
                }
                #if os(macOS)
                if let savedURL = savedFileURL {
                    Button(L10n.Processing.revealInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting([savedURL])
                        dismiss()
                    }
                }
                #endif
            } message: {
                Text(L10n.Processing.fileSavedMessage)
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
    
    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle:
            idleContent
            
        case .processing(let progress, let message):
            processingContent(progress: progress, message: message)
            
        case .completed(let resultURLs):
            completedContent(resultURLs: resultURLs)
            
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
    
    private func completedContent(resultURLs: [URL]) -> some View {
        VStack(spacing: 24) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            // Title
            Text(L10n.Processing.completed)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Summary
            if resultURLs.count == 1 {
                Text(L10n.Processing.readyToSave)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(L10n.Processing.filesCreated(resultURLs.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // File info
            if let firstURL = resultURLs.first,
               let fileSize = try? FileManager.default.attributesOfItem(atPath: firstURL.path)[.size] as? Int64 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
            #if os(macOS)
            // macOS: Save button using NSSavePanel
            Button {
                saveFileOnMacOS(urls: resultURLs)
            } label: {
                Label(L10n.Action.saveFile, systemImage: "square.and.arrow.down")
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
                ShareSheet(items: resultURLs)
            }
            #endif
        }
    }
    
    // MARK: - Helper Properties
    
    private var canDismiss: Bool {
        switch viewModel.state {
        case .idle, .processing:
            return false
        case .completed, .failed, .cancelled:
            return true
        }
    }
    
    // MARK: - macOS File Saving
    
    #if os(macOS)
    private func saveFileOnMacOS(urls: [URL]) {
        guard let firstURL = urls.first else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = firstURL.lastPathComponent
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Remove existing file if needed
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.moveItem(at: firstURL, to: destinationURL)
                    savedFileURL = destinationURL
                    showFileSaveSuccess = true
                } catch {
                    saveErrorMessage = L10n.Processing.couldNotSaveFile(error.localizedDescription)
                }
            }
        }
    }
    #endif
}

// MARK: - iOS Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
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
