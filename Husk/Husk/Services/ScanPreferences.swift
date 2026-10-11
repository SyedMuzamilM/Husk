import Foundation

enum ScanPreferences {
    static var excludedPaths: [String] {
        UserDefaults.standard.stringArray(forKey: "husk.excludedPaths") ?? []
    }
    static var projectRoots: [String] {
        UserDefaults.standard.stringArray(forKey: "husk.projectRoots") ?? []
    }
    static func overlapsExclusion(_ path: String, exclusions: [String]? = nil) -> Bool {
        let normalized = PathSafety.canonicalPath(path)
        return (exclusions ?? excludedPaths).contains {
            let root = PathSafety.canonicalPath($0)
            return normalized.lowercased() == root.lowercased() || PathSafety.isDescendant(normalized, of: root) || PathSafety.isDescendant(root, of: normalized)
        }
    }
    static func isExcluded(_ path: String) -> Bool {
        let normalized = PathSafety.canonicalPath(path)
        return excludedPaths.contains {
            let root = PathSafety.canonicalPath($0)
            return normalized.lowercased() == root.lowercased() || PathSafety.isDescendant(normalized, of: root)
        }
    }
}
