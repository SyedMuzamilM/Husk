//
//  AppEntry.swift
//  Husk
//

import AppKit
import Foundation

struct AppEntry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let bundleIdentifier: String?
    let version: String?
    let byteCount: Int64
    let isFromSystem: Bool

    var url: URL { URL(fileURLWithPath: path) }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}

struct LeftoverItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let byteCount: Int64
    let kind: String
    let safety: SafetyLabel

    init(
        id: UUID = UUID(),
        path: String,
        byteCount: Int64,
        kind: String,
        safety: SafetyLabel = .review
    ) {
        self.id = id
        self.path = path
        self.byteCount = byteCount
        self.kind = kind
        self.safety = safety
    }

    var url: URL { URL(fileURLWithPath: path) }
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
}

struct OptimizeTask: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let needsAdmin: Bool
}
