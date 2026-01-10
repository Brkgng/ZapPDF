# ZapPDF Implementation Plan

> **Living Document** – Last updated: 2026-01-09

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                            │
│  DashboardView │ ProcessingView │ PaywallView │ PageReorderView │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ViewModels                               │
│  DashboardViewModel │ ProcessingViewModel │ PageReorderViewModel│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Services                                │
│  PDFMerger │ PDFSplitter │ PDFReorderer │ UsageManager          │
│  (Future: PDFCompressor │ RevenueCatManager)                    │
└─────────────────────────────────────────────────────────────────┘
```

### Core Principles

| Principle                | Implementation                                                |
| ------------------------ | ------------------------------------------------------------- |
| **MVVM**                 | Views observe ViewModels; ViewModels call Services            |
| **Async-First**          | All PDF operations use `async/await` with `Task` cancellation |
| **Sandbox Compliance**   | Security-scoped URL access via `URL.withSecurityScope {}`     |
| **Platform Abstraction** | Shared logic; platform-specific UI via `#if os()`             |

### Key Dependencies

- **PDFKit** – Core PDF manipulation
- **CoreGraphics/Quartz** – Thumbnails, future compression
- **Security.framework** – Keychain for usage tracking
- **RevenueCat SDK** – Subscription management (planned)

---

## 2. Phase Roadmap

### ✅ Completed Phases

| Phase | Description                                            |
| ----- | ------------------------------------------------------ |
| 0     | Project Setup (Xcode, entitlements, build settings)    |
| 1     | Core Models (PDFFile, UserAction, URL+Security)        |
| 2     | PDF Engine (Merger, Splitter, Renderer)                |
| 3     | Persistence (KeychainHelper, UsageManager)             |
| 4     | ViewModels (Dashboard, Processing, Paywall)            |
| 5     | UI Components (FileDropZone, Thumbnails, ActionButton) |
| 6     | Screens (Dashboard, Processing, Paywall, Onboarding)   |
| 7     | Monetization Integration (RevenueCat)                  |
| 10    | Page Reordering Feature                                |
| 11    | Internationalization & Localization                    |
| 12    | In-App Language Switching                              |
| 13    | Tier 1 Language Translations (DE, FR, ES, JA, ZH, TR)  |

### 🚧 Pending Phases

#### Phase 8: Testing & Polish

**Status:** Not Started

- [ ] Unit tests for Services (Merger, Splitter, Reorderer)
- [ ] Integration tests for ViewModels
- [ ] UI tests for critical flows
- [ ] Performance profiling for large PDFs

#### Phase 9: App Store Preparation

**Status:** Not Started

- [ ] App Store screenshots
- [ ] Privacy policy
- [ ] App Review notes
- [ ] TestFlight beta distribution

---

## 3. Future Roadmap

### PDF Compression (Future Release)

> [!NOTE]
> Compression was removed from v1.0 scope but is planned for a future release.

**Proposed Implementation:**

```swift
actor PDFCompressor {
    enum CompressionLevel {
        case low      // ~80% of original
        case medium   // ~50% of original
        case high     // ~30% of original
        case maximum  // ~15% of original (quality loss)
    }

    func compress(file: PDFFile, level: CompressionLevel, progress: @escaping (Double) -> Void) async throws -> URL
    func estimatedOutputSize(for file: PDFFile, level: CompressionLevel) -> Int64
    func cancel()
}
```

**Compression Flow:**

1. User selects PDF(s) → Tap "Compress"
2. CompressionOptionsSheet shows estimated output sizes
3. Apply Quartz filters (CIFilter for image downsampling, CGContext for re-rendering)
4. Show before/after size comparison

---

## 4. Layer Responsibilities

| Layer        | Folder                  | Responsibility                                |
| ------------ | ----------------------- | --------------------------------------------- |
| App          | `App/`                  | Entry point, environment injection, assets    |
| Models       | `Models/`               | PDFFile, UserAction, PageItem, AppLanguage    |
| ViewModels   | `ViewModels/`           | State management, business logic coordination |
| Services     | `Services/PDFEngine/`   | PDF operations (Merger, Splitter, Reorderer)  |
| Persistence  | `Services/Persistence/` | KeychainHelper, UsageManager                  |
| UI           | `UI/Components/`        | Reusable UI building blocks                   |
| Screens      | `UI/Screens/`           | Full-screen views                             |
| Localization | `Common/Localization/`  | L10n namespace, LanguageManager               |
| Extensions   | `Common/Extensions/`    | URL+Security, View modifiers                  |
| Monetization | `Monetization/`         | RevenueCat integration (planned)              |

---

## 5. Key APIs

### PDF Engine

| Service        | Key Method                                             | Purpose               |
| -------------- | ------------------------------------------------------ | --------------------- |
| `PDFMerger`    | `merge(files:options:progress:) async throws -> URL`   | Combine multiple PDFs |
| `PDFSplitter`  | `split(file:mode:progress:) async throws -> [URL]`     | Extract page ranges   |
| `PDFReorderer` | `reorder(file:newOrder:progress:) async throws -> URL` | Reorder pages         |

