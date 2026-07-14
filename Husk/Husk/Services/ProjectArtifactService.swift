//
//  ProjectArtifactService.swift
//  Husk
//
//  Inspired by Mole `mo purge` — find node_modules, build/, target, .next, etc.
//  Performance: shallow scan of common project roots only (not entire home).
//

import Foundation

struct ProjectArtifact: Sendable {
    let name: String
    let path: String
    let kind: String
    let safety: SafetyLabel
    let reason: String
}

enum ProjectArtifactService: Sendable {
    /// Artifact folder names we treat as regenerable build junk.
    static let artifactNames: Set<String> = [
        "node_modules",
        "target",
        ".build",
        "build",
        "dist",
        ".next",
        ".nuxt",
        ".turbo",
        ".parcel-cache",
        "__pycache__",
        ".venv",
        "venv",
        ".tox",
        ".mypy_cache",
        ".pytest_cache",
        ".gradle",
        "Pods",
        ".dart_tool",
        "DerivedData"
    ]

    static func defaultSearchRoots() -> [String] {
        let home = NSHomeDirectory()
        let candidates = [
            "Projects", "Project", "Developer", "Dev", "dev", "Code", "code",
            "GitHub", "gitlab", "src", "work", "Work", "repos", "Repos",
            "Documents/Projects", "Documents/Code", "Desktop"
        ]
        var roots: [String] = []
        for c in candidates {
            let path = (home as NSString).appendingPathComponent(c)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                roots.append(path)
            }
        }
        return roots
    }

    /// Bounded discovery: maxDepth 4 under each root, max 80 hits.
    static func discover(
        maxDepth: Int = 4,
        maxHits: Int = 80,
        shouldCancel: @escaping () -> Bool = { false }
    ) -> [ProjectArtifact] {
        var found: [ProjectArtifact] = []
        let fm = FileManager.default
        let roots = defaultSearchRoots()
        guard !roots.isEmpty else { return [] }

        for root in roots {
            if shouldCancel() { break }
            guard found.count < maxHits else { break }

            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if shouldCancel() { break }
                if found.count >= maxHits { break }

                let depth = url.pathComponents.count - URL(fileURLWithPath: root).pathComponents.count
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                let name = url.lastPathComponent
                guard artifactNames.contains(name) else { continue }

                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true { continue }
                guard values?.isDirectory == true else { continue }

                // Avoid nested node_modules inside node_modules
                if name == "node_modules" {
                    let parent = url.deletingLastPathComponent().lastPathComponent
                    if parent == "node_modules" {
                        enumerator.skipDescendants()
                        continue
                    }
                }

                // Don't purge global Xcode DerivedData via project scan
                if name == "DerivedData", url.path.contains("/Library/Developer/Xcode/") {
                    enumerator.skipDescendants()
                    continue
                }

                let projectName = url.deletingLastPathComponent().lastPathComponent
                let (safety, reason) = classify(name)
                found.append(
                    ProjectArtifact(
                        name: "\(projectName)/\(name)",
                        path: url.path,
                        kind: name,
                        safety: safety,
                        reason: reason
                    )
                )
                enumerator.skipDescendants()
            }
        }

        return found
    }

    private static func classify(_ kind: String) -> (SafetyLabel, String) {
        switch kind {
        case "node_modules":
            return (.review, "JS dependencies — reinstall with npm/yarn/pnpm/bun")
        case "target":
            return (.review, "Rust/Cargo build output — recreated by cargo build")
        case ".build", "build", "dist":
            return (.review, "Build output — recreated by your build tool")
        case ".next", ".nuxt":
            return (.review, "Framework build cache — recreated on next build")
        case ".turbo", ".parcel-cache":
            return (.safe, "Bundler cache — safe regenerable")
        case "__pycache__", ".mypy_cache", ".pytest_cache", ".tox":
            return (.safe, "Python bytecode/cache — regenerable")
        case ".venv", "venv":
            return (.caution, "Virtual environment — reinstall packages after delete")
        case "Pods":
            return (.review, "CocoaPods — run pod install to restore")
        case ".dart_tool":
            return (.review, "Flutter/Dart tool cache")
        case ".gradle":
            return (.review, "Gradle project cache")
        default:
            return (.review, "Project build artifact")
        }
    }
}
