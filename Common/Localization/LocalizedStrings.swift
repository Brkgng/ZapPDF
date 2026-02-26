//
//  LocalizedStrings.swift
//  ZapPDF
//
//  Type-safe localized string constants for internationalization.
//

import Foundation

/// Centralized namespace for all localized strings in ZapPDF.
///
/// Static strings use `String(localized:)` with static keys.
/// Dynamic strings with interpolation use String.LocalizationValue.
///
/// Example:
/// ```swift
/// Text(L10n.Dashboard.title)
/// Text(L10n.Plural.pages(5))
/// ```
enum L10n {
    
    // MARK: - Common Actions
    
    enum Action {
        static let cancel = String(localized: "action.cancel", defaultValue: "Cancel")
        static let done = String(localized: "action.done", defaultValue: "Done")
        static let delete = String(localized: "action.delete", defaultValue: "Delete")
        static let remove = String(localized: "action.remove", defaultValue: "Remove")
        static let saveFile = String(localized: "action.saveFile", defaultValue: "Save File")
        static let saveFiles = String(localized: "action.saveFiles", defaultValue: "Save Files")
        static let close = String(localized: "action.close", defaultValue: "Close")
        static let retry = String(localized: "action.retry", defaultValue: "Try Again")
        static let `continue` = String(localized: "action.continue", defaultValue: "Continue")
        static let skip = String(localized: "action.skip", defaultValue: "Skip")
        static let getStarted = String(localized: "action.getStarted", defaultValue: "Get Started")
        static let selectAll = String(localized: "action.selectAll", defaultValue: "Select All")
        static let deselectAll = String(localized: "action.deselectAll", defaultValue: "Deselect All")
        static let undo = String(localized: "action.undo", defaultValue: "Undo")
        static let upgrade = String(localized: "action.upgrade", defaultValue: "Upgrade")
        static let ok = String(localized: "action.ok", defaultValue: "OK")
    }
    
    // MARK: - Dashboard
    
    enum Dashboard {
        static let title = String(localized: "dashboard.title", defaultValue: "ZapPDF")
        static let addFiles = String(localized: "dashboard.addFiles", defaultValue: "Add PDF Files")
        static let dropHere = String(localized: "dashboard.dropHere", defaultValue: "Drop PDF files here")
        static let dragAndDrop = String(localized: "dashboard.dragAndDrop", defaultValue: "Drag and drop PDF files or use the button below")
        static let browseFiles = String(localized: "dashboard.browseFiles", defaultValue: "Browse Files")
        static let dropToAdd = String(localized: "dashboard.dropToAdd", defaultValue: "Drop to add more files")
        static let clearAll = String(localized: "dashboard.clearAll", defaultValue: "Clear All")
        static let clearAllTitle = String(localized: "dashboard.clearAllTitle", defaultValue: "Clear All Files?")
        static let clearAllMessage = String(localized: "dashboard.clearAllMessage", defaultValue: "This will remove all PDF files from the list.")
        
        static func clearFiles(_ count: Int) -> String {
            String(localized: "Clear \(count) Files", comment: "Button showing count of files to clear")
        }
        
        static func undoMessage(_ count: Int) -> String {
            String(localized: "\(count) files cleared", comment: "Undo toast message")
        }
        
        static func selectedOfTotal(_ selected: Int, _ total: Int) -> String {
            String(localized: "\(selected) of \(total) selected", comment: "Selection count in status bar")
        }
        
        static func totalPages(_ count: Int) -> String {
            String(localized: "\(count) pages", comment: "Total page count in status bar")
        }
        
        static func failedToImport(_ error: String) -> String {
            String(localized: "Failed to import files: \(error)", comment: "File import error message")
        }
        
        static func moreFiles(_ count: Int) -> String {
            String(localized: "... and \(count) more files", comment: "Truncated file list indicator")
        }
        
        static let mergedOutputName = String(localized: "dashboard.mergedOutputName", defaultValue: "Merged")
        
        static func couldNotLoadFile(_ filename: String) -> String {
            String(localized: "Could not load '\(filename)'. Please select a valid PDF file.", comment: "Single file load error")
        }
        
