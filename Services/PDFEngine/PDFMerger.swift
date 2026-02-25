//
//  PDFMerger.swift
//  ZapPDF
//
//  Actor that merges multiple PDF files into a single output file.
//

import Foundation
@preconcurrency import PDFKit

/// Actor responsible for merging multiple PDF files into one.
///
/// `PDFMerger` combines PDFs in the order they are provided, preserving all pages
/// and optionally bookmarks. It supports progress reporting and cancellation.
///
/// Example:
/// ```swift
/// let merger = PDFMerger()
/// let outputURL = try await merger.merge(
///     files: pdfFiles,
///     options: .init(outputFileName: "combined"),
///     progress: { _ in }
/// )
/// ```
actor PDFMerger {
    
    // MARK: - Types
    
    /// Options for configuring the merge operation.
    struct MergeOptions: Sendable {
        /// Base name for the output file (without extension)
        var outputFileName: String = "merged"
        
        /// Whether to preserve bookmarks from source documents
        var preserveBookmarks: Bool = true
        
        /// Whether to append a timestamp suffix for uniqueness
        var includeTimestamp: Bool = true

        /// Write profile used when serializing merged output.
        var writeProfile: MergeWriteProfile = .losslessPreserve

        /// Output is considered suspiciously large when output/input exceeds this ratio.
        var excessiveGrowthThreshold: Double = 2.0

        /// Output is considered suspiciously small when output/input is below this ratio.
        var unexpectedShrinkThreshold: Double = 0.10

        /// If true, retries oversized lossless output using a lossy screen-optimized profile.
        var enableLossyRetryOnGrowth: Bool = false
        
        /// Creates default merge options
        init(
            outputFileName: String = "merged",
            preserveBookmarks: Bool = true,
            includeTimestamp: Bool = true,
            writeProfile: MergeWriteProfile = .losslessPreserve,
            excessiveGrowthThreshold: Double = 2.0,
            unexpectedShrinkThreshold: Double = 0.10,
            enableLossyRetryOnGrowth: Bool = false
        ) {
            self.outputFileName = outputFileName
            self.preserveBookmarks = preserveBookmarks
            self.includeTimestamp = includeTimestamp
            self.writeProfile = writeProfile
            self.excessiveGrowthThreshold = excessiveGrowthThreshold
            self.unexpectedShrinkThreshold = unexpectedShrinkThreshold
            self.enableLossyRetryOnGrowth = enableLossyRetryOnGrowth
        }
    }

    private struct PreflightSource {
        let file: PDFFile
        let pageCount: Int
        let fileSize: Int64
    }

    private struct SourcePageKey: Hashable {
        let documentID: ObjectIdentifier
        let pageIndex: Int
    }

    private struct PendingLinkRemap {
        let outputPageIndex: Int
        let annotationIndex: Int
        let destinationSourcePageIndex: Int
        let destinationPoint: CGPoint
        let destinationZoom: CGFloat
    }

    private enum OutlineMergeInternalError: Error {
        case unmappedDestination
    }
    
    // MARK: - Private Properties
    
    private var isCancelled = false
    private let progressDispatchInterval: TimeInterval = 0.1
    private let progressDispatchPageStride: Int = 25
    private var lastProgressDispatchAt: Date = .distantPast
    private var pagesSinceProgressDispatch: Int = 0
    
    // MARK: - Public Methods
    
    /// Merge multiple PDF files into a single output file.
    ///
    /// - Parameters:
    ///   - files: Array of `PDFFile` objects to merge (in order)
    ///   - options: Configuration options for the merge
    ///   - progress: Callback reporting progress from 0.0 to 1.0
    /// - Returns: URL to the merged PDF file in the temporary directory
    /// - Throws: `PDFEngineError` if merge fails
    func merge(
        files: [PDFFile],
        options: MergeOptions = MergeOptions(),
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let result = try await mergeDetailed(files: files, options: options, progress: progress)
        return result.outputURL
    }

    /// Merge multiple files and return output diagnostics.
    func mergeDetailed(
        files: [PDFFile],
        options: MergeOptions = MergeOptions(),
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> PDFMergeResult {
        isCancelled = false
        resetProgressThrottling()

        guard !files.isEmpty else {
            throw PDFEngineError.emptyInput
        }

        let preflightSources = try await preflight(files: files)
        let totalPages = preflightSources.reduce(0) { $0 + $1.pageCount }
        let inputBytes = preflightSources.reduce(Int64(0)) { $0 + $1.fileSize }

        let outputDocument = PDFDocument()
        var processedPages = 0

        var sourcePageMap: [SourcePageKey: Int] = [:]
        let mergedOutlineRoot = options.preserveBookmarks ? PDFOutline() : nil

        for source in preflightSources {
            try checkCancellation()

            try await source.file.withResolvedAccessAsync { resolvedURL in
                guard let sourceDocument = PDFDocument(url: resolvedURL) else {
                    throw PDFEngineError.invalidPDF(resolvedURL)
                }

                if sourceDocument.isLocked {
                    throw PDFEngineError.passwordProtected(source.file.url)
                }

                let sourceDocumentID = ObjectIdentifier(sourceDocument)
                var localPageMap: [Int: Int] = [:]
                var pendingLinkRemaps: [PendingLinkRemap] = []

                for pageIndex in 0..<sourceDocument.pageCount {
                    try self.checkCancellation()

                    guard let sourcePage = sourceDocument.page(at: pageIndex) else {
                        throw PDFEngineError.pageLoadFailed(resolvedURL, pageIndex: pageIndex)
                    }

                    let copiedPage = try Self.copyPageForMerge(
                        from: sourceDocument,
                        at: pageIndex,
                        sourceURL: resolvedURL
                    )

                    let outputPageIndex = outputDocument.pageCount
                    outputDocument.insert(copiedPage, at: outputPageIndex)

                    localPageMap[pageIndex] = outputPageIndex
                    sourcePageMap[SourcePageKey(documentID: sourceDocumentID, pageIndex: pageIndex)] = outputPageIndex
                    pendingLinkRemaps.append(
                        contentsOf: Self.pendingLinkRemaps(
                            from: sourcePage,
                            sourceDocument: sourceDocument,
                            sourceDocumentID: sourceDocumentID,
                            outputPageIndex: outputPageIndex
                        )
                    )

                    processedPages += 1
                    await self.reportProcessingProgress(
                        processedPages: processedPages,
                        totalPages: totalPages,
                        progress: progress
                    )
                }

                if let mergedOutlineRoot {
                    do {
                        try Self.mergeOutlineTree(
                            from: sourceDocument,
                            outputDocument: outputDocument,
                            outputRoot: mergedOutlineRoot,
                            pageMap: localPageMap
                        )
                    } catch {
                        throw PDFEngineError.outlineMergeFailed(resolvedURL)
                    }
                }

                Self.applyPendingLinkRemaps(
                    pendingLinkRemaps,
                    outputDocument: outputDocument,
                    localPageMap: localPageMap
                )
            }
        }

        try checkCancellation()

        if let mergedOutlineRoot, mergedOutlineRoot.numberOfChildren > 0 {
            outputDocument.outlineRoot = mergedOutlineRoot
        }

        Self.normalizeLinkActions(in: outputDocument, sourcePageMap: sourcePageMap)

        await MainActor.run {
            progress(PDFProgressPolicy.finalizingStart)
        }

        try checkCancellation()

        let outputURL = outputURL(for: options)
        try removeFileIfExists(at: outputURL)

        let initialWriteOptions = Self.writeOptions(for: options.writeProfile)
        guard outputDocument.write(to: outputURL, withOptions: initialWriteOptions) else {
            throw PDFEngineError.writeFailed(outputURL)
        }

        var finalProfile = options.writeProfile
        var outputBytes = Self.fileSize(at: outputURL)

        var diagnostics = Self.makeDiagnostics(
            inputBytes: inputBytes,
            outputBytes: outputBytes,
            pageCount: outputDocument.pageCount,
            writeProfile: finalProfile,
            excessiveGrowthThreshold: options.excessiveGrowthThreshold,
            unexpectedShrinkThreshold: options.unexpectedShrinkThreshold
        )

        if options.enableLossyRetryOnGrowth,
           options.writeProfile == .losslessPreserve,
           diagnostics.anomaly == .excessiveGrowth {
            let retryURL = retryOutputURL(from: outputURL)
            try removeFileIfExists(at: retryURL)

            let retryOptions = Self.writeOptions(for: .screenOptimizedLossy)
            guard outputDocument.write(to: retryURL, withOptions: retryOptions) else {
                throw PDFEngineError.writeFailed(retryURL)
            }

            let retryBytes = Self.fileSize(at: retryURL)
            if Self.shouldUseRetryOutput(originalBytes: outputBytes, retryBytes: retryBytes) {
                try removeFileIfExists(at: outputURL)
                try FileManager.default.moveItem(at: retryURL, to: outputURL)
                outputBytes = retryBytes
                finalProfile = .screenOptimizedLossy
            } else {
                try? FileManager.default.removeItem(at: retryURL)
            }

            diagnostics = Self.makeDiagnostics(
                inputBytes: inputBytes,
                outputBytes: outputBytes,
                pageCount: outputDocument.pageCount,
                writeProfile: finalProfile,
                excessiveGrowthThreshold: options.excessiveGrowthThreshold,
                unexpectedShrinkThreshold: options.unexpectedShrinkThreshold
            )
        }

        await MainActor.run {
            progress(1.0)
        }

        return PDFMergeResult(outputURL: outputURL, diagnostics: diagnostics)
    }
    
    /// Cancel the current merge operation.
    ///
    /// The operation will throw `PDFEngineError.cancelled` at the next checkpoint.
    func cancel() {
        isCancelled = true
    }
    
    // MARK: - Private Methods
    
    private func checkCancellation() throws {
        if isCancelled {
            throw PDFEngineError.cancelled
        }
        try Task.checkCancellation()
    }

    private func preflight(files: [PDFFile]) async throws -> [PreflightSource] {
        var sources: [PreflightSource] = []
        sources.reserveCapacity(files.count)

        for file in files {
            try checkCancellation()

            let source = try await file.withResolvedAccessAsync { resolvedURL in
                guard let sourceDocument = PDFDocument(url: resolvedURL) else {
                    throw PDFEngineError.invalidPDF(resolvedURL)
                }
                if sourceDocument.isLocked {
                    throw PDFEngineError.passwordProtected(file.url)
                }

                let fileSize = Self.fileSize(at: resolvedURL)
                return PreflightSource(
                    file: file,
                    pageCount: sourceDocument.pageCount,
                    fileSize: fileSize
                )
            }

            sources.append(source)
        }

        return sources
    }

    private nonisolated static func mergeOutlineTree(
        from sourceDocument: PDFDocument,
        outputDocument: PDFDocument,
        outputRoot: PDFOutline,
        pageMap: [Int: Int]
    ) throws {
        guard let sourceRoot = sourceDocument.outlineRoot else { return }
        try appendOutlineChildren(
            from: sourceRoot,
            to: outputRoot,
            sourceDocument: sourceDocument,
            outputDocument: outputDocument,
            pageMap: pageMap
        )
    }

    private nonisolated static func appendOutlineChildren(
        from sourceParent: PDFOutline,
        to targetParent: PDFOutline,
        sourceDocument: PDFDocument,
        outputDocument: PDFDocument,
        pageMap: [Int: Int]
    ) throws {
        for childIndex in 0..<sourceParent.numberOfChildren {
            guard let sourceChild = sourceParent.child(at: childIndex) else { continue }

            let targetChild = PDFOutline()
            targetChild.label = sourceChild.label
            targetChild.isOpen = sourceChild.isOpen

            if let sourceAction = sourceChild.action {
                if let remappedAction = try remappedAction(
                    from: sourceAction,
                    sourceDocument: sourceDocument,
                    outputDocument: outputDocument,
                    pageMap: pageMap
                ) {
                    targetChild.action = remappedAction
                }
            } else if let sourceDestination = sourceChild.destination {
                guard let destination = try remappedDestination(
                    from: sourceDestination,
                    sourceDocument: sourceDocument,
                    outputDocument: outputDocument,
                    pageMap: pageMap
                ) else {
                    throw OutlineMergeInternalError.unmappedDestination
                }
                targetChild.destination = destination
            }

            targetParent.insertChild(targetChild, at: targetParent.numberOfChildren)
            try appendOutlineChildren(
                from: sourceChild,
                to: targetChild,
                sourceDocument: sourceDocument,
                outputDocument: outputDocument,
                pageMap: pageMap
            )
        }
    }

    private nonisolated static func remappedAction(
        from action: PDFAction,
        sourceDocument: PDFDocument,
        outputDocument: PDFDocument,
        pageMap: [Int: Int]
    ) throws -> PDFAction? {
        if let goToAction = action as? PDFActionGoTo {
            guard let destination = try remappedDestination(
                from: goToAction.destination,
                sourceDocument: sourceDocument,
                outputDocument: outputDocument,
                pageMap: pageMap
            ) else {
                throw OutlineMergeInternalError.unmappedDestination
            }
            return PDFActionGoTo(destination: destination)
        }

        return action.copy() as? PDFAction
    }

    private nonisolated static func remappedDestination(
        from destination: PDFDestination,
        sourceDocument: PDFDocument,
        outputDocument: PDFDocument,
        pageMap: [Int: Int]
    ) throws -> PDFDestination? {
        guard let sourcePage = destination.page else {
            return nil
        }

        let sourcePageIndex = sourceDocument.index(for: sourcePage)
        guard sourcePageIndex != NSNotFound,
              let outputPageIndex = pageMap[sourcePageIndex],
              let outputPage = outputDocument.page(at: outputPageIndex) else {
            return nil
        }

        let remappedDestination = PDFDestination(page: outputPage, at: destination.point)
        remappedDestination.zoom = destination.zoom
        return remappedDestination
    }

    private nonisolated static func normalizeLinkActions(
        in outputDocument: PDFDocument,
        sourcePageMap: [SourcePageKey: Int]
    ) {
        for outputPageIndex in 0..<outputDocument.pageCount {
            guard let outputPage = outputDocument.page(at: outputPageIndex) else { continue }

            for annotation in outputPage.annotations {
                if let goToAction = annotation.action as? PDFActionGoTo {
                    let sourceDestination = goToAction.destination
                    guard let sourcePage = sourceDestination.page,
                          let sourceDocument = sourcePage.document else {
                        continue
                    }

                    let sourcePageIndex = sourceDocument.index(for: sourcePage)
                    guard sourcePageIndex != NSNotFound else { continue }
                    let key = SourcePageKey(
                        documentID: ObjectIdentifier(sourceDocument),
                        pageIndex: sourcePageIndex
                    )

                    guard let mappedPageIndex = sourcePageMap[key],
                          let mappedPage = outputDocument.page(at: mappedPageIndex) else {
                        continue
                    }

                    let mappedDestination = PDFDestination(page: mappedPage, at: sourceDestination.point)
                    mappedDestination.zoom = sourceDestination.zoom
                    annotation.action = PDFActionGoTo(destination: mappedDestination)
                } else if let sourceDestination = annotation.destination,
                          let sourcePage = sourceDestination.page,
                          let sourceDocument = sourcePage.document {
                    let sourcePageIndex = sourceDocument.index(for: sourcePage)
                    guard sourcePageIndex != NSNotFound else { continue }
                    let key = SourcePageKey(
                        documentID: ObjectIdentifier(sourceDocument),
                        pageIndex: sourcePageIndex
                    )

                    guard let mappedPageIndex = sourcePageMap[key],
                          let mappedPage = outputDocument.page(at: mappedPageIndex) else {
                        continue
                    }

                    let mappedDestination = PDFDestination(page: mappedPage, at: sourceDestination.point)
                    mappedDestination.zoom = sourceDestination.zoom
                    annotation.destination = mappedDestination
                }
            }
        }
    }

    private nonisolated static func pendingLinkRemaps(
        from sourcePage: PDFPage,
        sourceDocument: PDFDocument,
        sourceDocumentID: ObjectIdentifier,
        outputPageIndex: Int
    ) -> [PendingLinkRemap] {
        var remaps: [PendingLinkRemap] = []

        for (annotationIndex, annotation) in sourcePage.annotations.enumerated() {
            if let goToAction = annotation.action as? PDFActionGoTo {
                let sourceDestination = goToAction.destination
                guard let destinationPage = sourceDestination.page,
                      let destinationDocument = destinationPage.document,
                      ObjectIdentifier(destinationDocument) == sourceDocumentID else {
                    continue
                }

                let destinationPageIndex = sourceDocument.index(for: destinationPage)
                guard destinationPageIndex != NSNotFound else { continue }

                remaps.append(
                    PendingLinkRemap(
                        outputPageIndex: outputPageIndex,
                        annotationIndex: annotationIndex,
                        destinationSourcePageIndex: destinationPageIndex,
                        destinationPoint: sourceDestination.point,
                        destinationZoom: sourceDestination.zoom
                    )
                )
            } else if let sourceDestination = annotation.destination,
                      let destinationPage = sourceDestination.page,
                      let destinationDocument = destinationPage.document,
                      ObjectIdentifier(destinationDocument) == sourceDocumentID {
                let destinationPageIndex = sourceDocument.index(for: destinationPage)
                guard destinationPageIndex != NSNotFound else { continue }

                remaps.append(
                    PendingLinkRemap(
                        outputPageIndex: outputPageIndex,
                        annotationIndex: annotationIndex,
                        destinationSourcePageIndex: destinationPageIndex,
                        destinationPoint: sourceDestination.point,
                        destinationZoom: sourceDestination.zoom
                    )
                )
            }
        }

        return remaps
    }

    private nonisolated static func applyPendingLinkRemaps(
        _ pendingLinkRemaps: [PendingLinkRemap],
        outputDocument: PDFDocument,
        localPageMap: [Int: Int]
    ) {
        guard !pendingLinkRemaps.isEmpty else { return }

        for remap in pendingLinkRemaps {
            guard let outputPage = outputDocument.page(at: remap.outputPageIndex),
                  remap.annotationIndex < outputPage.annotations.count,
                  let destinationOutputPageIndex = localPageMap[remap.destinationSourcePageIndex],
                  let destinationPage = outputDocument.page(at: destinationOutputPageIndex) else {
                continue
            }

            let mappedDestination = PDFDestination(page: destinationPage, at: remap.destinationPoint)
            mappedDestination.zoom = remap.destinationZoom

            let annotation = outputPage.annotations[remap.annotationIndex]
            if annotation.action is PDFActionGoTo {
                annotation.action = PDFActionGoTo(destination: mappedDestination)
            } else {
                annotation.destination = mappedDestination
            }
        }
    }

    private func outputURL(for options: MergeOptions) -> URL {
        var finalOutputName = options.outputFileName
        if options.includeTimestamp {
            finalOutputName += "_\(Date.filenameTimestamp())"
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(finalOutputName)
            .appendingPathExtension("pdf")
    }

    private func retryOutputURL(from outputURL: URL) -> URL {
        outputURL.deletingLastPathComponent()
            .appendingPathComponent(outputURL.deletingPathExtension().lastPathComponent + "_screenoptimized")
            .appendingPathExtension("pdf")
    }

    private func removeFileIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func resetProgressThrottling() {
        lastProgressDispatchAt = .distantPast
        pagesSinceProgressDispatch = 0
    }

    private func reportProcessingProgress(
        processedPages: Int,
        totalPages: Int,
        progress: @escaping @Sendable (Double) -> Void
    ) async {
        guard totalPages > 0 else { return }

        pagesSinceProgressDispatch += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastProgressDispatchAt)
        let shouldDispatch =
            processedPages == totalPages ||
            pagesSinceProgressDispatch >= progressDispatchPageStride ||
            elapsed >= progressDispatchInterval

        guard shouldDispatch else { return }

        pagesSinceProgressDispatch = 0
        lastProgressDispatchAt = now
        let rawProgress = Double(processedPages) / Double(totalPages)

        await MainActor.run {
            let currentProgress = PDFProgressPolicy.processingProgress(from: rawProgress)
            progress(currentProgress)
        }
    }

    // MARK: - Internal helpers (tests)

    nonisolated static func copyPageForMerge(
        from sourceDocument: PDFDocument,
        at pageIndex: Int,
        sourceURL: URL
    ) throws -> PDFPage {
        guard let page = sourceDocument.page(at: pageIndex),
              let copiedPage = page.copy() as? PDFPage else {
            throw PDFEngineError.pageLoadFailed(sourceURL, pageIndex: pageIndex)
        }
        return copiedPage
    }

    nonisolated static func writeOptions(for profile: MergeWriteProfile) -> [PDFDocumentWriteOption: Any] {
        switch profile {
        case .losslessPreserve:
            return [
                PDFDocumentWriteOption.burnInAnnotationsOption: false,
                PDFDocumentWriteOption.saveTextFromOCROption: false,
                PDFDocumentWriteOption.saveImagesAsJPEGOption: false,
                PDFDocumentWriteOption.optimizeImagesForScreenOption: false
            ]
        case .screenOptimizedLossy:
            return [
                PDFDocumentWriteOption.burnInAnnotationsOption: false,
                PDFDocumentWriteOption.saveTextFromOCROption: false,
                PDFDocumentWriteOption.saveImagesAsJPEGOption: true,
                PDFDocumentWriteOption.optimizeImagesForScreenOption: true
            ]
        }
    }

    nonisolated static func shouldUseRetryOutput(
        originalBytes: Int64,
        retryBytes: Int64,
        minimumImprovement: Double = 0.15
    ) -> Bool {
        guard originalBytes > 0, retryBytes > 0, retryBytes < originalBytes else {
            return false
        }

        let improvement = Double(originalBytes - retryBytes) / Double(originalBytes)
        return improvement >= minimumImprovement
    }

    nonisolated static func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    nonisolated static func makeDiagnostics(
        inputBytes: Int64,
        outputBytes: Int64,
        pageCount: Int,
        writeProfile: MergeWriteProfile,
        excessiveGrowthThreshold: Double,
        unexpectedShrinkThreshold: Double
    ) -> MergeDiagnostics {
        let growthFactor: Double
        if inputBytes > 0 {
            growthFactor = Double(outputBytes) / Double(inputBytes)
        } else {
            growthFactor = 1.0
        }

        let anomaly: MergeAnomaly
        if growthFactor > excessiveGrowthThreshold {
            anomaly = .excessiveGrowth
        } else if growthFactor < unexpectedShrinkThreshold {
            anomaly = .unexpectedShrink
        } else {
            anomaly = .none
        }

        return MergeDiagnostics(
            inputBytes: inputBytes,
            outputBytes: outputBytes,
            growthFactor: growthFactor,
            pageCount: pageCount,
            writeProfile: writeProfile,
            anomaly: anomaly
        )
    }
}
