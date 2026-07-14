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

    init() {
        refresh()
    }

    func refresh() {
        hasFullDiskAccess = Self.probeFullDiskAccess()
        lastChecked = Date()
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
            ?? URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")!
        NSWorkspace.shared.open(url)
    }

    /// Heuristic: try reading a TCC-protected path outside the sandbox profile.
    nonisolated static func probeFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let candidates = [
            (home as NSString).appendingPathComponent("Library/Safari"),
            (home as NSString).appendingPathComponent("Library/Mail"),
            (home as NSString).appendingPathComponent("Library/Containers/com.apple.Safari"),
            (home as NSString).appendingPathComponent("Library/Application Support/com.apple.TCC")
        ]

        let fm = FileManager.default
        for path in candidates {
            if fm.isReadableFile(atPath: path) {
                // Attempt a lightweight listing where applicable
                if let contents = try? fm.contentsOfDirectory(atPath: path), !contents.isEmpty {
                    return true
                }
                // Readable file path counts on some macOS versions
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
                    return true
                }
            }
        }

        // Fallback: DataVaults / TCC may still block; try Cookies
        let cookies = (home as NSString).appendingPathComponent("Library/Cookies")
        if let _ = try? fm.contentsOfDirectory(atPath: cookies) {
            return true
        }

        return false
    }
}
