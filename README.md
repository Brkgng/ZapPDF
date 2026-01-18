# ZapPDF

A powerful, privacy-first PDF utility app for macOS, iOS, and iPadOS.

## Features

- **Merge PDFs** – Combine multiple PDF files into one
- **Split PDFs** – Extract page ranges or split into individual pages
- **Reorder Pages** – Drag-and-drop page reordering within a PDF
- **Flatten PDFs** – Merge layers and annotations into page content
- **Convert PDFs** – Transform PDFs to/from other formats
- **Share Sheet Support** – Open PDFs from Files, Mail, and other apps directly in ZapPDF

## Requirements

- **macOS**: 14.0+ (Sonoma)
- **iOS/iPadOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Architecture

The app follows **MVVM** architecture with a shared codebase for all Apple platforms:

```
ZapPDF/
├── App/           # Entry point, assets, entitlements
├── Common/        # Extensions and utilities
├── Models/        # Pure data structures
├── ViewModels/    # UI state and business logic coordination
├── Services/      # PDF engine, usage tracking, persistence
├── UI/            # SwiftUI views and components
└── Monetization/  # StoreKit/RevenueCat integration
```

## Getting Started

1. Clone the repository
2. Open `ZapPDF.xcodeproj` in Xcode
3. Select your target device/simulator
4. Build and run (⌘R)

## Development

See [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) for detailed technical specifications and development roadmap.

### Key Technical Highlights

- **PDFKit** for all PDF operations
- **Security-scoped resources** for sandboxed file access
- **async/await** with cancellation support
- **Type-safe localization** via `L10n` namespace (ready for 7 languages)
- **RevenueCat** for subscription management

## Privacy

ZapPDF is designed with privacy as a core principle:

- All PDF processing happens **locally on-device**
- No files are uploaded to any server
- No analytics or tracking beyond anonymous crash reports

## License

Proprietary – All rights reserved.
