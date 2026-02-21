# ZapPDF

A privacy-first PDF utility app for macOS, iOS, and iPadOS.

## Features

- **Merge PDFs** - Combine multiple PDF files into one
- **Split PDFs** - Extract page ranges or split into individual pages
- **Edit Pages** - Reorder, rotate, and delete pages in a single file
- **Flatten PDFs** - Merge annotations and form content into page content
- **Share Sheet Support** - Open PDFs from Files, Mail, and other apps directly in ZapPDF
- **Document Scanning (iOS/iPadOS)** - Scan paper documents or import photos and save as PDF
- **Freemium Model** - 5 free actions, with Pro unlocking unlimited actions
- **In-App Language Switching** - English, Turkish, German, French, Spanish, Japanese, Chinese (Simplified)

## Requirements

- **macOS**: 14.0+
- **iOS/iPadOS**: 17.0+
- **Xcode**: Latest stable version recommended

## Getting Started

1. Clone the repository.
2. Open `ZapPDF.xcodeproj` in Xcode
3. Select a target device or simulator.
4. Build and run (`Cmd+R`).

The app runs without a RevenueCat key. Subscription purchases are disabled until a key is configured.

## Build and Test

```sh
# Debug build (macOS)
xcodebuild build -project ZapPDF.xcodeproj -scheme ZapPDF -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Full test suite (macOS)
xcodebuild test -project ZapPDF.xcodeproj -scheme ZapPDF -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Release build (macOS)
xcodebuild build -project ZapPDF.xcodeproj -scheme ZapPDF -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Optional RevenueCat Setup (Local Only)

1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`.
2. Fill your key in `Config/Secrets.xcconfig`:
   `REVENUECAT_API_KEY=your_public_sdk_key`
3. Provide the key at runtime using one of these methods:
   - Set `REVENUECAT_API_KEY` as an environment variable in your run scheme.
   - Add `REVENUECAT_API_KEY` to `Info.plist` (recommended through local build settings/xcconfig).

Never commit real keys or local secret files.

## Project Structure

The app follows MVVM architecture with a shared codebase:

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

## Security and Privacy

- All PDF processing happens locally on device.
- Files are not automatically uploaded to external servers.
- Subscription networking is limited to RevenueCat endpoints when an API key is configured.
- Keep API keys local (`Config/Secrets.xcconfig`, env vars, or local plist settings).

## License

[MIT](./LICENSE)
