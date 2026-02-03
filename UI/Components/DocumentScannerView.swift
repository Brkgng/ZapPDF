//
//  DocumentScannerView.swift
//  ZapPDF
//
//  SwiftUI wrapper for VNDocumentCameraViewController.
//

#if os(iOS)
import SwiftUI
import VisionKit

/// SwiftUI wrapper for VNDocumentCameraViewController.
///
/// iOS/iPadOS only. Presents the system document scanner.
///
/// Example:
/// ```swift
/// .fullScreenCover(isPresented: $showScanner) {
///     DocumentScannerView(
///         isPresented: $showScanner,
///         onScanCompleted: { scan in ... },
///         onCancelled: { },
///         onError: { error in ... }
///     )
/// }
/// ```
@available(iOS 17.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    let onScanCompleted: (VNDocumentCameraScan) -> Void
    let onCancelled: () -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator

        // Configure accessibility
        scanner.title = L10n.Scanner.scanDocument
        scanner.accessibilityLabel = L10n.Scanner.scanDocument

        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            parent.isPresented = false
            parent.onScanCompleted(scan)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
            parent.onCancelled()
        }
        
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.isPresented = false
            parent.onError(error)
        }
    }
}
#endif