        static func couldNotLoadFiles(_ count: Int, _ names: String) -> String {
            String(localized: "Could not load \(count) files: \(names)", comment: "Multiple file load error")
        }
    }
    
    // MARK: - PDF Operations
    
    enum Operation {
        enum Merge {
            static let title = String(localized: "operation.merge.title", defaultValue: "Merge PDFs")
            static let description = String(localized: "operation.merge.description", defaultValue: "Combine multiple PDFs into one document")
        }
        
        enum Split {
            static let title = String(localized: "operation.split.title", defaultValue: "Split PDF")
            static let description = String(localized: "operation.split.description", defaultValue: "Extract pages or split into multiple documents")
            static let extractRanges = String(localized: "operation.split.extractRanges", defaultValue: "Extract Page Ranges")
            static let selectPages = String(localized: "operation.split.selectPages", defaultValue: "Select Specific Pages")
            static let splitEvery = String(localized: "operation.split.splitEvery", defaultValue: "Split Every N Pages")
        }
        
        /// Edit Pages operation (reorder, rotate, delete).
        enum EditPages {
            static let title = String(localized: "operation.editPages.title", defaultValue: "Edit Pages")
            static let description = String(localized: "operation.editPages.description", defaultValue: "Reorder, rotate, and delete pages")
            static let save = String(localized: "operation.editPages.save", defaultValue: "Save")
        }
        
        enum Flatten {
            static let title = String(localized: "operation.flatten.title", defaultValue: "Flatten PDF")
            static let description = String(localized: "operation.flatten.description", defaultValue: "Bake annotations and forms into page content")
        }
    }
    
    // MARK: - Split Options
    
    enum SplitOptions {
        static let title = String(localized: "splitOptions.title", defaultValue: "Split Options")
        static let splitMode = String(localized: "splitOptions.splitMode", defaultValue: "Split Mode")
        static let options = String(localized: "splitOptions.options", defaultValue: "Options")
        static let outputPreview = String(localized: "splitOptions.outputPreview", defaultValue: "Output Preview")
        static let noOutput = String(localized: "splitOptions.noOutput", defaultValue: "No output files will be created")
        static let pagesPerFile = String(localized: "splitOptions.pagesPerFile", defaultValue: "Pages per file:")
        static let selectPagesToExtract = String(localized: "splitOptions.selectPagesToExtract", defaultValue: "Select pages to extract:")
        static let enterPageRanges = String(localized: "splitOptions.enterPageRanges", defaultValue: "Enter page numbers and ranges separated by commas")
        static let validRange = String(localized: "splitOptions.validRange", defaultValue: "Valid range")
        static let divideIntoChunks = String(localized: "splitOptions.divideIntoChunks", defaultValue: "Divide into equal chunks")
        static let specifyRanges = String(localized: "splitOptions.specifyRanges", defaultValue: "Specify ranges like 1-5, 10-15")
        static let pickPagesVisually = String(localized: "splitOptions.pickPagesVisually", defaultValue: "Pick individual pages visually")
        static let split = String(localized: "splitOptions.split", defaultValue: "Split")
        static let rangePlaceholder = String(localized: "splitOptions.rangePlaceholder", defaultValue: "e.g., 1-5, 10, 15-20")
        
        // iOS picker labels
        static let everyN = String(localized: "splitOptions.everyN", defaultValue: "Every N")
        static let ranges = String(localized: "splitOptions.ranges", defaultValue: "Ranges")
        static let select = String(localized: "splitOptions.select", defaultValue: "Select")
        
        static func totalFiles(_ count: Int) -> String {
            String(localized: "splitOptions.totalFiles \(count)")
        }
        
        // Mode descriptions for iOS
        static let modeDescSplitEvery = String(localized: "splitOptions.modeDesc.splitEvery", defaultValue: "Divide PDF into chunks of N pages each")
        static let modeDescPageRange = String(localized: "splitOptions.modeDesc.pageRange", defaultValue: "Enter page ranges like 1-5, 10, 15-20")
        static let modeDescSelectPages = String(localized: "splitOptions.modeDesc.selectPages", defaultValue: "Tap pages to select them")
        
        // Page count display
        static func pageCount(_ count: Int) -> String {
            String(localized: "splitOptions.pageCountPlural \(count)")
        }
        
