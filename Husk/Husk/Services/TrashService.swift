import Foundation

struct TrashDestination: Identifiable, Codable, Sendable {
    var id: String { originalPath }
    let originalPath: String
    let trashPath: String
}

struct TrashResult: Identifiable, Sendable {
    let id = UUID()
    var destinations: [TrashDestination] = []
    var failures: [(path: String, error: String)] = []
    var skipped: [OperationIssue] = []
    var journalError: String?
    var cancelled = false
    var totalBytes: Int64 = 0
    var successPaths: [String] { destinations.map(\.originalPath) }
    var successCount: Int { destinations.count }
    var hasProblems: Bool { journalError != nil || cancelled || !failures.isEmpty || !skipped.isEmpty }
}

enum TrashService {
    /// UI callers use RemovalService's shared gate and a confirmed immutable plan.
    /// The injectable move operation keeps tests out of the real Trash.
    static func execute(
        _ plan: RemovalPlan,
        runningBundleIDs: Set<String> = [],
        excludedPaths: [String] = ScanPreferences.excludedPaths,
        shouldCancel: @Sendable () -> Bool = { false },
        move: @Sendable (URL) throws -> URL = { url in
            var destination: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &destination)
            guard let destination else { throw CocoaError(.fileWriteUnknown) }
            return destination as URL
        }
    ) -> TrashResult {
        var result = TrashResult()
        result.skipped = plan.skipped
        guard Date().timeIntervalSince(plan.createdAt) < 300 else {
            result.failures = plan.entries.map { ($0.path, "Review expired. Prepare a fresh selection.") }
            return result
        }
        for entry in plan.entries {
            if shouldCancel() { result.cancelled = true; break }
            do {
                guard entry.safety.isSelectable, !PathSafety.isProtected(entry.path), !PathSafety.hasUnsafeSymlink(entry.path),
                      PathSafety.canonicalPath(entry.path) == entry.path else {
                    throw RemovalError.changed("Path became protected or redirected.")
                }
                guard try FileIdentity.read(entry.path) == entry.identity else {
                    throw RemovalError.changed("Item changed since review. Scan and review it again.")
                }
                if let owner = entry.ownerBundleID, runningBundleIDs.contains(owner) {
                    throw RemovalError.changed("The owning app is running. Quit it before removal.")
                }
                guard !ScanPreferences.overlapsExclusion(entry.path, exclusions: excludedPaths) else {
                    throw RemovalError.changed("This path is now excluded in Settings.")
                }
                let destination = try move(URL(fileURLWithPath: entry.path))
                result.destinations.append(TrashDestination(originalPath: entry.path, trashPath: destination.path))
                result.totalBytes += entry.bytes
            } catch { result.failures.append((entry.path, error.localizedDescription)) }
        }
        return result
    }
}

enum RemovalError: LocalizedError {
    case changed(String)
    case busy
    var errorDescription: String? {
        switch self {
        case .changed(let message): message
        case .busy: "Another removal is running. Wait for its result before trying again."
        }
    }
}
