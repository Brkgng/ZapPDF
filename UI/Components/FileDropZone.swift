//
//  FileDropZone.swift
//  ZapPDF
//
//  Drag and drop zone for adding PDF files with platform-specific implementations.
//

import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop zone for adding PDF files.
///
/// `FileDropZone` provides a visual drop target for PDF files with platform-specific
/// implementations. On macOS, it uses `onDrop`; on iOS, it uses `dropDestination`.
/// It also provides a file picker button as a fallback input method.
///
/// Example:
/// ```swift
/// @State private var showFilePicker = false
///
/// FileDropZone(
///     isEmpty: viewModel.selectedFiles.isEmpty,
///     isTargeted: $isDropTargeted
/// ) { urls in
///     Task {
///         await viewModel.addFiles(urls: urls)
///     }
/// } onPickerRequested: {
///     showFilePicker = true
/// }
/// .fileImporter(isPresented: $showFilePicker, ...) { ... }
/// ```
struct FileDropZone: View {
    
    // MARK: - Properties
    
    /// Whether the drop zone is empty (no files added yet).
    let isEmpty: Bool
    
    /// Binding to track if a drag is currently over the drop zone.
    @Binding var isTargeted: Bool
    
    /// Callback when files are dropped onto the zone.
    var onFilesDropped: ([URL]) -> Void
    
    /// Callback when the file picker button is tapped.
    var onPickerRequested: () -> Void
    
    /// Accepted file types (defaults to PDF only).
    var acceptedTypes: [UTType] = [.pdf]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Content
            if isEmpty {
                emptyStateView
            }
        }
        .frame(minHeight: 200)
        .dropTargetHighlight(isTargeted: isTargeted)
        .modifier(DropHandlerModifier(
            isTargeted: $isTargeted,
            acceptedTypes: acceptedTypes,
            onDrop: handleDrop
        ))
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: isEmpty ? [8, 4] : [])
                    )
            )
    }
    
    private var backgroundFill: Color {
        if isTargeted {
            return Color.accentColor.opacity(0.1)
        } else {
            #if os(macOS)
            return Color(nsColor: .controlBackgroundColor)
            #else
            return Color(uiColor: .secondarySystemGroupedBackground)
            #endif
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: isTargeted ? "arrow.down.doc" : "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .accentColor : .secondary)
                .symbolEffect(.bounce, value: isTargeted)
            
            // Title
            Text(isTargeted ? "Drop PDF files here" : "Add PDF Files")
                .font(.headline)
                .foregroundColor(isTargeted ? .accentColor : .primary)
            
            // Subtitle
            Text("Drag and drop PDF files or use the button below")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // File Picker Button
            Button {
                onPickerRequested()
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
            .buttonStyle(.primary)
            .padding(.top, 8)
        }
        .padding(32)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
    
    // MARK: - Drop Handler
    
    private func handleDrop(urls: [URL]) {
        // Filter to only PDF files
        let pdfURLs = urls.filter { url in
            guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
                // Fallback to extension check
                return url.pathExtension.lowercased() == "pdf"
            }
            
            if let utType = UTType(typeIdentifier) {
                return utType.conforms(to: .pdf)
            }
            
            return url.pathExtension.lowercased() == "pdf"
        }
        
        if !pdfURLs.isEmpty {
            onFilesDropped(pdfURLs)
        }
    }
}

// MARK: - Platform-Specific Drop Handler

/// A ViewModifier that handles drag-and-drop with platform-specific implementations.
private struct DropHandlerModifier: ViewModifier {
    @Binding var isTargeted: Bool
    let acceptedTypes: [UTType]
    let onDrop: ([URL]) -> Void
    
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
                handleProviders(providers)
            }
        #else
        content
            .dropDestination(for: URL.self) { items, location in
                onDrop(items)
                return !items.isEmpty
            } isTargeted: { targeted in
                isTargeted = targeted
            }
        #endif
    }
    
    #if os(macOS)
    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        var loadedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        loadedURLs.append(url)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if !loadedURLs.isEmpty {
                onDrop(loadedURLs)
            }
        }
        
        return true
    }
    #endif
}

// MARK: - File Drop Zone with Content Overlay

/// A file drop zone that shows content (like a file list) when not empty.
struct FileDropZoneWithContent<Content: View>: View {
    let isEmpty: Bool
    @Binding var isTargeted: Bool
    var onFilesDropped: ([URL]) -> Void
    var onPickerRequested: () -> Void
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        ZStack {
            if isEmpty {
                FileDropZone(
                    isEmpty: true,
                    isTargeted: $isTargeted,
                    onFilesDropped: onFilesDropped,
                    onPickerRequested: onPickerRequested
                )
            } else {
                // Show content with drop overlay
                content()
                    .modifier(DropHandlerModifier(
                        isTargeted: $isTargeted,
                        acceptedTypes: [.pdf],
                        onDrop: onFilesDropped
                    ))
                    .overlay {
                        if isTargeted {
                            dropOverlay
                        }
                    }
            }
        }
    }
    
    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.15)
            
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Drop to add more files")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Empty State") {
    @Previewable @State var isTargeted = false
    
    FileDropZone(
        isEmpty: true,
        isTargeted: $isTargeted
    ) { urls in
        print("Dropped: \(urls)")
    } onPickerRequested: {
        print("Picker requested")
    }
    .padding()
}

#Preview("Targeted State") {
    @Previewable @State var isTargeted = true
    
    FileDropZone(
        isEmpty: true,
        isTargeted: $isTargeted
    ) { urls in
        print("Dropped: \(urls)")
    } onPickerRequested: {
        print("Picker requested")
    }
    .padding()
}

#Preview("With Content") {
    @Previewable @State var isTargeted = false
    
    let mockFiles = [
        PDFFile(
            url: URL(fileURLWithPath: "/tmp/Doc1.pdf"),
            fileName: "Document 1.pdf",
            pageCount: 5,
            fileSize: 500_000
        ),
        PDFFile(
            url: URL(fileURLWithPath: "/tmp/Doc2.pdf"),
            fileName: "Document 2.pdf",
            pageCount: 10,
            fileSize: 1_000_000
        )
    ]
    
    FileDropZoneWithContent(
        isEmpty: false,
        isTargeted: $isTargeted,
        onFilesDropped: { _ in },
        onPickerRequested: { }
    ) {
        VStack(spacing: 0) {
            ForEach(mockFiles) { file in
                PDFFileRow(pdfFile: file)
                Divider()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