        static func pagesSelected(_ count: Int) -> String {
            String(localized: "\(count) pages selected", comment: "Selected page count in page selector")
        }
        
        static func selectedOfTotal(_ selected: Int, _ total: Int) -> String {
            String(localized: "\(selected) of \(total) pages selected", comment: "Page selection count")
        }
        
        static func pageRange(_ page: Int) -> String {
            String(localized: "Page \(page)", comment: "Single page description")
        }
        
        static func pagesRange(_ start: Int, _ end: Int) -> String {
            String(localized: "Pages \(start)-\(end)", comment: "Page range description")
        }
        
        static func pagesLabel(_ list: String) -> String {
            String(localized: "Pages: \(list)", comment: "Selected pages list")
        }
    }

    // MARK: - Page Editor (Page Reorder)
    
    enum PageReorder {
        static let discardChangesTitle = String(localized: "pageReorder.discardChangesTitle", defaultValue: "Discard Changes?")
        static let discardChangesMessage = String(localized: "pageReorder.discardChangesMessage", defaultValue: "You have unsaved changes. Are you sure you want to discard them?")
        static let discard = String(localized: "pageReorder.discard", defaultValue: "Discard")
        static let tapDoneToSave = String(localized: "pageReorder.tapDoneToSave", defaultValue: "Tap Done to save changes")
        static let selectPageToPreview = String(localized: "pageReorder.selectPageToPreview", defaultValue: "Select a page to preview")
        static let loadingPages = String(localized: "pageReorder.loadingPages", defaultValue: "Loading pages...")
        
        // Rotation
        static let rotateLeft = String(localized: "pageEditor.rotateLeft", defaultValue: "Rotate Left")
        static let rotateRight = String(localized: "pageEditor.rotateRight", defaultValue: "Rotate Right")
        
        static func rotatedBy(_ degrees: Int) -> String {
            String(localized: "Rotated \(degrees)°", comment: "Rotation indicator showing current rotation")
        }
        
        static func page(_ number: Int) -> String {
            String(localized: "Page \(number)", comment: "Page number label")
        }
        
        static func originalPosition(_ position: Int) -> String {
            String(localized: "Original position: \(position)", comment: "Tooltip showing original page position")
        }
        
        static func savingProgress(_ progress: Double) -> String {
            let formatted = progress.formatted(.percent.precision(.fractionLength(0)))
            return String(localized: "Saving... \(formatted)", comment: "Save progress indicator")
        }
        
        static let finalizing = String(localized: "pageReorder.finalizing", defaultValue: "Finalizing file...")
        
        static func pageOf(_ current: Int, _ total: Int) -> String {
            String(localized: "Page \(current) of \(total)", comment: "Page navigation indicator")
        }
        
        static func movedFrom(_ position: Int) -> String {
            String(localized: "Moved from position \(position)", comment: "Label showing original page position")
        }
        
        // Error messages
        static let noChangesToSave = String(localized: "pageReorder.noChangesToSave", defaultValue: "No changes to save.")
        static let invalidPageOrder = String(localized: "pageReorder.invalidPageOrder", defaultValue: "Invalid page order.")
        static let cannotDeleteLastPage = String(localized: "pageReorder.cannotDeleteLastPage", defaultValue: "Cannot delete the last page")
        
        static func saveFailedTo(_ filename: String) -> String {
            String(localized: "Failed to save PDF to '\(filename)'.", comment: "Save failed error message")
        }
    }
    
    // MARK: - Common UI
    
    enum Common {
        static let loading = String(localized: "common.loading", defaultValue: "Loading...")
        static let mergeOrderHint = String(localized: "common.mergeOrderHint", defaultValue: "Files merge in displayed order. Drag to reorder.")
        static let selection = String(localized: "common.selection", defaultValue: "Selection")
        static let select = String(localized: "common.select", defaultValue: "Select")
        static let deselect = String(localized: "common.deselect", defaultValue: "Deselect")
        static let saveFailed = String(localized: "common.saveFailed", defaultValue: "Save Failed")
        static let unableToSave = String(localized: "common.unableToSave", defaultValue: "Unable to save the file.")
        static let errorTitle = String(localized: "common.errorTitle", defaultValue: "Error")
        static let errorOccurred = String(localized: "common.errorOccurred", defaultValue: "An error occurred")
        static let all = String(localized: "common.all", defaultValue: "All")
        static let none = String(localized: "common.none", defaultValue: "None")
        static let invalidFormat = String(localized: "common.invalidFormat", defaultValue: "Invalid format")
    }

