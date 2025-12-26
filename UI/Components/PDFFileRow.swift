//
//  PDFFileRow.swift
//  ZapPDF
//
//  List row component for displaying a PDF file with thumbnail, name, and metadata.
//

import SwiftUI

/// A list row view for displaying PDF file information.
///
/// `PDFFileRow` shows a thumbnail, file name, page count, and file size
/// in a compact row format suitable for lists and file browsers.
/// It supports delete actions, drag handles for reordering, and context menus.
///
/// Example:
/// ```swift
/// List {
///     ForEach(pdfFiles) { file in
///         PDFFileRow(pdfFile: file) {
///             viewModel.removeFile(file)
///         }
///     }
/// }
///
/// // With drag handle for reordering
/// PDFFileRow(pdfFile: file, showDragHandle: true)
/// ```
struct PDFFileRow: View {
    
    // MARK: - Properties
    
    /// The PDF file to display.
    let pdfFile: PDFFile
    
    /// Whether to show a drag handle for reordering.
    var showDragHandle: Bool = false
    
    /// Whether to show the delete button.
    var showDeleteButton: Bool = true
    
    /// Callback when the delete button is tapped.
    var onDelete: (() -> Void)?
    
    /// Callback when the row is tapped.
    var onTap: (() -> Void)?
    
    // MARK: - Private State
    
    @State private var isHovered: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (if enabled)
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            
            // Thumbnail
            PDFThumbnailView(
                pdfFile: pdfFile,
                size: CGSize(width: 48, height: 64),
                showPageCount: false,
                cornerRadius: 4
            )
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(pdfFile.fileName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    // Page count
                    Label("\(pdfFile.pageCount) pages", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // File size
                    Text(pdfFile.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button (if enabled and has callback)
            if showDeleteButton, let onDelete = onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.6)
                .help("Remove file")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            openInFinder()
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        
        Button {
            copyFileName()
        } label: {
            Label("Copy Name", systemImage: "doc.on.doc")
        }
        
        if let onDelete = onDelete {
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func openInFinder() {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([pdfFile.url])
        #else
        // On iOS, we can't directly open Files app to a location
        // Instead, we could share the file or show a message
        #endif
    }
    
    private func copyFileName() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pdfFile.fileName, forType: .string)
        #else
        UIPasteboard.general.string = pdfFile.fileName
        #endif
    }
}

// MARK: - Compact Row Variant

/// A more compact row variant for dense file lists.
struct PDFFileRowCompact: View {
    let pdfFile: PDFFile
    var onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .font(.title3)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pdfFile.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text("\(pdfFile.pageCount) pages • \(pdfFile.formattedFileSize)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let onDelete = onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Swipe Actions Extension (iOS)

extension PDFFileRow {
    /// Adds swipe-to-delete functionality for iOS lists.
    @ViewBuilder
    func withSwipeToDelete() -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        #else
        self
        #endif
    }
}

// MARK: - Preview

#Preview("Standard Row") {
    let mockFile = PDFFile(
        url: URL(fileURLWithPath: "/tmp/Sample Document.pdf"),
        fileName: "Sample Document.pdf",
        pageCount: 15,
        fileSize: 2_450_000
    )
    
    return VStack(spacing: 0) {
        PDFFileRow(pdfFile: mockFile, onDelete: {
            print("Delete tapped")
        })
        Divider()
        PDFFileRow(pdfFile: mockFile, showDragHandle: true, onDelete: {
            print("Delete tapped")
        })
    }
    .padding()
}

#Preview("Compact Row") {
    let mockFile = PDFFile(
        url: URL(fileURLWithPath: "/tmp/Report.pdf"),
        fileName: "Annual Report 2024.pdf",
        pageCount: 42,
        fileSize: 5_600_000
    )
    
    return VStack(spacing: 8) {
        PDFFileRowCompact(pdfFile: mockFile, onDelete: {
            print("Delete tapped")
        })
        PDFFileRowCompact(pdfFile: mockFile)
    }
    .padding()
}

#Preview("Multiple Files") {
    let files = [
        PDFFile(
            url: URL(fileURLWithPath: "/tmp/Doc1.pdf"),
            fileName: "Document 1.pdf",
            pageCount: 5,
            fileSize: 500_000
        ),
        PDFFile(
            url: URL(fileURLWithPath: "/tmp/Doc2.pdf"),
            fileName: "A Very Long Document Name That Should Truncate.pdf",
            pageCount: 100,
            fileSize: 15_000_000
        ),
        PDFFile(
            url: URL(fileURLWithPath: "/tmp/Doc3.pdf"),
            fileName: "Short.pdf",
            pageCount: 1,
            fileSize: 50_000
        )
    ]
    
    return VStack(spacing: 0) {
        ForEach(files) { file in
            PDFFileRow(pdfFile: file, showDragHandle: true, onDelete: {
                print("Delete \(file.fileName)")
            })
            Divider()
        }
    }
    .padding()
}

