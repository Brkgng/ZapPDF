//
//  ScanProcessingOverlay.swift
//  ZapPDF
//
//  Loading overlay shown during PDF conversion.
//

#if os(iOS)
import SwiftUI

/// Overlay shown while processing scanned images into PDF.
///
/// Provides visual feedback during the PDF conversion process
/// to indicate that the app is working. Can display optional
/// progress percentage for longer operations.
struct ScanProcessingOverlay: View {
    /// Optional progress value from 0.0 to 1.0. If nil, shows indeterminate progress.
    var progress: Double?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if let progress {
                    // Show determinate progress with percentage
                    ProgressView(value: progress)
                        .scaleEffect(1.5)
                        .tint(.white)
                        .accessibilityLabel("Creating PDF progress")
                        .accessibilityValue("\(Int(progress * 100)) percent")

                    let percentage = Int(progress * 100)
                    Text("\(L10n.Scanner.processing) \(percentage)%")
                        .font(.headline)
                        .foregroundColor(.white)
                        .accessibilityLabel("Creating PDF \(percentage) percent complete")
                } else {
                    // Show indeterminate progress
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                        .accessibilityLabel("Creating PDF")

                    Text(L10n.Scanner.processing)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityIdentifier("scanProcessingOverlay")
        .accessibilityLabel("Scan processing overlay")
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}

#Preview("Indeterminate") {
    ScanProcessingOverlay()
}

#Preview("With Progress") {
    ScanProcessingOverlay(progress: 0.47)
}
#endif