    // MARK: - Processing
    
    enum Processing {
        static let preparing = String(localized: "processing.preparing", defaultValue: "Preparing...")
        static let finalizingFile = String(localized: "processing.finalizingFile", defaultValue: "Finalizing file...")
        static let largePDFWriteHint = String(localized: "processing.largePDFWriteHint", defaultValue: "Large PDFs may take a while to write.")
        static let cancelOperation = String(localized: "processing.cancelOperation", defaultValue: "Cancel Operation")
        static let cancelConfirmTitle = String(localized: "processing.cancelConfirmTitle", defaultValue: "Cancel Operation?")
        static let cancelConfirmMessage = String(localized: "processing.cancelConfirmMessage", defaultValue: "The current operation will be stopped and any progress will be lost.")
        static let completed = String(localized: "processing.completed", defaultValue: "Completed!")
        static let fileSaved = String(localized: "processing.fileSaved", defaultValue: "File Saved")
        static let fileSavedMessage = String(localized: "processing.fileSavedMessage", defaultValue: "Your PDF has been saved successfully.")
        static let filesSaved = String(localized: "processing.filesSaved", defaultValue: "Files Saved")
        private static let filesSavedMessageFormat = String(
            localized: "processing.filesSavedMessage",
            defaultValue: "Successfully saved %lld PDF files."
        )
        static func filesSavedMessage(_ count: Int) -> String {
            String(format: filesSavedMessageFormat, locale: Locale.current, count)
        }
        static let selectDestinationFolder = String(
            localized: "processing.selectDestinationFolder",
            defaultValue: "Choose a destination folder for split output files."
        )
        static let revealInFinder = String(localized: "processing.revealInFinder", defaultValue: "Reveal in Finder")
        static let share = String(localized: "processing.share", defaultValue: "Share")
        static let readyToSave = String(localized: "processing.readyToSave", defaultValue: "Your PDF is ready to save")
        static let somethingWentWrong = String(localized: "processing.somethingWentWrong", defaultValue: "Something Went Wrong")
        
        // Preview feature
        static let previewLoading = String(localized: "processing.previewLoading", defaultValue: "Loading preview...")
        static let previewNotAvailable = String(localized: "processing.previewNotAvailable", defaultValue: "Preview not available")
        static func outputPages(_ count: Int) -> String {
            String(localized: "\(count) pages", comment: "Output PDF page count on preview")
        }
        
        static func progress(_ value: Double) -> String {
            value.formatted(.percent.precision(.fractionLength(0)))
        }
        
        static func filesCreated(_ count: Int) -> String {
            String(localized: "\(count) files created", comment: "Number of output files created")
        }
        
        static func couldNotSaveFile(_ error: String) -> String {
            String(localized: "Could not save file: \(error)", comment: "File save error message")
        }
        
        static func mergingProgress(_ progress: Double) -> String {
            if progress > 0 {
                let formatted = progress.formatted(.percent.precision(.fractionLength(0)))
                return String(localized: "Merging PDFs... \(formatted)", comment: "Merge progress with percentage")
            }
            return String(localized: "processing.merging", defaultValue: "Merging PDFs...")
        }
        
        static func splittingProgress(_ progress: Double) -> String {
            if progress > 0 {
                let formatted = progress.formatted(.percent.precision(.fractionLength(0)))
                return String(localized: "Splitting PDF... \(formatted)", comment: "Split progress with percentage")
            }
            return String(localized: "processing.splitting", defaultValue: "Splitting PDF...")
        }
        
        static func reorderingProgress(_ progress: Double) -> String {
            if progress > 0 {
                let formatted = progress.formatted(.percent.precision(.fractionLength(0)))
                return String(localized: "Reordering pages... \(formatted)", comment: "Reorder progress with percentage")
            }
            return String(localized: "processing.reordering", defaultValue: "Reordering pages...")
        }
        
