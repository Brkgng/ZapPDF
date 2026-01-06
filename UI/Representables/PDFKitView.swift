//
//  PDFKitView.swift
//  ZapPDF
//
//  SwiftUI representable wrapper for PDFKit's PDFView.
//

import SwiftUI
import PDFKit

// MARK: - Display Mode

/// Display modes for PDF viewing.
enum PDFDisplayModeOption: Int, CaseIterable, Identifiable {
    case singlePage
    case singlePageContinuous
    case twoUp
    case twoUpContinuous
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .singlePage:
            return L10n.PDFDisplay.singlePage
        case .singlePageContinuous:
            return L10n.PDFDisplay.continuous
        case .twoUp:
            return L10n.PDFDisplay.twoPages
        case .twoUpContinuous:
            return L10n.PDFDisplay.twoPagesContinuous
        }
    }
    
    var pdfDisplayMode: PDFDisplayMode {
        switch self {
        case .singlePage:
            return .singlePage
        case .singlePageContinuous:
            return .singlePageContinuous
        case .twoUp:
            return .twoUp
        case .twoUpContinuous:
            return .twoUpContinuous
        }
    }
}

// MARK: - PDFKitView

/// A SwiftUI view that displays a PDF document using PDFKit.
///
/// `PDFKitView` wraps the native `PDFView` from PDFKit and provides
/// a SwiftUI-friendly interface with bindings for page navigation
/// and configuration options.
///
/// Example:
/// ```swift
/// @State private var currentPage = 0
///
/// PDFKitView(url: pdfURL, currentPage: $currentPage)
///     .frame(maxWidth: .infinity, maxHeight: .infinity)
///
/// // With display mode
/// PDFKitView(url: pdfURL, displayMode: .twoUpContinuous)
/// ```
struct PDFKitView: View {
    
    // MARK: - Properties
    
    /// URL of the PDF document to display.
    let url: URL
    
    /// Display mode for the PDF view.
    var displayMode: PDFDisplayModeOption = .singlePageContinuous
    
    /// Whether to auto-scale the PDF to fit the container.
    var autoScales: Bool = true
    
    /// Background color for the PDF view.
    var backgroundColor: Color = .clear
    
    /// Binding to the current page index (zero-based).
    @Binding var currentPage: Int
    
    /// Total number of pages in the document.
    @State private var totalPages: Int = 0
    
    // MARK: - Body
    
    var body: some View {
        PDFKitViewRepresentable(
            url: url,
            displayMode: displayMode.pdfDisplayMode,
            autoScales: autoScales,
            backgroundColor: backgroundColor,
            currentPage: $currentPage,
            totalPages: $totalPages
        )
        .accessibilityLabel(L10n.Accessibility.pdfDocument)
        .accessibilityHint(L10n.Accessibility.displayingPages(totalPages))
    }
}

// MARK: - Simple Initializer (without page binding)

extension PDFKitView {
    /// Creates a PDFKitView without page navigation binding.
    init(
        url: URL,
        displayMode: PDFDisplayModeOption = .singlePageContinuous,
        autoScales: Bool = true,
        backgroundColor: Color = .clear
    ) {
        self.url = url
        self.displayMode = displayMode
        self.autoScales = autoScales
        self.backgroundColor = backgroundColor
        self._currentPage = .constant(0)
    }
}

// MARK: - Platform-Specific Representable

#if os(macOS)

/// macOS implementation using NSViewRepresentable.
struct PDFKitViewRepresentable: NSViewRepresentable {
    let url: URL
    let displayMode: PDFDisplayMode
    let autoScales: Bool
    let backgroundColor: Color
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configurePDFView(pdfView)
        loadDocument(into: pdfView, context: context)
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update display mode if changed
        if pdfView.displayMode != displayMode {
            pdfView.displayMode = displayMode
        }
        
        // Update auto-scaling
        pdfView.autoScales = autoScales
        
        // Navigate to page if binding changed
        updateCurrentPage(pdfView, context: context)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func configurePDFView(_ pdfView: PDFView) {
        pdfView.displayMode = displayMode
        pdfView.autoScales = autoScales
        pdfView.displayDirection = .vertical
        
        // Set background color
        if backgroundColor != .clear {
            pdfView.backgroundColor = NSColor(backgroundColor)
        }
    }
    
