//
//  AppUninstallService.swift
//  Husk
//

import Foundation

actor AppUninstallService {
    /// Fast listing — does **not** recursively size every app.
    func listApplications() async -> [AppEntry] {
        let roots = [
            "/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        var apps: [AppEntry] = []
        let fm = FileManager.default

        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in items where name.hasSuffix(".app") {
                let path = (root as NSString).appendingPathComponent(name)
                let url = URL(fileURLWithPath: path)
                let bundle = Bundle(url: url)
                let bid = bundle?.bundleIdentifier
                let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                let display = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? name.replacingOccurrences(of: ".app", with: "")

                let isSystem = path.hasPrefix("/System") || (bid?.hasPrefix("com.apple.") == true)

                apps.append(
                    AppEntry(
                        id: path,
                        name: display,
                        path: path,
                        bundleIdentifier: bid,
                        version: version,
                        byteCount: 0,
                        isFromSystem: isSystem
                    )
                )
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func sizeOfApp(at path: String) async -> Int64 {
        (try? DirectorySizer.size(of: URL(fileURLWithPath: path)).bytes) ?? 0
    }

    func findLeftovers(for app: AppEntry) async -> [LeftoverItem] {
        guard let bid = app.bundleIdentifier, !bid.isEmpty else {
            return await heuristicNameSearch(appName: app.name)
        }

        let home = NSHomeDirectory()
        let lib = (home as NSString).appendingPathComponent("Library")

        let searchRoots: [(String, String)] = [
            ((lib as NSString).appendingPathComponent("Application Support"), "Application Support"),
            ((lib as NSString).appendingPathComponent("Caches"), "Caches"),
            ((lib as NSString).appendingPathComponent("Preferences"), "Preferences"),
            ((lib as NSString).appendingPathComponent("Logs"), "Logs"),
            ((lib as NSString).appendingPathComponent("Saved Application State"), "Saved State"),
            ((lib as NSString).appendingPathComponent("Containers"), "Containers"),
            ((lib as NSString).appendingPathComponent("Group Containers"), "Group Containers"),
            ((lib as NSString).appendingPathComponent("WebKit"), "WebKit"),
            ((lib as NSString).appendingPathComponent("HTTPStorages"), "HTTP Storage")
        ]

        let tokens = matchTokens(bundleID: bid, appName: app.name)
        var candidates: [(path: String, kind: String, safety: SafetyLabel)] = []

        for (root, kind) in searchRoots {
            guard let children = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for name in children {
                if name.hasPrefix(".") { continue }
                let path = (root as NSString).appendingPathComponent(name)
                if path == app.path { continue }
                if PathSafety.isProtected(path) { continue }

                if matches(name: name, path: path, tokens: tokens, bundleID: bid) {
                    let safety: SafetyLabel =
                        kind == "Preferences" ? .caution : (kind == "Caches" ? .safe : .review)
                    candidates.append((path, kind, safety))
                }
            }
        }

        let prefs = (lib as NSString).appendingPathComponent("Preferences")
        let plist = (prefs as NSString).appendingPathComponent("\(bid).plist")
        if FileManager.default.fileExists(atPath: plist),
           !candidates.contains(where: { $0.path == plist }) {
            candidates.append((plist, "Preferences", .caution))
        }

        // Cap and size concurrently (sizing Containers fully was a major hang).
        let limited = Array(candidates.prefix(40))

        return await withTaskGroup(of: LeftoverItem?.self) { group in
            for c in limited {
                group.addTask {
                    let bytes = (try? DirectorySizer.size(of: URL(fileURLWithPath: c.path)).bytes) ?? 0
                    return LeftoverItem(
                        path: c.path,
                        byteCount: bytes,
                        kind: c.kind,
                        safety: c.safety
                    )
                }
            }
            var results: [LeftoverItem] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results.sorted { $0.byteCount > $1.byteCount }
        }
    }

    private func matchTokens(bundleID: String, appName: String) -> [String] {
        var tokens = Set<String>()
        tokens.insert(bundleID.lowercased())
        let parts = bundleID.split(separator: ".")
        if let last = parts.last, last.count >= 3 { tokens.insert(String(last).lowercased()) }
        if parts.count >= 2 {
            let joined = parts.suffix(2).joined(separator: ".").lowercased()
            if joined.count >= 5 { tokens.insert(joined) }
        }
        let cleaned = appName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".app", with: "")
        if cleaned.count >= 4 { tokens.insert(cleaned) }
        return Array(tokens)
    }

    private func matches(name: String, path: String, tokens: [String], bundleID: String) -> Bool {
        let lowerName = name.lowercased()
        let bid = bundleID.lowercased()
        if lowerName == bid { return true }
        if lowerName.hasPrefix(bid) { return true }
        // Prefer prefix/exact over loose contains to reduce false positives.
        for token in tokens where token.count >= 4 {
            if token == "app" || token == "com" || token == "org" || token == "net" { continue }
            if lowerName == token || lowerName.hasPrefix(token) || lowerName.contains(".\(token)") {
                return true
            }
            if lowerName.hasPrefix(token + ".") { return true }
        }
        _ = path
        return false
    }

    private func heuristicNameSearch(appName: String) async -> [LeftoverItem] {
        let cleaned = appName.replacingOccurrences(of: ".app", with: "")
        guard cleaned.count >= 3 else { return [] }
        let support = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/\(cleaned)")
        guard FileManager.default.fileExists(atPath: support) else { return [] }
        let bytes = (try? DirectorySizer.size(of: URL(fileURLWithPath: support)).bytes) ?? 0
        return [LeftoverItem(path: support, byteCount: bytes, kind: "Application Support", safety: .review)]
    }
}