        static func flatteningProgress(_ progress: Double) -> String {
            if progress > 0 {
                let formatted = progress.formatted(.percent.precision(.fractionLength(0)))
                return String(localized: "Flattening PDF... \(formatted)", comment: "Flatten progress with percentage")
            }
            return String(localized: "processing.flattening", defaultValue: "Flattening PDF...")
        }
        
        static let pdfOperationFailed = String(localized: "processing.pdfOperationFailed", defaultValue: "PDF operation failed.")
        static let usageLimitReached = String(localized: "processing.usageLimitReached", defaultValue: "Usage limit reached.")
        static let unexpectedError = String(localized: "processing.unexpectedError", defaultValue: "An unexpected error occurred.")
    }
    
    // MARK: - Paywall / Subscription Status
    
    enum Paywall {
        /// "Pro" badge text
        static let pro = String(localized: "paywall.pro", defaultValue: "Pro")
        
        /// Status text when no actions left
        static func noActionsLeft() -> String {
            String(localized: "No actions left", comment: "Status when free actions exhausted")
        }
        
        /// Status text showing remaining actions (e.g., "2 actions left")
        static func actionsLeft(_ count: Int) -> String {
            String(localized: "\(count) actions left", comment: "Status showing remaining free actions")
        }
        
        /// Status text showing actions remaining of total (e.g., "4 of 5 free")
        static func actionsRemaining(_ count: Int, of total: Int) -> String {
            String(localized: "\(count) of \(total) free", comment: "Status showing X of Y free actions")
        }
    }
    
    // MARK: - Onboarding
    
    enum Onboarding {
        static let welcomeTitle = String(localized: "onboarding.welcomeTitle", defaultValue: "Welcome to ZapPDF")
        static let welcomeDescription = String(localized: "onboarding.welcomeDescription", defaultValue: "Your privacy-first PDF toolkit for merging, splitting, and organizing documents.")
        static let privacyTitle = String(localized: "onboarding.privacyTitle", defaultValue: "Privacy First")
        static let privacyDescription = String(localized: "onboarding.privacyDescription", defaultValue: "All your PDFs are processed locally on your device. Nothing is ever uploaded to the cloud.")
        static let featuresTitle = String(localized: "onboarding.featuresTitle", defaultValue: "Powerful Features")
        static let featuresDescription = String(localized: "onboarding.featuresDescription", defaultValue: "Merge multiple PDFs, split documents, and reorder pages with ease.")
        static let readyTitle = String(localized: "onboarding.readyTitle", defaultValue: "You're All Set!")
        static let readyDescription = String(localized: "onboarding.readyDescription", defaultValue: "Start by adding some PDF files to get going.")
        static let next = String(localized: "onboarding.next", defaultValue: "Next")
        static let previous = String(localized: "onboarding.previous", defaultValue: "Previous")
    }
    
    // MARK: - Errors
    
    enum Error {
        static func invalidPDF(filename: String) -> String {
            String(localized: "'\(filename)' is not a valid PDF file.", comment: "Error when file is not a valid PDF")
        }
        
        static func passwordProtected(filename: String) -> String {
            String(localized: "'\(filename)' is password protected.", comment: "Error when PDF is encrypted")
        }
        
        static func corruptedFile(filename: String) -> String {
            String(localized: "'\(filename)' appears to be corrupted.", comment: "Error when PDF is corrupted")
        }
        
        static let insufficientDiskSpace = String(localized: "error.insufficientDiskSpace", defaultValue: "Not enough storage space to complete this operation.")
        
        static func writeFailed(filename: String) -> String {
            String(localized: "Failed to save '\(filename)'.", comment: "Error when file write fails")
        }
        
        static let cancelled = String(localized: "error.cancelled", defaultValue: "Operation was cancelled.")
        
        static func invalidPageRange(start: Int, end: Int, total: Int) -> String {
            String(localized: "Page range \(start)-\(end) is invalid. Document has \(total) pages.", comment: "Error for invalid page range")
        }
        
        static let emptyInput = String(localized: "error.emptyInput", defaultValue: "No files provided for this operation.")
        
        static func fileNotFound(filename: String) -> String {
            String(localized: "File not found: '\(filename)'.", comment: "Error when file doesn't exist")
        }

