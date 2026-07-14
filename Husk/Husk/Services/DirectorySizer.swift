//
//  DirectorySizer.swift
//  Husk
//

import Foundation

/// Fast directory size calculation using resource values (allocated size when available).
enum DirectorySizer: Sendable {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .fileSizeKey,
        .isHiddenKey,
        .contentModificationDateKey,
        .nameKey
    ]

    static func size(
        of url: URL,
        shouldCancel: () -> Bool = { false }
    ) throws -> (bytes: Int64, modified: Date?) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, nil)
        }

        if !isDir.boolValue {
            return try fileSize(url)
        }

        var total: Int64 = 0
        var latest: Date?

        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let item = enumerator?.nextObject() as? URL {
            if shouldCancel() { throw CancellationError() }

            let values = try item.resourceValues(forKeys: resourceKeys)
            if values.isSymbolicLink == true { continue }
            if values.isDirectory == true { continue }

            let size = values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.fileSize
                ?? 0
            total += Int64(size)

            if let mod = values.contentModificationDate {
                if latest == nil || mod > latest! {
                    latest = mod
                }
            }
        }

        return (total, latest)
    }

    static func fileSize(_ url: URL) throws -> (bytes: Int64, modified: Date?) {
        let values = try url.resourceValues(forKeys: [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey
        ])
        let size = values.totalFileAllocatedSize
            ?? values.fileAllocatedSize
            ?? values.fileSize
            ?? 0
        return (Int64(size), values.contentModificationDate)
    }

    /// Bounded shallow listing for treemap: immediate children with sizes.
    static func childSizes(
        of url: URL,
        maxChildren: Int = 80,
        shouldCancel: () -> Bool = { false }
    ) throws -> [(name: String, path: String, isDirectory: Bool, bytes: Int64)] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        var results: [(String, String, Bool, Int64)] = []
        results.reserveCapacity(min(contents.count, maxChildren))

        for child in contents.prefix(maxChildren * 2) {
            if shouldCancel() { throw CancellationError() }
            let name = child.lastPathComponent
            if PathSafety.shouldSkipDirectoryName(name) { continue }
            if PathSafety.isProtected(child.path) { continue }

            let values = try child.resourceValues(forKeys: resourceKeys)
            let isDir = values.isDirectory == true && values.isPackage != true
            let isPackage = values.isPackage == true

            if isDir && !isPackage {
                let sized = try size(of: child, shouldCancel: shouldCancel)
                results.append((name, child.path, true, sized.bytes))
            } else {
                let sized = try fileSize(child)
                results.append((name, child.path, false, sized.bytes))
            }
        }

        return results
            .sorted { $0.3 > $1.3 }
            .prefix(maxChildren)
            .map { ($0.0, $0.1, $0.2, $0.3) }
    }
}
