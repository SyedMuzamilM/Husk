import Darwin
import Foundation

struct RemovalCandidate: Sendable {
    let path: String
    let bytes: Int64
    let safety: SafetyLabel
    let reason: String
    var ownerBundleID: String? = nil
}

struct RemovalEntry: Identifiable, Sendable {
    var id: String { path }
    let path: String
    let bytes: Int64
    let safety: SafetyLabel
    let reason: String
    let identity: FileIdentity
    let ownerBundleID: String?
}

struct OperationIssue: Identifiable, Codable, Sendable {
    var id: String { path + message }
    let path: String
    let message: String
}

/// The confirmation sheet owns this immutable snapshot. It never consults a
/// changing UI selection when executing it.
struct RemovalPlan: Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let title: String
    let entries: [RemovalEntry]
    let skipped: [OperationIssue]
    var estimatedBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    var hasCaution: Bool { entries.contains { $0.safety == .caution } }

    static func prepare(_ candidates: [RemovalCandidate], title: String,
                        runningBundleIDs: Set<String> = [], excludedPaths: [String] = ScanPreferences.excludedPaths) -> RemovalPlan {
        var skipped: [OperationIssue] = []
        var entries: [RemovalEntry] = []
        var seen: Set<FileIdentity> = []
        let sorted = candidates.sorted { $0.path.count == $1.path.count ? $0.path < $1.path : $0.path.count < $1.path.count }
        for candidate in sorted {
            let path = PathSafety.canonicalPath(candidate.path)
            let fail: (String) -> Void = { skipped.append(OperationIssue(path: candidate.path, message: $0)) }
            guard candidate.path.hasPrefix("/"), candidate.safety.isSelectable,
                  !PathSafety.isProtected(candidate.path), !PathSafety.hasUnsafeSymlink(candidate.path),
                  !ScanPreferences.overlapsExclusion(candidate.path, exclusions: excludedPaths) else {
                fail("Protected path or symbolic link; cannot move this item."); continue
            }
            if let owner = candidate.ownerBundleID, runningBundleIDs.contains(owner) {
                fail("The owning app is running. Quit it yourself, then review again."); continue
            }
            do {
                let identity = try FileIdentity.read(path)
                guard identity.owner == getuid() else { fail("Item belongs to another user; skipped."); continue }
                guard !identity.isSymbolicLink else { fail("Symbolic link; skipped."); continue }
                guard !entries.contains(where: { $0.path == path || PathSafety.isDescendant(path, of: $0.path) }),
                      seen.insert(identity).inserted else { continue }
                let nested = candidates.filter { PathSafety.isDescendant(PathSafety.canonicalPath($0.path), of: path) }
                let risk = ([candidate.safety] + nested.map(\.safety)).max() ?? candidate.safety
                guard risk.isSelectable else { fail("Selection contains inspection-only data. Select individual items instead."); continue }
                if nested.contains(where: { $0.ownerBundleID != nil && $0.ownerBundleID != candidate.ownerBundleID }) {
                    fail("Nested selection has a different app owner. Select individual items instead."); continue
                }
                entries.append(RemovalEntry(path: path, bytes: max(0, candidate.bytes), safety: risk,
                                            reason: candidate.reason + (risk > candidate.safety ? " Nested selection has greater risk: " + nested.filter { $0.safety > candidate.safety }.map(\.reason).joined(separator: "; ") : ""), identity: identity, ownerBundleID: candidate.ownerBundleID))
            } catch { fail(error.localizedDescription) }
        }
        return RemovalPlan(id: UUID(), createdAt: Date(), title: title, entries: entries, skipped: skipped)
    }
}
