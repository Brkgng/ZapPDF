//
//  OutputFileSaver.swift
//  ZapPDF
//
//  Helper for persisting one or more output PDFs with collision-safe naming.
//

import Foundation

enum OutputFileSaverError: Error, LocalizedError, Sendable {
    case emptyInput
    case invalidDestination(URL)
    case sourceFileMissing(URL)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No output files to save."
        case .invalidDestination(let url):
            return "Invalid destination folder: \(url.path)"
        case .sourceFileMissing(let url):
            return "Source file is missing: \(url.lastPathComponent)"
        }
    }
}

/// Saves output files to a chosen destination directory.
struct OutputFileSaver {
    enum ConflictPolicy: Sendable {
        case autoRename
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Save all source files into destination directory.
    ///
    /// Uses copy semantics and rolls back copied files if any step fails.
    func saveAll(
        _ sourceURLs: [URL],
        to directory: URL,
        conflictPolicy: ConflictPolicy = .autoRename
    ) throws -> [URL] {
        guard !sourceURLs.isEmpty else {
            throw OutputFileSaverError.emptyInput
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw OutputFileSaverError.invalidDestination(directory)
        }

        var savedURLs: [URL] = []
        do {
            for sourceURL in sourceURLs {
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    throw OutputFileSaverError.sourceFileMissing(sourceURL)
                }

                let destinationURL: URL
                switch conflictPolicy {
                case .autoRename:
                    destinationURL = uniqueDestinationURL(
                        for: sourceURL.lastPathComponent,
                        in: directory
                    )
                }

                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                savedURLs.append(destinationURL)
            }

            return savedURLs
        } catch {
            for url in savedURLs.reversed() {
                try? fileManager.removeItem(at: url)
            }
            throw error
        }
    }

    /// Returns a destination URL that does not collide with existing files.
    ///
    /// Example: `output.pdf`, `output_2.pdf`, `output_3.pdf`.
    func uniqueDestinationURL(for fileName: String, in directory: URL) -> URL {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        let baseURL = URL(fileURLWithPath: safeName)
        let stem = baseURL.deletingPathExtension().lastPathComponent
        let pathExtension = baseURL.pathExtension

        var candidate = directory.appendingPathComponent(safeName)
        var suffixIndex = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let candidateName: String
            if pathExtension.isEmpty {
                candidateName = "\(stem)_\(suffixIndex)"
            } else {
                candidateName = "\(stem)_\(suffixIndex).\(pathExtension)"
            }
            candidate = directory.appendingPathComponent(candidateName)
            suffixIndex += 1
        }

        return candidate
    }
}
