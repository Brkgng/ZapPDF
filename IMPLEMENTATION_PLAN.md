# ZapPDF Implementation Plan

> **Living Document** – Update as development progresses. Last updated: 2025-12-26

---

## Table of Contents

1. [High-Level System Overview](#1-high-level-system-overview)
2. [Phase-by-Phase Roadmap](#2-phase-by-phase-roadmap)
3. [Layer Responsibilities](#3-layer-responsibilities)
4. [File Responsibilities & Public APIs](#4-file-responsibilities--public-apis)
5. [Data Flow Walkthroughs](#5-data-flow-walkthroughs)
6. [Concurrency Model](#6-concurrency-model)
7. [Error Handling Strategy](#7-error-handling-strategy)
8. [Security & Sandbox Considerations](#8-security--sandbox-considerations)
9. [Monetization Flow](#9-monetization-flow)
10. [Platform-Specific Differences](#10-platform-specific-differences)
11. [Testing Strategy](#11-testing-strategy)
12. [Performance & Memory](#12-performance--memory)
13. [Risks & Mitigation](#13-risks--mitigation)

---

## 1. High-Level System Overview

### 1.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ DashboardView│  │ProcessingView│  │  PaywallView │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼─────────────────┼─────────────────┼───────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ViewModels                               │
│  ┌──────────────────┐ ┌────────────────────┐ ┌───────────────┐ │
│  │DashboardViewModel│ │ProcessingViewModel │ │PaywallViewModel│ │
│  └────────┬─────────┘ └─────────┬──────────┘ └───────┬───────┘ │
└───────────┼─────────────────────┼────────────────────┼──────────┘
            │                     │                    │
            ▼                     ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Services                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  PDFEngine  │  │UsageManager │  │ RevenueCatManager       │ │
│  │ ┌─────────┐ │  └─────────────┘  └─────────────────────────┘ │
│  │ │ Merger  │ │                                               │
│  │ │Splitter │ │  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ │Compressor│  │KeychainHelper│  │  URL+Security Extension │ │
│  │ └─────────┘ │  └─────────────┘  └─────────────────────────┘ │
│  └─────────────┘                                               │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Core Principles

| Principle                    | Implementation                                                  |
| ---------------------------- | --------------------------------------------------------------- |
| **MVVM**                     | Views observe ViewModels; ViewModels call Services              |
| **Unidirectional Data Flow** | User Action → ViewModel → Service → ViewModel State → View      |
| **Platform Abstraction**     | Shared ViewModels/Services; Platform-specific UI via `#if os()` |
| **Async-First**              | All PDF operations use `async/await` with `Task` cancellation   |
| **Sandbox Compliance**       | Security-scoped URL access wrapped in `withSecurityScope {}`    |

### 1.3 Key Dependencies

- **PDFKit** – Core PDF manipulation (Apple framework)
- **CoreGraphics/Quartz** – PDF compression via `CGContext` and `CIFilter`
- **StoreKit 2** – In-app purchases (wrapped by RevenueCat)
- **RevenueCat SDK** – Subscription management
- **Security.framework** – Keychain access for usage tracking

---

## 2. Phase-by-Phase Roadmap

### Phase 0: Project Setup ✅

- [x] Create Xcode project with macOS + iOS targets
- [x] Configure folder structure
- [x] Add entitlements (sandbox, file access)
- [x] Configure build settings for Release/Debug

### Phase 1: Core Models & Extensions ✅

**Duration: 1-2 days** | Completed: 2024-12-24

- [x] `PDFFile.swift` – Identifiable wrapper for PDF URLs
- [x] `UserAction.swift` – Enum for merge/split/compress/convert
- [x] `URL+Security.swift` – Security-scoped resource helpers
- [x] `View+Modifiers.swift` – Shared view modifiers

### Phase 2: PDF Engine (Services)

**Duration: 3-5 days** | Completed: 2024-12-25

- [x] `PDFMerger.swift` – Combine multiple PDFs
- [x] `PDFSplitter.swift` – Extract page ranges
- [/] `PDFCompressor.swift` – Reduce file size via Quartz (Deferred)
- [x] `PDFRenderer.swift` – Thumbnail generation

### Phase 3: Persistence & Usage Tracking

**Duration: 1-2 days** | Completed: 2024-12-25

- [x] `KeychainHelper.swift` – Secure storage wrapper
- [x] `UsageManager.swift` – Track/decrement free actions

### Phase 4: ViewModels

**Duration: 2-3 days** | Completed: 2024-12-26

- [x] `DashboardViewModel.swift` – File selection state
- [x] `ProcessingViewModel.swift` – Progress/cancellation
- [x] `PaywallViewModel.swift` – Purchase state

### Phase 5: UI Components

**Duration: 3-4 days** | Completed: 2024-12-26

- [x] `FileDropZone.swift` – Drag & drop (macOS)
- [x] `PDFThumbnailView.swift` – Async thumbnail loading
- [x] `ActionButton.swift` – Styled action buttons
- [x] `PDFFileRow.swift` – List row component for PDF files
- [x] `PDFKitView.swift` – NSViewRepresentable/UIViewRepresentable

### Phase 6: Screens

**Duration: 3-4 days**

- [ ] `DashboardView.swift` – Main file picker UI
- [ ] `ProcessingView.swift` – Progress + cancel
- [ ] `PaywallView.swift` – Subscription UI
- [ ] `OnboardingView.swift` – Privacy-first intro

### Phase 7: Monetization Integration

**Duration: 2-3 days**

- [ ] `RevenueCatManager.swift` – SDK wrapper
- [ ] `StoreConfiguration.swift` – Product IDs
- [ ] Paywall trigger logic integration

### Phase 8: Testing & Polish

**Duration: 3-5 days**

- [ ] Unit tests for Services
- [ ] Integration tests for ViewModels
- [ ] UI tests for critical flows
- [ ] Performance profiling

### Phase 9: App Store Preparation

**Duration: 2-3 days**

- [ ] App Store screenshots
- [ ] Privacy policy
- [ ] App Review notes
- [ ] TestFlight beta

---

## 3. Layer Responsibilities

### 3.1 App Layer (`App/`)

| File                 | Responsibility                                              |
| -------------------- | ----------------------------------------------------------- |
| `ZapPDFApp.swift`    | App entry point, environment injection, scene configuration |
| `Assets.xcassets`    | App icons, accent colors, image assets                      |
| `Entitlements.plist` | Sandbox permissions, file access rights                     |

### 3.2 Models Layer (`Models/`)

| File               | Responsibility                                    |
| ------------------ | ------------------------------------------------- |
| `PDFFile.swift`    | Immutable struct representing a PDF with metadata |
| `UserAction.swift` | Enumeration of available PDF operations           |

### 3.3 ViewModels Layer (`ViewModels/`)

| File                        | Responsibility                                                   |
| --------------------------- | ---------------------------------------------------------------- |
| `DashboardViewModel.swift`  | Manage selected files, validate selection, trigger actions       |
| `ProcessingViewModel.swift` | Execute PDF operations, report progress, handle cancellation     |
| `PaywallViewModel.swift`    | Check subscription status, initiate purchases, restore purchases |

### 3.4 Services Layer (`Services/`)

| File                   | Responsibility                           |
| ---------------------- | ---------------------------------------- |
| `PDFMerger.swift`      | Pure business logic for merging PDFs     |
| `PDFSplitter.swift`    | Pure business logic for splitting PDFs   |
| `PDFCompressor.swift`  | Apply Quartz filters to reduce file size |
| `UsageManager.swift`   | Track free tier usage, check limits      |
| `KeychainHelper.swift` | Secure storage abstraction               |

### 3.5 UI Layer (`UI/`)

| Folder            | Responsibility                           |
| ----------------- | ---------------------------------------- |
| `Components/`     | Reusable, stateless UI building blocks   |
| `Screens/`        | Full-screen views composed of components |
| `Representables/` | UIKit/AppKit wrappers for SwiftUI        |

### 3.6 Common Layer (`Common/`)

| Folder        | Responsibility                     |
| ------------- | ---------------------------------- |
| `Extensions/` | Swift extensions (URL, View, etc.) |
| `Utils/`      | Shared utilities (PDFRenderer)     |

### 3.7 Monetization Layer (`Monetization/`)

| File                       | Responsibility                          |
| -------------------------- | --------------------------------------- |
| `RevenueCatManager.swift`  | Singleton managing subscription state   |
| `StoreConfiguration.swift` | Product IDs, API keys (via environment) |

---

## 4. File Responsibilities & Public APIs

### 4.1 Models

#### `PDFFile.swift`

```swift
struct PDFFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let fileName: String
    let pageCount: Int
    let fileSize: Int64
    let thumbnail: Image?

    init(url: URL) async throws

    var isSecurityScoped: Bool { get }
}
```

#### `UserAction.swift`

```swift
enum UserAction: String, CaseIterable, Identifiable {
    case merge
    case split
    case compress
    case convert

    var id: String { rawValue }
    var displayName: String { get }
    var iconName: String { get }
    var requiresMultipleFiles: Bool { get }
}
```

### 4.2 Extensions

#### `URL+Security.swift`

```swift
extension URL {
    /// Execute closure with security-scoped resource access
    func withSecurityScope<T>(_ body: () throws -> T) rethrows -> T

    /// Async version for PDF operations
    func withSecurityScopeAsync<T>(_ body: () async throws -> T) async rethrows -> T

    /// Check if URL requires security scope
    var requiresSecurityScope: Bool { get }

    /// Create bookmark data for persistence
    func createBookmarkData() throws -> Data

    /// Resolve URL from bookmark data
    static func resolve(from bookmarkData: Data) throws -> URL
}
```

### 4.3 PDF Engine

#### `PDFMerger.swift`

```swift
actor PDFMerger {
    struct MergeOptions {
        var outputFileName: String
        var preserveBookmarks: Bool
    }

    func merge(
        files: [PDFFile],
        options: MergeOptions,
        progress: @escaping (Double) -> Void
    ) async throws -> URL

    func cancel()
}
```

#### `PDFSplitter.swift`

```swift
actor PDFSplitter {
    enum SplitMode {
        case byPageRange(ranges: [ClosedRange<Int>])
        case extractPages(indices: [Int])
        case splitEvery(n: Int)
    }

    func split(
        file: PDFFile,
        mode: SplitMode,
        progress: @escaping (Double) -> Void
    ) async throws -> [URL]

    func cancel()
}
```

#### `PDFCompressor.swift`

```swift
actor PDFCompressor {
    enum CompressionLevel {
        case low      // ~80% of original
        case medium   // ~50% of original
        case high     // ~30% of original
        case maximum  // ~15% of original (quality loss)
    }

    func compress(
        file: PDFFile,
        level: CompressionLevel,
        progress: @escaping (Double) -> Void
    ) async throws -> URL

    func estimatedOutputSize(for file: PDFFile, level: CompressionLevel) -> Int64

    func cancel()
}
```

### 4.4 ViewModels

#### `DashboardViewModel.swift`

```swift
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var selectedFiles: [PDFFile] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    func addFiles(urls: [URL]) async
    func removeFile(_ file: PDFFile)
    func reorderFiles(from: IndexSet, to: Int)
    func clearAll()

    func canPerform(action: UserAction) -> Bool
    func startAction(_ action: UserAction) async throws
}
```

#### `ProcessingViewModel.swift`

```swift
@MainActor
final class ProcessingViewModel: ObservableObject {
    enum State {
        case idle
        case processing(progress: Double, message: String)
        case completed(resultURLs: [URL])
        case failed(error: AppError)
        case cancelled
    }

    @Published private(set) var state: State = .idle

    func execute(
        action: UserAction,
        files: [PDFFile],
        options: ActionOptions
    ) async

    func cancel()
    func reset()
}
```

#### `PaywallViewModel.swift`

```swift
@MainActor
final class PaywallViewModel: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState {
        case idle
        case purchasing
        case restoring
        case success
        case failed(Error)
    }

    func loadProducts() async
    func purchase(product: Product) async
    func restorePurchases() async

    var remainingFreeActions: Int { get }
}
```

### 4.5 Services

#### `UsageManager.swift`

```swift
actor UsageManager {
    static let shared = UsageManager()

    private let freeActionLimit = 5

    func remainingActions() async -> Int
    func canPerformAction() async -> Bool
    func recordAction() async throws
    func resetUsage() async // For testing only
}
```

#### `KeychainHelper.swift`

```swift
enum KeychainHelper {
    enum Key: String {
        case actionsRemaining
        case proSubscriptionReceipt
    }

    static func save(_ data: Data, for key: Key) throws
    static func load(for key: Key) throws -> Data?
    static func delete(for key: Key) throws
    static func exists(for key: Key) -> Bool
}
```

### 4.6 Monetization

#### `RevenueCatManager.swift`

```swift
@MainActor
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?

    var isPro: Bool { get }

    func configure()
    func fetchOfferings() async throws
    func purchase(package: Package) async throws
    func restorePurchases() async throws
    func checkEntitlements() async
}
```

---

## 5. Data Flow Walkthroughs

### 5.1 Merge Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1. User drops PDF files onto FileDropZone                            │
│    └─> DashboardView receives URLs                                   │
│        └─> DashboardViewModel.addFiles(urls:)                        │
│            └─> URL.withSecurityScope { create PDFFile }              │
│                └─> PDFFile stored in @Published selectedFiles        │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 2. User taps "Merge" button                                          │
│    └─> DashboardViewModel.canPerform(.merge) returns true            │
│        └─> UsageManager.canPerformAction() checked                   │
│            ├─> If false → Show PaywallView                           │
│            └─> If true → Navigate to ProcessingView                  │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 3. ProcessingView appears                                            │
│    └─> ProcessingViewModel.execute(.merge, files, options)           │
│        └─> PDFMerger.merge(files:options:progress:)                  │
│            ├─> For each file: URL.withSecurityScopeAsync { }         │
│            ├─> Merge pages using PDFDocument.insert()                │
│            ├─> Report progress via callback                          │
│            └─> Write to temp directory, return URL                   │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 4. Completion                                                        │
│    └─> ProcessingViewModel.state = .completed(resultURLs)            │
│        └─> UsageManager.recordAction() called                        │
│            └─> ProcessingView shows "Save" button                    │
│                └─> User picks save location via NSSavePanel          │
└──────────────────────────────────────────────────────────────────────┘
```

### 5.2 Split Flow

```
1. User selects single PDF
   └─> DashboardViewModel updates selectedFiles

2. User taps "Split"
   └─> SplitOptionsSheet presented
       └─> User selects: byPageRange / extractPages / splitEvery

3. User confirms options
   └─> UsageManager.canPerformAction() checked
   └─> ProcessingViewModel.execute(.split, ...)
       └─> PDFSplitter.split(file:mode:progress:)
           └─> Creates multiple PDFDocuments
           └─> Returns [URL] for each output file

4. Completion
   └─> User can save all files to folder (macOS: NSOpenPanel folder mode)
   └─> iOS: Share sheet with multiple files
```

### 5.3 Compress Flow

```
1. User selects PDF(s)
   └─> DashboardViewModel updates selectedFiles

2. User taps "Compress"
   └─> CompressionOptionsSheet presented
       └─> Shows estimated output size per level
       └─> PDFCompressor.estimatedOutputSize(...) called

3. User selects compression level
   └─> UsageManager.canPerformAction() checked
   └─> ProcessingViewModel.execute(.compress, ...)
       └─> PDFCompressor.compress(file:level:progress:)
           └─> Apply Quartz filters:
               - CIFilter for image downsampling
               - CGContext for re-rendering
           └─> Returns URL to compressed file

4. Completion
   └─> Show before/after size comparison
   └─> User saves file
```

---

## 6. Concurrency Model

### 6.1 Task Hierarchy

```swift
// ProcessingViewModel
func execute(action: UserAction, files: [PDFFile], options: ActionOptions) async {
    // Create cancellable task
    processingTask = Task {
        do {
            // Check for cancellation before starting
            try Task.checkCancellation()

            let result = try await performAction(action, files: files, options: options)

            // Check again before updating state
            try Task.checkCancellation()

            await MainActor.run {
                self.state = .completed(resultURLs: result)
            }
        } catch is CancellationError {
            await MainActor.run {
                self.state = .cancelled
            }
        } catch {
            await MainActor.run {
                self.state = .failed(error: AppError(error))
            }
        }
    }

    await processingTask?.value
}

func cancel() {
    processingTask?.cancel()
    merger.cancel()
    splitter.cancel()
    compressor.cancel()
}
```

### 6.2 Progress Reporting

```swift
// PDFMerger (actor)
func merge(
    files: [PDFFile],
    options: MergeOptions,
    progress: @escaping @Sendable (Double) -> Void
) async throws -> URL {
    let totalPages = files.reduce(0) { $0 + $1.pageCount }
    var processedPages = 0

    for file in files {
        try Task.checkCancellation()

        try await file.url.withSecurityScopeAsync {
            guard let pdf = PDFDocument(url: file.url) else {
                throw PDFEngineError.invalidPDF(file.url)
            }

            for pageIndex in 0..<pdf.pageCount {
                try Task.checkCancellation()

                // Insert page...
                processedPages += 1

                await MainActor.run {
                    progress(Double(processedPages) / Double(totalPages))
                }
            }
        }
    }

    return outputURL
}
```

### 6.3 Actor Isolation

```swift
// All PDF engine components are actors for thread safety
actor PDFMerger {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    private func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }
}
```

### 6.4 MainActor Annotations

- **ViewModels**: All `@MainActor`
- **Views**: Implicit `@MainActor`
- **Services**: Actor-isolated (not MainActor)
- **Models**: Value types (Sendable by default)

---

## 7. Error Handling Strategy

### 7.1 Error Type Hierarchy

```swift
enum AppError: LocalizedError {
    // PDF Engine Errors
    case pdfEngineError(PDFEngineError)

    // File Access Errors
    case fileAccessError(FileAccessError)

    // Usage/Monetization Errors
    case usageLimitReached
    case purchaseError(PurchaseError)

    // Generic
    case unknown(Error)

    var errorDescription: String? {
        // User-friendly messages
    }

    var recoverySuggestion: String? {
        // Actionable next steps
    }
}

enum PDFEngineError: Error {
    case invalidPDF(URL)
    case passwordProtected(URL)
    case corruptedFile(URL)
    case insufficientDiskSpace
    case compressionFailed(reason: String)
    case writeFailed(URL)
}

enum FileAccessError: Error {
    case securityScopeAccessDenied(URL)
    case bookmarkResolutionFailed
    case fileNotFound(URL)
    case permissionDenied(URL)
}
```

### 7.2 Error Translation

| Technical Error             | User Message                                                      |
| --------------------------- | ----------------------------------------------------------------- |
| `securityScopeAccessDenied` | "Unable to access file. Please re-select it."                     |
| `passwordProtected`         | "This PDF is password protected. Please unlock it first."         |
| `insufficientDiskSpace`     | "Not enough storage space. Free up X MB to continue."             |
| `compressionFailed`         | "Unable to compress this PDF. Try a different compression level." |

### 7.3 Error Presentation

```swift
// In View
.alert(item: $viewModel.currentError) { error in
    Alert(
        title: Text(error.title),
        message: Text(error.message),
        primaryButton: error.retryAction.map { .default(Text("Retry"), action: $0) } ?? .cancel(),
        secondaryButton: .cancel()
    )
}
```

---

## 8. Security & Sandbox Considerations

### 8.1 Entitlements Required

```xml
<!-- Entitlements.plist -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

### 8.2 Security-Scoped Resource Protocol

#### ✅ DO

```swift
// Always wrap file access in security scope
func readPDF(at url: URL) async throws -> PDFDocument {
    try await url.withSecurityScopeAsync {
        guard let doc = PDFDocument(url: url) else {
            throw PDFEngineError.invalidPDF(url)
        }
        return doc
    }
}

// Store bookmarks for re-access
func persistFileReference(_ url: URL) throws -> Data {
    let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    return bookmarkData
}
```

#### ❌ DON'T

```swift
// NEVER access URL without security scope
let doc = PDFDocument(url: url) // WRONG - will fail in sandbox

// NEVER forget to stop accessing
url.startAccessingSecurityScopedResource()
let doc = PDFDocument(url: url)
// Missing stopAccessingSecurityScopedResource() - RESOURCE LEAK

// NEVER assume URL is perpetually accessible
// Bookmarks can become stale after app restart
```

### 8.3 URL+Security Implementation

```swift
extension URL {
    func withSecurityScope<T>(_ body: () throws -> T) rethrows -> T {
        let didStartAccessing = self.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    func withSecurityScopeAsync<T>(_ body: () async throws -> T) async rethrows -> T {
        let didStartAccessing = self.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try await body()
    }
}
```

### 8.4 Temporary File Handling

```swift
// Always write output to temporary directory first
let tempURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("pdf")

// Then let user choose final destination via save panel
```

---

## 9. Monetization Flow

### 9.1 Usage Flow Diagram

```
┌─────────────────┐
│ User Taps Action│
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ UsageManager            │
│ .canPerformAction()     │
└────────┬────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐  ┌───────────────────┐
│ true  │  │ false             │
└───┬───┘  └─────────┬─────────┘
    │                │
    ▼                ▼
┌──────────┐  ┌─────────────────┐
│ Execute  │  │ Show Paywall    │
│ Action   │  │                 │
└──────────┘  └─────────────────┘
                     │
                     ▼
              ┌─────────────────┐
              │ User Purchases? │
              └────────┬────────┘
                       │
                  ┌────┴────┐
                  │         │
                  ▼         ▼
            ┌───────┐  ┌───────┐
            │  Yes  │  │  No   │
            └───┬───┘  └───┬───┘
                │          │
                ▼          ▼
         ┌──────────┐  ┌───────┐
         │ Unlock   │  │ Cancel│
         │ Pro      │  └───────┘
         │ Execute  │
         └──────────┘
```

### 9.2 Free Tier Logic

```swift
actor UsageManager {
    private let freeActionLimit = 5
    private let keychainKey = KeychainHelper.Key.actionsRemaining

    func canPerformAction() async -> Bool {
        // Pro users always can
        if await RevenueCatManager.shared.isPro {
            return true
        }

        return (try? await remainingActions()) ?? 0 > 0
    }

    func recordAction() async throws {
        guard !await RevenueCatManager.shared.isPro else { return }

        var remaining = try await remainingActions()
        remaining = max(0, remaining - 1)

        let data = withUnsafeBytes(of: remaining) { Data($0) }
        try KeychainHelper.save(data, for: keychainKey)
    }

    func remainingActions() async throws -> Int {
        guard let data = try KeychainHelper.load(for: keychainKey) else {
            // First launch - initialize with free limit
            let data = withUnsafeBytes(of: freeActionLimit) { Data($0) }
            try KeychainHelper.save(data, for: keychainKey)
            return freeActionLimit
        }

        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }
}
```

### 9.3 Edge Cases

| Scenario                 | Handling                                      |
| ------------------------ | --------------------------------------------- |
| User reinstalls app      | Keychain persists; usage count maintained     |
| User restores purchase   | RevenueCat validates; bypass usage check      |
| Network unavailable      | Cache last known entitlement state            |
| Receipt validation fails | Allow action, queue validation for later      |
| Subscription expires     | RevenueCat notifies; revert to usage counting |

---

## 10. Platform-Specific Differences

### 10.1 File Picking

| Platform   | Implementation                                               |
| ---------- | ------------------------------------------------------------ |
| **macOS**  | `NSOpenPanel` via `fileImporter` modifier + Drag & Drop      |
| **iOS**    | `UIDocumentPickerViewController` via `fileImporter` modifier |
| **iPadOS** | Same as iOS + Drag & Drop on iPad                            |

### 10.2 File Saving

| Platform       | Implementation                                                          |
| -------------- | ----------------------------------------------------------------------- |
| **macOS**      | `NSSavePanel` via `fileMover` or custom `NSViewControllerRepresentable` |
| **iOS/iPadOS** | `UIActivityViewController` (Share Sheet) or Files app export            |

### 10.3 Drag & Drop

```swift
// FileDropZone.swift
struct FileDropZone: View {
    var body: some View {
        ZStack {
            // Common UI
        }
        #if os(macOS)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        #else
        .dropDestination(for: URL.self) { items, location in
            handleDrop(items)
        }
        #endif
    }
}
```

### 10.4 UI Differences

| Component    | macOS                 | iOS/iPadOS               |
| ------------ | --------------------- | ------------------------ |
| Navigation   | `NavigationSplitView` | `NavigationStack`        |
| Toolbar      | Window toolbar        | Navigation bar           |
| Context Menu | Right-click           | Long press               |
| File list    | Sidebar style         | List with inset grouping |
| Progress     | Sheet or inline       | Full-screen overlay      |

### 10.5 Platform Compilation

```swift
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
```

---

## 11. Testing Strategy

### 11.1 Unit Tests

| Component        | What to Test                                     | Location                                         |
| ---------------- | ------------------------------------------------ | ------------------------------------------------ |
| `PDFMerger`      | Merge 2 files, page order, bookmark preservation | `ZapPDFTests/Services/PDFMergerTests.swift`      |
| `PDFSplitter`    | Split modes, edge cases (1 page, 100+ pages)     | `ZapPDFTests/Services/PDFSplitterTests.swift`    |
| `PDFCompressor`  | Compression ratios, quality preservation         | `ZapPDFTests/Services/PDFCompressorTests.swift`  |
| `UsageManager`   | Count decrement, limit enforcement, persistence  | `ZapPDFTests/Services/UsageManagerTests.swift`   |
| `KeychainHelper` | Save/load/delete operations                      | `ZapPDFTests/Services/KeychainHelperTests.swift` |
| `URL+Security`   | Security scope wrapper behavior                  | `ZapPDFTests/Extensions/URLSecurityTests.swift`  |

### 11.2 Integration Tests

| Flow            | What to Test                                                  |
| --------------- | ------------------------------------------------------------- |
| Full merge flow | Files → ViewModel → Service → Result                          |
| Paywall trigger | Usage exhausted → Paywall shown → Purchase → Action completes |
| Cancellation    | Start operation → Cancel → State reset correctly              |

### 11.3 UI Tests

| Test                 | Steps                                                     |
| -------------------- | --------------------------------------------------------- |
| Add files via picker | Tap add → Select files → Verify thumbnails appear         |
| Merge PDFs           | Add 2 files → Tap Merge → Verify progress → Verify output |
| Paywall display      | Exhaust free actions → Verify paywall appears             |

### 11.4 Test Data

```
ZapPDFTests/
├── Resources/
│   ├── sample_1page.pdf
│   ├── sample_10pages.pdf
│   ├── sample_100pages.pdf
│   ├── sample_password_protected.pdf
│   └── sample_large_50mb.pdf
```

### 11.5 Mock Services

```swift
// For testing ViewModels without real PDF operations
protocol PDFMerging {
    func merge(files: [PDFFile], options: MergeOptions, progress: (Double) -> Void) async throws -> URL
}

class MockPDFMerger: PDFMerging {
    var shouldSucceed = true
    var simulatedDuration: TimeInterval = 0.1

    func merge(...) async throws -> URL {
        // Return mock result or throw mock error
    }
}
```

---

## 12. Performance & Memory

### 12.1 Large File Handling

```swift
// Stream pages instead of loading entire document
func mergeStreaming(files: [PDFFile]) async throws -> URL {
    let output = PDFDocument()

    for file in files {
        // Load one page at a time
        await file.url.withSecurityScopeAsync {
            guard let source = CGPDFDocument(file.url as CFURL) else { return }

            for pageNum in 1...source.numberOfPages {
                autoreleasepool {
                    if let page = source.page(at: pageNum) {
                        // Copy page to output
                    }
                }
            }
        }
    }

    return outputURL
}
```

### 12.2 Thumbnail Generation

```swift
actor PDFRenderer {
    private let cache = NSCache<NSURL, CGImage>()

    func thumbnail(for url: URL, size: CGSize) async -> CGImage? {
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // Generate on background thread
        let image = await Task.detached(priority: .utility) {
            // Use CGPDFPage for efficient rendering
        }.value

        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }

        return image
    }
}
```

### 12.3 Memory Limits

| Platform | Recommended Max File Size |
| -------- | ------------------------- |
| iPhone   | 100 MB per file           |
| iPad     | 200 MB per file           |
| macOS    | 500 MB per file           |

### 12.4 Optimization Guidelines

1. **Use `autoreleasepool`** for loops processing pages
2. **Prefer CGPDFDocument** over PDFDocument for read-only operations
3. **Generate thumbnails lazily** and cache aggressively
4. **Process pages sequentially** to avoid memory spikes
5. **Use background priority** for non-user-initiated work

---

## 13. Risks & Mitigation

### 13.1 Technical Risks

| Risk                                  | Likelihood | Impact | Mitigation                                                            |
| ------------------------------------- | ---------- | ------ | --------------------------------------------------------------------- |
| Security scope fails silently         | Medium     | High   | Always check return value of `startAccessingSecurityScopedResource()` |
| Memory crash on large PDFs            | Medium     | High   | Implement streaming, add file size limits                             |
| Quartz compression produces artifacts | Medium     | Medium | Provide compression level options, preview before save                |
| Keychain inaccessible                 | Low        | High   | Fallback to UserDefaults with warning                                 |
| RevenueCat SDK issues                 | Low        | Medium | Offline entitlement caching                                           |

### 13.2 App Review Risks

| Risk                                   | Mitigation                                      |
| -------------------------------------- | ----------------------------------------------- |
| Rejection for incomplete purchase flow | Test all purchase paths on TestFlight           |
| Rejection for missing restore button   | Add prominent "Restore Purchases" button        |
| Metadata rejection                     | Prepare accurate screenshots, clear description |

### 13.3 User Experience Risks

| Risk                         | Mitigation                                |
| ---------------------------- | ----------------------------------------- |
| Users confused by free limit | Clear onboarding explaining free tier     |
| Lost work on cancel          | Confirm before cancelling long operations |
| Can't access previous files  | Store bookmarks for recently used files   |

---

## Appendix A: Checklist for Code Review

Before merging any PR, verify:

- [ ] Security-scoped access properly wrapped
- [ ] No force unwraps on user-provided URLs
- [ ] Cancellation points in all loops
- [ ] Progress updates dispatched to MainActor
- [ ] Errors translated to user-friendly messages
- [ ] Memory profiled for large files
- [ ] Works on both macOS and iOS

---

## Appendix B: Quick Reference

### File to Responsibility Map

```
PDFFile.swift           → Data model
URL+Security.swift      → Sandbox access
PDFMerger.swift         → Merge logic
PDFSplitter.swift       → Split logic
PDFCompressor.swift     → Compression logic
DashboardViewModel.swift → File selection state
ProcessingViewModel.swift → Operation execution
UsageManager.swift      → Free tier tracking
RevenueCatManager.swift → Subscription status
```

### Key Method Signatures

```swift
// Core operations
PDFMerger.merge(files:options:progress:) async throws -> URL
PDFSplitter.split(file:mode:progress:) async throws -> [URL]
PDFCompressor.compress(file:level:progress:) async throws -> URL

// State management
UsageManager.canPerformAction() async -> Bool
UsageManager.recordAction() async throws
RevenueCatManager.isPro: Bool

// Security
URL.withSecurityScopeAsync(_:) async throws -> T
```

---

_End of Implementation Plan_
