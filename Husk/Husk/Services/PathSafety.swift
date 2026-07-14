//
//  PathSafety.swift
//  Husk
//

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
        ".ssh",
        ".gnupg",
        ".config/gcloud"
    ]

    static func isProtected(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath

        if standardized == "/" || standardized.isEmpty {
            return true
        }

        for prefix in absoluteDenyPrefixes {
            if standardized == prefix || standardized.hasPrefix(prefix + "/") {
                return true
            }
        }

        let home = NSHomeDirectory()
        if standardized == home {
            return true
        }

        for suffix in homeDenySuffixes {
            let deny = (home as NSString).appendingPathComponent(suffix)
            if standardized == deny || standardized.hasPrefix(deny + "/") {
                return true
            }
        }

        if standardized.contains("/Husk.app") {
            return true
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

    static func classifyCachePath(_ path: String) -> (SafetyLabel, String) {
        if isProtected(path) {
            return (.protected, "Protected system or sensitive path")
        }

        let lower = path.lowercased()
        let name = (path as NSString).lastPathComponent.lowercased()

        if lower.contains("/caches/") || name == "cache" || name.hasSuffix(".cache") {
            if lower.contains("webkit") || lower.contains("chromium") || lower.contains("com.apple.safari") {
                return (.safe, "Browser cache — recreated automatically")
            }
            return (.safe, "Application cache — usually regenerable")
        }

        if lower.contains("/logs/") || name.hasSuffix(".log") {
            return (.safe, "Log files — safe to remove")
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
