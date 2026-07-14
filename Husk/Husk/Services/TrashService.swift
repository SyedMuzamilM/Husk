//
//  TrashService.swift
//  Husk
//

import Foundation

struct TrashResult: Sendable {
    var successPaths: [String] = []
    var failures: [(path: String, error: String)] = []
    var totalBytes: Int64 = 0

    var successCount: Int { successPaths.count }
}

enum TrashService: Sendable {
    /// Moves items to Trash only — never permanent delete.
    @discardableResult
    static func moveToTrash(
        paths: [String],
        byteLookup: [String: Int64] = [:],
        shouldCancel: () -> Bool = { false }
    ) throws -> TrashResult {
        var result = TrashResult()
        let fm = FileManager.default

        for path in paths {
            if shouldCancel() { throw CancellationError() }

            if PathSafety.isProtected(path) {
                result.failures.append((path, "Protected path — skipped"))
                continue
            }

            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else {
                result.failures.append((path, "Path no longer exists"))
                continue
            }

            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resultingURL)
                result.successPaths.append(path)
                result.totalBytes += byteLookup[path] ?? 0
            } catch {
                result.failures.append((path, error.localizedDescription))
            }
        }

        return result
    }
}