    private func loadDocument(into pdfView: PDFView, context: Context) {
        // Access file with security scope
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return
        }
        
        pdfView.document = document
        
        // Update total pages
        DispatchQueue.main.async {
            totalPages = document.pageCount
        }
        
        // Set up notification for page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }
    
    private func updateCurrentPage(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document,
              currentPage >= 0,
              currentPage < document.pageCount,
              let page = document.page(at: currentPage) else {
            return
        }
        
        // Only navigate if the current page doesn't match
        if pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: PDFKitViewRepresentable
        
        init(_ parent: PDFKitViewRepresentable) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            
            let pageIndex = document.index(for: currentPage)
            
            DispatchQueue.main.async {
                if self.parent.currentPage != pageIndex {
                    self.parent.currentPage = pageIndex
                }
            }
        }
    }
}

#else

/// iOS/iPadOS implementation using UIViewRepresentable.
struct PDFKitViewRepresentable: UIViewRepresentable {
    let url: URL
    let displayMode: PDFDisplayMode
    let autoScales: Bool
    let backgroundColor: Color
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configurePDFView(pdfView)
        loadDocument(into: pdfView, context: context)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update display mode if changed
        if pdfView.displayMode != displayMode {
            pdfView.displayMode = displayMode
        }
        
        // Update auto-scaling
        pdfView.autoScales = autoScales
        
        // Navigate to page if binding changed
        updateCurrentPage(pdfView, context: context)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func configurePDFView(_ pdfView: PDFView) {
        pdfView.displayMode = displayMode
        pdfView.autoScales = autoScales
        pdfView.displayDirection = .vertical
        pdfView.pageShadowsEnabled = true
        
        // Set background color
        if backgroundColor != .clear {
            pdfView.backgroundColor = UIColor(backgroundColor)
        }
    }
    
    private func loadDocument(into pdfView: PDFView, context: Context) {
        // Access file with security scope
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            return
        }
        
        pdfView.document = document
        
        // Update total pages
        DispatchQueue.main.async {
            totalPages = document.pageCount
        }
        
        // Set up notification for page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }
    
    private func updateCurrentPage(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document,
              currentPage >= 0,
              currentPage < document.pageCount,
              let page = document.page(at: currentPage) else {
            return
        }
        
        // Only navigate if the current page doesn't match
        if pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: PDFKitViewRepresentable
        
        init(_ parent: PDFKitViewRepresentable) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            
            let pageIndex = document.index(for: currentPage)
            
            DispatchQueue.main.async {
                if self.parent.currentPage != pageIndex {
                    self.parent.currentPage = pageIndex
                }
            }
        }
    }
}

#endif

// MARK: - PDF Viewer with Controls

/// A PDF viewer with navigation controls and page indicator.
struct PDFViewerWithControls: View {
    let url: URL
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var displayMode: PDFDisplayModeOption = .singlePageContinuous
    
    var body: some View {
        VStack(spacing: 0) {
            // PDF View
            PDFKitViewRepresentable(
                url: url,
                displayMode: displayMode.pdfDisplayMode,
                autoScales: true,
                backgroundColor: .gray.opacity(0.1),
                currentPage: $currentPage,
                totalPages: $totalPages
            )
            
            // Controls
            HStack {
                // Previous page
                Button {
                    if currentPage > 0 {
                        currentPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage == 0)
                
                Spacer()
                
                // Page indicator
                Text(L10n.PageReorder.pageOf(currentPage + 1, totalPages))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Next page
                Button {
                    if currentPage < totalPages - 1 {
                        currentPage += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage >= totalPages - 1)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}

// MARK: - Preview

#Preview("PDF Viewer") {
    // Note: This preview requires an actual PDF file to work
    // In a real environment, provide a valid PDF URL
    let testURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    
    return PDFKitView(url: testURL)
        .frame(width: 400, height: 600)
}

#Preview("PDF Viewer with Controls") {
    let testURL = URL(fileURLWithPath: "/tmp/sample.pdf")
    
    return PDFViewerWithControls(url: testURL)
        .frame(width: 400, height: 600)
}
