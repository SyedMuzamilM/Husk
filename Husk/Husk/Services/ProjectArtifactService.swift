import Foundation

struct ProjectArtifact: Sendable {
    let name: String
    let path: String
    let kind: String
    let safety: SafetyLabel
    let reason: String
}

struct ProjectDiscoveryReport: Sendable {
    let artifacts: [ProjectArtifact]
    let issues: [OperationIssue]
}

enum ProjectArtifactService {
    // Ambiguous build/dist, dependencies, environments, and source-bearing
    // directories are excluded until tracked-file and activity checks exist.
    static let manifests: [String: [String]] = [
        ".next": ["package.json"], ".nuxt": ["package.json"], ".turbo": ["package.json"],
        ".parcel-cache": ["package.json"], ".mypy_cache": ["pyproject.toml"],
        ".pytest_cache": ["pyproject.toml"], ".dart_tool": ["pubspec.yaml"]
    ]
    static var artifactNames: Set<String> { Set(manifests.keys) }

    static func defaultSearchRoots() -> [String] {
        let paths = ScanPreferences.projectRoots
        // Project discovery is opt-in. No crawling Desktop or all of home.
        let sorted = Set(paths.map(PathSafety.canonicalPath)).sorted()
        return sorted.filter { path in !sorted.contains { $0 != path && PathSafety.isDescendant(path, of: $0) } }
    }

    static func discover(roots: [String]? = nil, maxDepth: Int = 4, maxHits: Int = 80,
                         shouldCancel: () -> Bool = { false }) -> [ProjectArtifact] {
        discovery(roots: roots, maxDepth: maxDepth, maxHits: maxHits, shouldCancel: shouldCancel).artifacts
    }

    static func discovery(roots: [String]? = nil, maxDepth: Int = 4, maxHits: Int = 80,
                         shouldCancel: () -> Bool = { false }) -> ProjectDiscoveryReport {
        var found: [ProjectArtifact] = []
        var issues: [OperationIssue] = []
        var seen = Set<String>()
        for root in roots ?? defaultSearchRoots() {
            guard !PathSafety.hasUnsafeSymlink(root), !ScanPreferences.isExcluded(root),
                  !PathSafety.isSensitiveForReading(root) else { continue }
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants], errorHandler: { url, error in
                    if issues.count < 50 { issues.append(OperationIssue(path: url.path, message: error.localizedDescription)) }
                    return true
                }) else { issues.append(OperationIssue(path: root, message: "Project root could not be listed.")); continue }
            var visits = 0
            while let url = enumerator.nextObject() as? URL {
                visits += 1
                if shouldCancel() { break }
                if visits > 20_000 || found.count >= maxHits {
                    issues.append(OperationIssue(path: root, message: "Project discovery limit reached. Results are partial.")); break
                }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
                let name = url.lastPathComponent
                if name == ".git" || name == "node_modules" || name == ".venv" || name == "venv"
                    || values?.isSymbolicLink == true || ScanPreferences.isExcluded(url.path)
                    || PathSafety.isSensitiveForReading(url.path) || PathSafety.shouldSkipForSizing(url.path)
                    || url.pathComponents.count - URL(fileURLWithPath: root).pathComponents.count > maxDepth {
                    if url.pathComponents.count - URL(fileURLWithPath: root).pathComponents.count > maxDepth {
                        if issues.count < 50 { issues.append(OperationIssue(path: url.path, message: "Project discovery depth limit reached.")) }
                    }
                    enumerator.skipDescendants(); continue
                }
                guard let expected = manifests[name], values?.isDirectory == true else { continue }
                enumerator.skipDescendants()
                let parent = url.deletingLastPathComponent()
                guard expected.contains(where: { FileManager.default.fileExists(atPath: parent.appendingPathComponent($0).path) }) else { continue }
                // These candidates are inspection-only until Git tracking and
                // running build checks can prove safe regeneration.
                guard seen.insert(url.path).inserted else { continue }
                found.append(ProjectArtifact(name: parent.lastPathComponent + "/" + name, path: url.path,
                    kind: name, safety: .protected, reason: "Project cache found. Inspection only: Git tracking and active-build ownership are not yet verified."))
            }
        }
        return ProjectDiscoveryReport(artifacts: found, issues: issues)
    }
}
