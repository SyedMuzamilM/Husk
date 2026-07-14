//
//  AppUninstallService.swift
//  Husk
//

import Foundation

actor AppUninstallService {
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
                let display = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? name.replacingOccurrences(of: ".app", with: "")

                let size = (try? DirectorySizer.size(of: url).bytes) ?? 0
                let isSystem = path.hasPrefix("/System") || (bid?.hasPrefix("com.apple.") == true)

                apps.append(
                    AppEntry(
                        id: path,
                        name: display,
                        path: path,
                        bundleIdentifier: bid,
                        version: version,
                        byteCount: size,
                        isFromSystem: isSystem
                    )
                )
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func findLeftovers(for app: AppEntry) async -> [LeftoverItem] {
        guard let bid = app.bundleIdentifier, !bid.isEmpty else {
            return heuristicNameSearch(appName: app.name)
        }

        var results: [LeftoverItem] = []
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

        for (root, kind) in searchRoots {
            guard let children = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for name in children {
                if name.hasPrefix(".") { continue }
                let path = (root as NSString).appendingPathComponent(name)
                if path == app.path { continue }
                if PathSafety.isProtected(path) { continue }

                if matches(name: name, path: path, tokens: tokens, bundleID: bid) {
                    let bytes = (try? DirectorySizer.size(of: URL(fileURLWithPath: path)).bytes) ?? 0
                    let safety: SafetyLabel = kind == "Preferences" ? .caution : (kind == "Caches" ? .safe : .review)
                    results.append(
                        LeftoverItem(
                            path: path,
                            byteCount: bytes,
                            kind: kind,
                            safety: safety
                        )
                    )
                }
            }
        }

        // Preference plists by bundle id
        let prefs = (lib as NSString).appendingPathComponent("Preferences")
        let plist = (prefs as NSString).appendingPathComponent("\(bid).plist")
        if FileManager.default.fileExists(atPath: plist), !results.contains(where: { $0.path == plist }) {
            let bytes = (try? DirectorySizer.fileSize(URL(fileURLWithPath: plist)).bytes) ?? 0
            results.append(
                LeftoverItem(path: plist, byteCount: bytes, kind: "Preferences", safety: .caution)
            )
        }

        return results.sorted { $0.byteCount > $1.byteCount }
    }

    private func matchTokens(bundleID: String, appName: String) -> [String] {
        var tokens = Set<String>()
        tokens.insert(bundleID.lowercased())
        let parts = bundleID.split(separator: ".")
        if let last = parts.last { tokens.insert(String(last).lowercased()) }
        if parts.count >= 2 {
            tokens.insert(parts.suffix(2).joined(separator: ".").lowercased())
        }
        let cleaned = appName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".app", with: "")
        if cleaned.count >= 3 { tokens.insert(cleaned) }
        return Array(tokens)
    }

    private func matches(name: String, path: String, tokens: [String], bundleID: String) -> Bool {
        let lowerName = name.lowercased()
        let lowerPath = path.lowercased()
        if lowerName == bundleID.lowercased() { return true }
        if lowerName.hasPrefix(bundleID.lowercased()) { return true }
        for token in tokens where token.count >= 3 {
            if lowerName == token || lowerName.contains(token) || lowerPath.contains("/\(token)") {
                // Avoid ultra-generic tokens
                if token == "app" || token == "com" || token == "org" { continue }
                return true
            }
        }
        return false
    }

    private func heuristicNameSearch(appName: String) -> [LeftoverItem] {
        // Minimal fallback when no bundle id
        let cleaned = appName.replacingOccurrences(of: ".app", with: "")
        guard cleaned.count >= 3 else { return [] }
        let support = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/\(cleaned)")
        guard FileManager.default.fileExists(atPath: support) else { return [] }
        let bytes = (try? DirectorySizer.size(of: URL(fileURLWithPath: support)).bytes) ?? 0
        return [LeftoverItem(path: support, byteCount: bytes, kind: "Application Support", safety: .review)]
    }
}
