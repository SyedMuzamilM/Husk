//
//  PathSafety.swift
//  Husk
//

import Darwin
import Foundation

enum PathSafety: Sendable {
    private static let absoluteDenyPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/private/var/folders",
        "/Library/Apple",
        "/Library/OSAnalytics",
        "/Library/Updates",
        "/Applications/Utilities"
    ]

    private static let homeDenySuffixes: [String] = [
        "Library/Keychains",
        "Library/Mail",
        "Library/Messages",
        "Library/Accounts",
        "Library/Cookies",
        // Browser session/cookie/profile data in Application Support is strictly protected
        "Library/Application Support/Google/Chrome",
        "Library/Application Support/Firefox",
        "Library/Application Support/BraveSoftware",
        "Library/Application Support/com.microsoft.edgemac",
        "Library/Application Support/Company.TheBrowserCompany.Arc",
        "Library/Application Support/Safari",
        ".ssh",
        ".gnupg",
        ".config/gcloud"
    ]

    static func isProtected(_ path: String) -> Bool {
        guard path.hasPrefix("/"), !path.contains("\0") else { return true }
        let standardized = canonicalPath(path)

        if standardized == "/" || standardized.isEmpty {
            return true
        }

        if isProtectedAIStorage(standardized) { return true }

        for prefix in absoluteDenyPrefixes {
            if overlaps(standardized, prefix) {
                return true
            }
        }

        let home = canonicalPath(NSHomeDirectory())
        if overlaps(standardized, home) && !isDescendant(standardized, of: home) {
            return true
        }

        for suffix in homeDenySuffixes {
            let deny = (home as NSString).appendingPathComponent(suffix)
            if overlaps(standardized, deny) {
                return true
            }
        }

        let additional = [".Trash", ".aws", ".kube", ".azure", ".codex/auth.json",
                          ".claude", "Library/CloudStorage", "Library/Mobile Documents"]
        if additional.contains(where: { overlaps(standardized, home + "/" + $0) }) {
            return true
        }

        let bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "app", overlaps(standardized, canonicalPath(bundle.path)) { return true }
        // User and system directory roots are never removal candidates.
        let broadRoots = ["/Applications", "/Library", "/Volumes", home + "/Applications",
                          home + "/Documents", home + "/Downloads", home + "/Desktop",
                          home + "/Library/Caches", home + "/Library/Logs",
                          home + "/Library/Containers", home + "/Library/Group Containers",
                          home + "/Library/Application Support", home + "/Library/Preferences"]
        if broadRoots.contains(where: { canonicalPath($0).lowercased() == standardized.lowercased() }) { return true }

        return false
    }

    /// AI state cannot become an arbitrary Analyze/App removal candidate.
    /// Only fixed cache leaves in the catalog are eligible inside these containers.
    static func isProtectedAIStorage(_ path: String, home: String = NSHomeDirectory()) -> Bool {
        let normalized = canonicalPath(path)
        let containers = [".codex", ".claude", ".gemini", ".local/share/opencode", ".config/opencode",
                          "Library/Application Support/Codex", "Library/Application Support/Claude",
                          "Library/Application Support/Cursor", "Library/Application Support/Antigravity",
                          "Library/Caches/Codex"]
        let dataRoots = AIStorageCatalog.rules.filter { !$0.removable }.map { $0.relativePath }
        for suffix in containers + dataRoots {
            let root = canonicalPath((home as NSString).appendingPathComponent(suffix))
            if normalized.lowercased() == root.lowercased() || isDescendant(normalized, of: root) || isDescendant(root, of: normalized) {
                if AIStorageCatalog.cacheRule(for: normalized, home: home) == nil { return true }
            }
        }
        return false
    }

    static func canonicalPath(_ path: String) -> String {
        if let resolved = realpath(path, nil) {
            defer { free(resolved) }
            return String(cString: resolved)
        }
        // Resolve the nearest existing ancestor for paths not created yet.
        let absolute = URL(fileURLWithPath: path).standardizedFileURL.path
        var parent = absolute
        var suffix: [String] = []
        while parent != "/" {
            suffix.insert((parent as NSString).lastPathComponent, at: 0)
            parent = (parent as NSString).deletingLastPathComponent
            if let resolved = realpath(parent, nil) {
                defer { free(resolved) }
                return suffix.reduce(String(cString: resolved)) { ($0 as NSString).appendingPathComponent($1) }
            }
        }
        return absolute
    }

    static func isDescendant(_ path: String, of parent: String) -> Bool {
        let base = parent == "/" ? "" : parent.hasSuffix("/") ? String(parent.dropLast()) : parent
        return path.lowercased().hasPrefix(base.lowercased() + "/")
    }

    private static func overlaps(_ path: String, _ protected: String) -> Bool {
        let a = canonicalPath(path).lowercased()
        let b = canonicalPath(protected).lowercased()
        return a == b || isDescendant(a, of: b) || isDescendant(b, of: a)
    }

    /// macOS exposes /var and /tmp as system aliases. Other symlink components
    /// are rejected at the mutation boundary, including a symlink leaf.
    static func hasUnsafeSymlink(_ path: String) -> Bool {
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        var current = ""
        for component in components.dropFirst() {
            current += "/" + component
            if let attributes = try? FileManager.default.attributesOfItem(atPath: current),
               attributes[.type] as? FileAttributeType == .typeSymbolicLink,
               !["/var", "/tmp", "/etc"].contains(current) { return true }
        }
        return false
    }

    /// Paths that often hang remote/cloud APIs — skip during bulk sizing.
    static func shouldSkipForSizing(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.contains("mobile documents") { return true }
        if lower.contains("com~apple~clouddocs") { return true }
        if lower.contains("library/cloudstorage") { return true }
        if lower.hasSuffix("/library/caches/com.apple.bird") { return true }
        return false
    }

    private static let readDenyPaths = (absoluteDenyPrefixes + (homeDenySuffixes + [".aws", ".azure", ".kube", ".codex/auth.json", ".claude", ".local/share/opencode", "Library/Application Support/Codex", "Library/CloudStorage", "Library/Mobile Documents"]).map { NSHomeDirectory() + "/" + $0 }).map { canonicalPath($0).lowercased() }

    static func isSensitiveForReading(_ path: String) -> Bool {
        let normalized = path.lowercased()
        return readDenyPaths.contains { deny in
            return normalized == deny || isDescendant(normalized, of: deny)
        }
    }

    static func classifyCachePath(_ path: String) -> (SafetyLabel, String) {
        if isProtected(path) {
            return (.protected, "Protected system or sensitive path")
        }

        let lower = path.lowercased()
        let name = (path as NSString).lastPathComponent.lowercased()

        if lower.contains("/caches/") || name == "cache" || name.hasSuffix(".cache") {
            if ["com.apple.safari", "com.apple.webkit"].contains(name) {
                return (.safe, "Browser cache — recreated automatically")
            }
            return (.review, "Unverified application cache. May contain offline data; review its contents.")
        }

        if lower.contains("/logs/") || name.hasSuffix(".log") {
            return (.review, "Logs may contain useful diagnostics or history. Review before removal.")
        }

        if lower.contains("deriveddata") {
            return (.review, "Xcode DerivedData — rebuilds on next compile")
        }

        if lower.contains("coresimulator") {
            return (.review, "iOS Simulator data — review before removing")
        }

        if name == "node_modules" {
            return (.review, "Node dependencies — reinstall with npm/yarn/pnpm")
        }

        if lower.contains(".ollama") || lower.contains("lmstudio") {
            return (.caution, "Local AI model data — may be large and slow to re-download")
        }

        if lower.contains("application support") {
            return (.caution, "App support data — may include settings or offline data")
        }

        if lower.contains("preferences") || name.hasSuffix(".plist") {
            return (.caution, "Preferences — removing may reset app settings")
        }

        return (.review, "Review before removing")
    }

    static func shouldSkipDirectoryName(_ name: String) -> Bool {
        switch name {
        case ".Trash", "TimesMachine.localsnapshots",
             ".DocumentRevisions-V100", ".MobileBackups", ".Spotlight-V100",
             ".fseventsd", ".TemporaryItems":
            return true
        default:
            return false
        }
    }
}

/// Safe dictionary builders that never crash on duplicate keys.
enum DictUtil {
    static func uniquingFirst<K: Hashable, V>(_ pairs: [(K, V)]) -> [K: V] {
        var result: [K: V] = [:]
        result.reserveCapacity(pairs.count)
        for (k, v) in pairs {
            if result[k] == nil { result[k] = v }
        }
        return result
    }

    static func uniquingLast<K: Hashable, V>(_ pairs: [(K, V)]) -> [K: V] {
        Dictionary(pairs, uniquingKeysWith: { _, new in new })
    }
}