### State Management

| ViewModel              | Key Properties                               | Purpose                     |
| ---------------------- | -------------------------------------------- | --------------------------- |
| `DashboardViewModel`   | `selectedFiles`, `isLoading`, `errorMessage` | File selection state        |
| `ProcessingViewModel`  | `state` (idle/processing/completed/failed)   | Operation execution         |
| `PageReorderViewModel` | `pages`, `canUndo`, `canRedo`, `hasChanges`  | Page reorder with undo/redo |

### Usage & Monetization

| Service        | Key Method                         | Purpose                     |
| -------------- | ---------------------------------- | --------------------------- |
| `UsageManager` | `canPerformAction() async -> Bool` | Check free tier limit       |
| `UsageManager` | `recordAction() async throws`      | Decrement remaining actions |

---

## 6. Monetization Flow (Planned)

```
User Taps Action
       │
       ▼
UsageManager.canPerformAction()
       │
   ┌───┴───┐
   │       │
   ▼       ▼
 true    false
   │       │
   ▼       ▼
Execute  Show Paywall → Purchase? → Unlock Pro
Action              │
                    └─No→ Cancel
```

### Free Tier Logic

- **Limit:** 5 free actions stored in Keychain
- **Pro users:** Bypass usage check via RevenueCat entitlement
- **Persistence:** Keychain survives app reinstall

### Edge Cases to Handle

| Scenario             | Handling                                  |
| -------------------- | ----------------------------------------- |
| App reinstall        | Keychain persists; usage count maintained |
| Restore purchase     | RevenueCat validates; bypass usage check  |
| Network unavailable  | Cache last known entitlement state        |
| Subscription expires | Revert to usage counting                  |

---

## 7. Platform Differences

| Feature      | macOS                       | iOS/iPadOS                       |
| ------------ | --------------------------- | -------------------------------- |
| File Picking | `NSOpenPanel` + Drag & Drop | `UIDocumentPickerViewController` |
| File Saving  | `NSSavePanel`               | Share Sheet / Files app          |
| Navigation   | `NavigationSplitView`       | `NavigationStack`                |
| Toolbar      | Window toolbar              | Navigation bar                   |
| Context Menu | Right-click                 | Long press                       |

---

## 8. Localization Status

### Infrastructure ✅

- `Localizable.xcstrings` – String Catalog
- `LocalizedStrings.swift` – Type-safe `L10n` namespace (237 keys)
- `LanguageManager.swift` – In-app language switching

### Tier 1 Languages ✅

| Language                | Status | Strings |
| ----------------------- | ------ | ------- |
| 🇺🇸 English (base)       | ✅     | 237/237 |
| 🇩🇪 German               | ✅     | 237/237 |
| 🇫🇷 French               | ✅     | 237/237 |
| 🇪🇸 Spanish              | ✅     | 237/237 |
| 🇯🇵 Japanese             | ✅     | 237/237 |
| 🇨🇳 Chinese (Simplified) | ✅     | 237/237 |
| 🇹🇷 Turkish              | ✅     | 237/237 |

---

## 9. Testing Strategy

### Unit Tests

| Component    | What to Test                       | Location                |
| ------------ | ---------------------------------- | ----------------------- |
| PDFMerger    | Merge order, bookmark preservation | `ZapPDFTests/Services/` |
| PDFSplitter  | Split modes, edge cases            | `ZapPDFTests/Services/` |
| PDFReorderer | Validation, cancellation           | `ZapPDFTests/Services/` |
| UsageManager | Limit enforcement, persistence     | `ZapPDFTests/Services/` |
| PageItem     | `hasChanges`, `reorderedIndices`   | `ZapPDFTests/Models/`   |

### Test Data

```
ZapPDFTests/Resources/
├── sample_1page.pdf
├── sample_10pages.pdf
├── sample_100pages.pdf
├── sample_password_protected.pdf
└── sample_large_50mb.pdf
```

---

## 10. Risks & Mitigation

| Risk                          | Likelihood | Mitigation                                                   |
| ----------------------------- | ---------- | ------------------------------------------------------------ |
| Security scope fails silently | Medium     | Always check `startAccessingSecurityScopedResource()` return |
| Memory crash on large PDFs    | Medium     | Implement streaming, add file size limits                    |
| Keychain inaccessible         | Low        | Fallback to UserDefaults with warning                        |
| RevenueCat SDK issues         | Low        | Offline entitlement caching                                  |

### App Review Risks

| Risk                     | Mitigation                               |
| ------------------------ | ---------------------------------------- |
| Missing restore button   | Add prominent "Restore Purchases" button |
| Incomplete purchase flow | Test all paths on TestFlight             |

---

## Appendix: Security-Scoped Resource Pattern

> [!IMPORTANT]
> All file access must use security-scoped wrappers.

```swift
// ✅ Correct
try await url.withSecurityScopeAsync {
    guard let doc = PDFDocument(url: url) else { throw PDFEngineError.invalidPDF(url) }
    return doc
}

// ❌ Wrong - will fail in sandbox
let doc = PDFDocument(url: url)
```

---

_End of Implementation Plan_
