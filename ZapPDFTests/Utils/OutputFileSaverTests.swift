//
//  OutputFileSaverTests.swift
//  ZapPDFTests
//
//  Unit tests for OutputFileSaver.
//

import Testing
import Foundation
@testable import ZapPDF

@Suite("OutputFileSaver Tests")
struct OutputFileSaverTests {

    @Test("Saves all files to selected destination directory")
    func savesAllFilesToDestinationDirectory() throws {
        let saver = OutputFileSaver()
        let sourceURLs = try PDFTestHelpers.createTestPDFs(counts: [1, 2])
        let destinationDirectory = try makeTempDirectory()

        defer {
            PDFTestHelpers.cleanup(urls: sourceURLs)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let savedURLs = try saver.saveAll(sourceURLs, to: destinationDirectory)

        #expect(savedURLs.count == sourceURLs.count)
        #expect(Set(savedURLs).count == sourceURLs.count)

        for savedURL in savedURLs {
            #expect(FileManager.default.fileExists(atPath: savedURL.path))
        }

        // Source files should still exist because save-all uses copy semantics.
        for sourceURL in sourceURLs {
            #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        }
    }

    @Test("Auto-renames destination files when name conflicts exist")
    func autoRenamesConflictingFiles() throws {
        let saver = OutputFileSaver()
        let sourceURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "output_saver_conflict")
        let destinationDirectory = try makeTempDirectory()

        defer {
            PDFTestHelpers.cleanup(url: sourceURL)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let existingDestinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: existingDestinationURL)

        let savedURLs = try saver.saveAll([sourceURL], to: destinationDirectory)
        let savedURL = try #require(savedURLs.first)
        let expectedName = expectedAutoRenamedFileName(for: sourceURL.lastPathComponent, suffix: 2)

        #expect(savedURL.lastPathComponent == expectedName)
        #expect(FileManager.default.fileExists(atPath: existingDestinationURL.path))
        #expect(FileManager.default.fileExists(atPath: savedURL.path))
    }

    @Test("Rolls back copied files if a later save fails")
    func rollsBackCopiedFilesWhenLaterSaveFails() throws {
        let saver = OutputFileSaver()
        let sourceURL = try PDFTestHelpers.createTestPDF(pageCount: 1, identifier: "output_saver_rollback")
        let missingSourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing_source_\(UUID().uuidString).pdf")
        let destinationDirectory = try makeTempDirectory()

        defer {
            PDFTestHelpers.cleanup(url: sourceURL)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        #expect(throws: OutputFileSaverError.self) {
            try saver.saveAll([sourceURL, missingSourceURL], to: destinationDirectory)
        }

        let destinationContents = try FileManager.default.contentsOfDirectory(
            at: destinationDirectory,
            includingPropertiesForKeys: nil
        )
        #expect(destinationContents.isEmpty)
    }

    @Test("Throws empty input error when no source files provided")
    func throwsForEmptyInput() throws {
        let saver = OutputFileSaver()
        let destinationDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: destinationDirectory) }

        #expect(throws: OutputFileSaverError.self) {
            try saver.saveAll([], to: destinationDirectory)
        }
    }

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("output_saver_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func expectedAutoRenamedFileName(for fileName: String, suffix: Int) -> String {
        let fileURL = URL(fileURLWithPath: fileName)
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension

        if fileExtension.isEmpty {
            return "\(stem)_\(suffix)"
        }

        return "\(stem)_\(suffix).\(fileExtension)"
    }
}
