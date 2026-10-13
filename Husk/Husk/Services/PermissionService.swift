//
//  PermissionService.swift
//  Husk
//

import AppKit
import Foundation

@Observable
@MainActor
final class PermissionService {
    private(set) var hasFullDiskAccess: Bool = false
    private(set) var lastChecked: Date?
    private(set) var isChecking: Bool = false
    private var task: Task<Void, Never>?

    /// Never block the main thread or app launch with TCC-sensitive directory listings.
    init() {
        // Intentionally empty — call `refresh()` from `.task` after first frame.
    }

    func refresh() {
        guard !isChecking else { return }
        isChecking = true

        // Previews: skip heavy/TCC probes so the host app can launch instantly.
        if AppRuntime.isXcodePreview || AppRuntime.isUIFixture {
            hasFullDiskAccess = false
            lastChecked = Date()
            isChecking = false
            return
        }

        task = Task { [weak self] in
            let granted = (try? await BlockingIO.run { _ in Self.probeFullDiskAccess() }) ?? false
            guard let self, !Task.isCancelled else { return }
            hasFullDiskAccess = granted
            lastChecked = Date()
            isChecking = false
            task = nil
        }
    }

    isolated deinit { task?.cancel() }

    func openFullDiskAccessSettings() {
        // macOS Ventura+ privacy pane deep link; fall back to general Privacy & Security.
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Lightweight FDA heuristic — avoid recursive listings that can hang on TCC.
    nonisolated static func probeFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        // Single-file readability checks are much safer than directory enumeration.
        let candidates = [
            (home as NSString).appendingPathComponent("Library/Safari/Bookmarks.plist"),
            (home as NSString).appendingPathComponent("Library/Safari/CloudTabs.db"),
            (home as NSString).appendingPathComponent("Library/Mail/V10"),
            (home as NSString).appendingPathComponent("Library/Mail/V9"),
            (home as NSString).appendingPathComponent("Library/Containers/com.apple.Safari/Data")
        ]

        let fm = FileManager.default
        for path in candidates {
            // `isReadableFile` does not hang the way some directory listings can under TCC.
            if fm.isReadableFile(atPath: path) {
                return true
            }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                // Existence of protected container paths alone is not enough; try a non-blocking check.
                if fm.isReadableFile(atPath: path) {
                    return true
                }
            }
        }
        return false
    }
}
