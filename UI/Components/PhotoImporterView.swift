//
//  PhotoImporterView.swift
//  ZapPDF
//
//  SwiftUI wrapper for PHPickerViewController.
//

#if os(iOS)
import SwiftUI
import PhotosUI

/// SwiftUI wrapper for PHPickerViewController.
///
/// Allows importing images from Photo Library to convert to PDF.
/// Returns item providers so conversion can stream image loading.
///
/// Example:
/// ```swift
/// .sheet(isPresented: $showPhotoImporter) {
///     PhotoImporterView(
///         isPresented: $showPhotoImporter,
///         onItemProvidersSelected: { providers in ... }
///     )
/// }
/// ```
@available(iOS 17.0, *)
struct PhotoImporterView: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    let onItemProvidersSelected: ([NSItemProvider]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        // Limit selection to 50 images to balance UX and memory constraints
        // Rationale:
        // - UIImage objects consume significant memory (~2-5MB per image depending on resolution)
        // - 50 images at average 3MB each = ~150MB memory footprint during processing
        // - Allows users to convert entire photo albums while avoiding memory pressure on low-memory devices
        // - PHPickerViewController doesn't enforce memory limits, so we must set reasonable bounds
        // - Users can perform multiple imports if needed for larger collections
        config.selectionLimit = 50
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator

        // Configure accessibility
        picker.title = L10n.Scanner.importFromPhotos
        picker.accessibilityLabel = L10n.Scanner.importFromPhotos

        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoImporterView
        
        init(_ parent: PhotoImporterView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard !results.isEmpty else { return }

            let providers = results.map(\.itemProvider)
            parent.onItemProvidersSelected(providers)
        }
    }
}
#endif
