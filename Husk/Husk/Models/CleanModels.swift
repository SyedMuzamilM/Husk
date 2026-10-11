//
//  CleanModels.swift
//  Husk
//

import Foundation

/// Represents an individual cache, log, or build artifact folder discovered on the file system.
struct CleanItem: Identifiable, Hashable, Sendable {
    /// Unique identifier for the item.
    let id: UUID
    /// Display name of the item (e.g. "DerivedData", "com.apple.Safari").
    let name: String
    /// Absolute path to the item on disk.
    let path: String
    /// Key representing the category this item belongs to (e.g. "developer", "ai-agents").
    let categoryID: String
    /// User-facing category label (e.g. "Developer Caches", "AI Agents").
    let categoryName: String
    /// Calculated size of the folder or file in bytes.
    let byteCount: Int64
    /// Safety classification label indicating risk if removed.
    let safety: SafetyLabel
    /// Text description explaining what this item is and why it's safe/unsafe to delete.
    let reason: String
    /// Date when the item was last modified.
    let modified: Date?
    /// Immediate child count (cheap directory listing at scan time).
    let entryCount: Int?
    let completeness: ScanCompleteness
    let ownerBundleID: String?

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        categoryID: String,
        categoryName: String,
        byteCount: Int64,
        safety: SafetyLabel,
        reason: String,
        modified: Date? = nil,
        entryCount: Int? = nil,
        completeness: ScanCompleteness = .complete,
        ownerBundleID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.byteCount = byteCount
        self.safety = safety
        self.reason = reason
        self.modified = modified
        self.entryCount = entryCount
        self.completeness = completeness
        self.ownerBundleID = ownerBundleID
    }

    /// URL representation of the item's filesystem path.
    var url: URL { URL(fileURLWithPath: path) }
}

/// Represents a collection of CleanItems grouped by a specific category.
struct CleanCategory: Identifiable, Hashable, Sendable {
    /// Unique identifier for the category.
    let id: String
    /// Name of the category.
    let name: String
    /// SF Symbols image name for the category icon.
    let systemImage: String
    /// Items grouped under this category.
    let items: [CleanItem]

    /// Sum of sizes of all items in this category.
    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.byteCount }
    }
}

/// Progress metrics reported during the disk scanning phase.
struct CleanScanProgress: Sendable, Equatable {
    /// Scan completion fraction (0.0 to 1.0).
    var fraction: Double
    /// The current directory path being scanned.
    var currentPath: String
    /// Total number of cleanable items found so far.
    var itemsFound: Int
    /// Total bytes size of cleanable items found so far.
    var bytesFound: Int64
}

/// Represents the final completed results of a clean scan.
struct CleanScanResult: Sendable {
    /// List of item categories and their matching items.
    let categories: [CleanCategory]
    /// Date and time when the scan was executed.
    let scannedAt: Date
    /// Total time spent scanning the targets.
    let duration: TimeInterval
    var coverageIssues: [OperationIssue] = []

    /// All items flat-mapped across all categories.
    var allItems: [CleanItem] {
        categories.flatMap(\.items)
    }

    /// Grand total size of all scanned clutter items.
    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }
}

/// Represents the current state or stage of the cleaning flow.
enum ScanPhase: Equatable, Sendable {
    /// App is idle and waiting to start scanning.
    case idle
    /// App is currently traversing the disk and gathering targets.
    case scanning(CleanScanProgress)
    /// Scan completed successfully; ready to review and delete.
    case ready
    /// Deletion in progress; trashing files.
    case trashing
    /// Completed moving selected files to trash.
    case finished(trashedBytes: Int64, itemCount: Int)
    /// Scan or deletion failed with an error message.
    case failed(String)
}