        static func pageLoadFailed(filename: String, pageIndex: Int) -> String {
            String(
                localized: "Could not load page \(pageIndex) from '\(filename)'.",
                comment: "Error when a page cannot be read from a PDF"
            )
        }

        static func outlineMergeFailed(filename: String) -> String {
            String(
                localized: "Could not preserve bookmarks from '\(filename)'.",
                comment: "Error when outline/bookmark merge fails"
            )
        }
        
        static func accessDenied(filename: String) -> String {
            String(localized: "Cannot access '\(filename)'.", comment: "Error when file access is denied")
        }
        
        // Recovery suggestions
        static let selectValidPDF = String(localized: "error.recovery.selectValidPDF", defaultValue: "Please select a valid PDF file.")
        static let unlockPDF = String(localized: "error.recovery.unlockPDF", defaultValue: "Please unlock the PDF using another application first.")
        static let reselectFile = String(localized: "error.recovery.reselectFile", defaultValue: "Please select the file again using the file picker.")
        static let getFreshCopy = String(localized: "error.recovery.getFreshCopy", defaultValue: "Try obtaining a fresh copy of this file.")
        static let freeUpSpace = String(localized: "error.recovery.freeUpSpace", defaultValue: "Free up some storage space and try again.")
        static let checkPermissions = String(localized: "error.recovery.checkPermissions", defaultValue: "Check that you have write permission to the destination.")
        static let selectValidRange = String(localized: "error.recovery.selectValidRange", defaultValue: "Please select a valid page range within the document.")
        static let selectAtLeastOne = String(localized: "error.recovery.selectAtLeastOne", defaultValue: "Please select at least one PDF file.")
        static let fileMovedOrDeleted = String(localized: "error.recovery.fileMovedOrDeleted", defaultValue: "The file may have been moved or deleted.")
        static let reorderSomePages = String(localized: "error.recovery.reorderSomePages", defaultValue: "Reorder some pages before saving.")
        static let tryReorderingAgain = String(localized: "error.recovery.tryReorderingAgain", defaultValue: "Please try reordering again.")
        static let trySavingElsewhere = String(localized: "error.recovery.trySavingElsewhere", defaultValue: "Try saving to a different location.")
        static let tryAgain = String(localized: "error.recovery.tryAgain", defaultValue: "Please try again.")
        static let tryAnotherPDF = String(localized: "error.recovery.tryAnotherPDF", defaultValue: "Try a different PDF file.")
        static let tryDisablingBookmarks = String(localized: "error.recovery.tryDisablingBookmarks", defaultValue: "Try merging again with bookmark preservation turned off.")
        static let upgradeForUnlimited = String(localized: "error.recovery.upgradeForUnlimited", defaultValue: "Upgrade to Pro for unlimited PDF operations.")
        
        // Purchase/Restore errors
        static let title = String(localized: "error.title", defaultValue: "Error")
        static let purchaseFailed = String(localized: "error.purchaseFailed", defaultValue: "Purchase failed. Please try again.")
        static let restoreFailed = String(localized: "error.restoreFailed", defaultValue: "Restore failed. Please try again.")
    }
    
    // MARK: - Page Range Errors
    
    enum PageRangeError {
        static func invalidFormat(_ text: String) -> String {
            String(localized: "Invalid range format: '\(text)'", comment: "Page range parsing error")
        }
        
        static func pageOutOfRange(_ page: Int, _ maxPage: Int) -> String {
            String(localized: "Page \(page) is out of range (1-\(maxPage))", comment: "Page range bounds error")
        }
        
        static let emptyRange = String(localized: "pageRange.emptyRange", defaultValue: "No page ranges specified")
        
        static func invalidRange(_ start: Int, _ end: Int) -> String {
            String(localized: "Invalid range: \(start)-\(end) (start must be ≤ end)", comment: "Inverted page range error")
        }
    }
    
    // MARK: - File Access Errors
    
    enum FileAccessError {
        static func securityScopeAccessDenied(_ filename: String) -> String {
            String(localized: "Unable to access '\(filename)'. Please re-select the file.", comment: "Sandbox access denied")
        }
        
