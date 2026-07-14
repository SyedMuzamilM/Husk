//
//  PathSafety.swift
//  Husk
//

import Foundation

enum PathSafety: Sendable {
    /// Paths that must never be offered for deletion.
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

        // Never allow deleting the Husk app itself mid-scan edge cases
        if standardized.contains("/Husk.app") {
            return true
        }

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
        name == ".Trash"
            || name == "TimesMachine.localsnapshots"
            || name.hasPrefix(".")
            && (name == ".DocumentRevisions-V100" || name == ".MobileBackups" || name == ".Spotlight-V100")
    }
}
