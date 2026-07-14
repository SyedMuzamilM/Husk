//
//  CleanModels.swift
//  Husk
//

import Foundation

struct CleanItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let categoryID: String
    let categoryName: String
    let byteCount: Int64
    let safety: SafetyLabel
    let reason: String
    let modified: Date?
    /// Immediate child count (cheap directory listing at scan time).
    let entryCount: Int?

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
        entryCount: Int? = nil
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
    }

    var url: URL { URL(fileURLWithPath: path) }
}

struct CleanCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let items: [CleanItem]

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.byteCount }
    }
}

struct CleanScanProgress: Sendable, Equatable {
    var fraction: Double
    var currentPath: String
    var itemsFound: Int
    var bytesFound: Int64
}

struct CleanScanResult: Sendable {
    let categories: [CleanCategory]
    let scannedAt: Date
    let duration: TimeInterval

    var allItems: [CleanItem] {
        categories.flatMap(\.items)
    }

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }
}

enum ScanPhase: Equatable, Sendable {
    case idle
    case scanning(CleanScanProgress)
    case ready
    case trashing
    case finished(trashedBytes: Int64, itemCount: Int)
    case failed(String)
}
