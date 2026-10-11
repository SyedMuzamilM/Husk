import Foundation

actor AppUninstallService {
    func listApplications() async -> [AppEntry] {
        (try? await BlockingIO.run { flag in
            Self.discoverApplications(roots: ["/Applications", NSHomeDirectory() + "/Applications"], shouldCancel: { flag.isCancelled })
        }) ?? []
    }

    static func discoverApplications(roots: [String], shouldCancel: () -> Bool = { false }) -> [AppEntry] {
        var apps: [AppEntry] = []
        var seen = Set<String>()
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            var visited = 0
            while let url = enumerator.nextObject() as? URL {
                visited += 1
                if shouldCancel() || visited > 10_000 { break }
                let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                if values?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                if url.pathComponents.count - URL(fileURLWithPath: root).pathComponents.count > 3 {
                    enumerator.skipDescendants(); continue
                }
                guard url.pathExtension == "app", values?.isDirectory == true else { continue }
                enumerator.skipDescendants()
                let path = PathSafety.canonicalPath(url.path)
                guard seen.insert(path).inserted else { continue }
                let bundle = Bundle(url: url)
                let bid = bundle?.bundleIdentifier
                let display = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(AppEntry(id: path, name: display, path: path, bundleIdentifier: bid,
                    version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                    byteCount: 0, isFromSystem: PathSafety.isProtected(path) || bid?.hasPrefix("com.apple.") == true))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func sizeOfApp(at path: String) async -> SizeMeasurement {
        (try? await DirectorySizer.measure(URL(fileURLWithPath: path))) ?? SizeMeasurement(status: .unavailable)
    }

    /// Only exact, full bundle-ID paths. Group containers and display-name
    /// matches are intentionally absent because they do not prove ownership.
    static func associatedPaths(bundleID: String, home: String) -> [(path: String, kind: String)] {
        guard !bundleID.isEmpty, !bundleID.contains("/"), !bundleID.contains("\0"), bundleID.contains("."),
              bundleID != ".", bundleID != ".." else { return [] }
        return ["Application Support", "Caches", "Preferences", "Logs", "Saved Application State", "Containers", "WebKit", "HTTPStorages"].map {
            let suffix = $0 == "Preferences" ? ".plist" : $0 == "Saved Application State" ? ".savedState" : ""
            return (home + "/Library/" + $0 + "/" + bundleID + suffix, $0)
        }
    }

    func findLeftovers(for app: AppEntry) async -> [LeftoverItem] {
        guard let bid = app.bundleIdentifier, !app.isFromSystem else { return [] }
        let installed = await listApplications()
        // Multiple copies use the same data. Preserve it while another exists.
        guard !installed.contains(where: { $0.path != app.path && $0.bundleIdentifier == bid }) else { return [] }
        var results: [LeftoverItem] = []
        for candidate in Self.associatedPaths(bundleID: bid, home: NSHomeDirectory()) {
            if Task.isCancelled { break }
            guard !PathSafety.isProtected(candidate.path), !PathSafety.hasUnsafeSymlink(candidate.path),
                  !ScanPreferences.isExcluded(candidate.path), FileManager.default.fileExists(atPath: candidate.path) else { continue }
            let measurement = try? await DirectorySizer.measure(URL(fileURLWithPath: candidate.path))
            results.append(LeftoverItem(path: candidate.path, byteCount: measurement?.bytes ?? 0,
                kind: candidate.kind + ". Exact bundle ID; may contain personal data. Size " + (measurement?.status.rawValue ?? "unavailable"),
                safety: candidate.kind == "Caches" || candidate.kind == "Logs" ? .review : .caution))
        }
        return results.sorted { $0.byteCount > $1.byteCount }
    }
}