        static let bookmarkResolutionFailed = String(localized: "fileAccess.bookmarkResolutionFailed", defaultValue: "Could not restore access to a previously used file.")
        
        static func permissionDenied(_ filename: String) -> String {
            String(localized: "Permission denied for '\(filename)'", comment: "File permission error")
        }
        
        static func bookmarkCreationFailed(_ filename: String) -> String {
            String(localized: "Could not save reference to '\(filename)'", comment: "Bookmark creation error")
        }
        
        static let trySelectingAgain = String(localized: "fileAccess.recovery.trySelectingAgain", defaultValue: "Try selecting the file again.")
    }
    
    // MARK: - Usage Errors
    
    enum UsageError {
        static let noActionsRemaining = String(localized: "usage.noActionsRemaining", defaultValue: "You've used all your free actions.")
        static let persistenceFailed = String(localized: "usage.persistenceFailed", defaultValue: "Failed to save usage data.")
    }
    
    // MARK: - Validation
    
    enum Validation {
        static let selectMultipleForMerge = String(localized: "validation.selectMultipleForMerge", defaultValue: "Please select at least 2 PDF files to merge.")
        static let selectOneFile = String(localized: "validation.selectOneFile", defaultValue: "Please select a PDF file.")
        static let selectOnlyOne = String(localized: "validation.selectOnlyOne", defaultValue: "Please select only one PDF file for this action.")
    }
    
    // MARK: - Plurals
    
    enum Plural {
        static func pages(_ count: Int) -> String {
            String(localized: "\(count) pages", comment: "Number of pages (1 page, 5 pages)")
        }
    }
    
    // MARK: - Accessibility
    
    enum Accessibility {
        static let deleteFile = String(localized: "accessibility.deleteFile", defaultValue: "Remove file")
        static let selectFile = String(localized: "accessibility.selectFile", defaultValue: "Select file")
        static let deselectFile = String(localized: "accessibility.deselectFile", defaultValue: "Deselect file")
        static let dragHandle = String(localized: "accessibility.dragHandle", defaultValue: "Drag to reorder")
        static let upgradeHint = String(localized: "accessibility.upgradeHint", defaultValue: "Tap to view upgrade options")
        static let pdfDocument = String(localized: "accessibility.pdfDocument", defaultValue: "PDF Document")
        static let selectedTapHint = String(localized: "accessibility.selectedTapHint", defaultValue: "Selected. Double tap to deselect.")
        static let tapToSelectHint = String(localized: "accessibility.tapToSelectHint", defaultValue: "Double tap to select.")
        
        static func displayingPages(_ count: Int) -> String {
            String(localized: "Displaying \(count) pages", comment: "PDF viewer accessibility hint")
        }
    }
    
    // MARK: - Context Menu
    
    enum ContextMenu {
        static let showInFinder = String(localized: "contextMenu.showInFinder", defaultValue: "Show in Finder")
        static let copyName = String(localized: "contextMenu.copyName", defaultValue: "Copy Name")
    }
    
    // MARK: - Help (Tooltips)
    
    enum Help {
        static let undo = String(localized: "help.undo", defaultValue: "Undo (⌘Z)")
        static let redo = String(localized: "help.redo", defaultValue: "Redo (⌘⇧Z)")

        static let deletePage = String(localized: "help.deletePage", defaultValue: "Delete Selected Page (⌫)")
        static let clearAll = String(localized: "help.clearAll", defaultValue: "Remove all files from the list")
        static let rotateLeft = String(localized: "help.rotateLeft", defaultValue: "Rotate Left (⌘L)")
        static let rotateRight = String(localized: "help.rotateRight", defaultValue: "Rotate Right (⌘R)")
    }
    
    // MARK: - PDF Display Modes
    
    enum PDFDisplay {
        static let singlePage = String(localized: "pdfDisplay.singlePage", defaultValue: "Single Page")
        static let continuous = String(localized: "pdfDisplay.continuous", defaultValue: "Continuous")
        static let twoPages = String(localized: "pdfDisplay.twoPages", defaultValue: "Two Pages")
        static let twoPagesContinuous = String(localized: "pdfDisplay.twoPagesContinuous", defaultValue: "Two Pages (Continuous)")
    }
    
    // MARK: - Settings
    
    enum Settings {
        static let title = String(localized: "settings.title", defaultValue: "Settings")
        static let language = String(localized: "settings.language", defaultValue: "Language")
        static let languageDescription = String(localized: "settings.languageDescription", defaultValue: "Choose your preferred language")
        static let systemDefault = String(localized: "settings.systemDefault", defaultValue: "System Default")
        static let about = String(localized: "settings.about", defaultValue: "About")
        static let version = String(localized: "settings.version", defaultValue: "Version")
        static let subscription = String(localized: "settings.subscription", defaultValue: "Subscription")
        static let manageSubscription = String(localized: "settings.manageSubscription", defaultValue: "Manage Subscription")
        
        // Subscription status display
        static let proLifetime = String(localized: "settings.subscription.proLifetime", defaultValue: "Pro Lifetime")
        static let proAnnual = String(localized: "settings.subscription.proAnnual", defaultValue: "Pro Annual")
        static let proMonthly = String(localized: "settings.subscription.proMonthly", defaultValue: "Pro Monthly")
        static let freePlan = String(localized: "settings.subscription.freePlan", defaultValue: "Free Plan")
        static let proPlan = String(localized: "settings.subscription.proPlan", defaultValue: "Pro")
        
        static func renewsOn(_ date: String) -> String {
            String(localized: "Renews \(date)", comment: "Subscription renewal date")
        }
        
        static func expiresOn(_ date: String) -> String {
            String(localized: "Expires \(date)", comment: "Subscription expiration date")
        }
        
        // Subscription actions
        static let restorePurchases = String(localized: "settings.restorePurchases", defaultValue: "Restore Purchases")
        static let contactSupport = String(localized: "settings.contactSupport", defaultValue: "Contact Support")
        static let restoreSuccess = String(localized: "settings.restoreSuccess", defaultValue: "Purchases restored successfully!")
        static let restoreNoProducts = String(localized: "settings.restoreNoProducts", defaultValue: "No previous purchases found.")
        static let restartRequired = String(localized: "settings.restartRequired", defaultValue: "Restart Required")
        static let languageRestartMessage = String(localized: "settings.languageRestartMessage", defaultValue: "Language changes will take effect after restarting the app.")
    }
    
    // MARK: - Languages
    
    enum Language {
        static let english = String(localized: "language.english", defaultValue: "English")
        static let german = String(localized: "language.german", defaultValue: "German")
        static let french = String(localized: "language.french", defaultValue: "French")
        static let spanish = String(localized: "language.spanish", defaultValue: "Spanish")
        static let japanese = String(localized: "language.japanese", defaultValue: "Japanese")
        static let chineseSimplified = String(localized: "language.chineseSimplified", defaultValue: "Chinese (Simplified)")
        static let turkish = String(localized: "language.turkish", defaultValue: "Turkish")
    }
    
    // MARK: - Scanner (iOS only)
    
    enum Scanner {
        static let scanDocument = String(localized: "scanner.scanDocument", defaultValue: "Scan Document")
        static let importFromPhotos = String(localized: "scanner.importFromPhotos", defaultValue: "Import from Photos")
        static let processing = String(localized: "scanner.processing", defaultValue: "Creating PDF...")
        
        // Errors
        static let errorNotSupported = String(localized: "scanner.error.notSupported", defaultValue: "Document scanning is not supported on this device")
        static let errorNoImages = String(localized: "scanner.error.noImages", defaultValue: "No images were provided")
        static let errorPDFWriteFailed = String(localized: "scanner.error.pdfWriteFailed", defaultValue: "Failed to create PDF from scanned images")
        static let errorAllPagesFailed = String(localized: "scanner.error.allPagesFailed", defaultValue: "All pages failed to convert")
        
        static func errorCamera(_ detail: String) -> String {
            String(localized: "Camera error: \(detail)", comment: "Camera error with detail")
        }
        
        static func errorConversionFailed(_ pageNumber: Int) -> String {
            String(localized: "Failed to convert page \(pageNumber) to PDF", comment: "Image conversion error")
        }
        
        static func partialSuccess(_ saved: Int, _ total: Int) -> String {
            String(localized: "Saved \(saved) of \(total) pages", comment: "Partial conversion success message")
        }
    }
}
