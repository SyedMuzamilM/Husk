//
//  CacheDetailService.swift
//  Husk
//

import Foundation

/// On-demand deep-ish breakdown for a single cache path (never blocks Clean scan).
actor CacheDetailService {
    func detail(for path: String, topN: Int = 40) async -> CacheDetailReport {
        let url = URL(fileURLWithPath: path)
        let total = (try? DirectorySizer.size(of: url).bytes) ?? 0
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate

        var files = 0
        var folders = 0
        var children: [(name: String, path: String, isDir: Bool)] = []

        if let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in urls {
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                let isDir = values?.isDirectory == true
                let isPackage = values?.isPackage == true
                if isDir && !isPackage {
                    folders += 1
                    children.append((child.lastPathComponent, child.path, true))
                } else {
                    files += 1
                    children.append((child.lastPathComponent, child.path, false))
                }
            }
        }

        // Size children concurrently (bounded)
        let limited = Array(children.prefix(80))
        let entries: [CacheBreakdownEntry] = await withTaskGroup(of: CacheBreakdownEntry?.self) { group in
            for child in limited {
                group.addTask {
                    let bytes: Int64
                    if child.isDir {
                        bytes = (try? DirectorySizer.size(of: URL(fileURLWithPath: child.path)).bytes) ?? 0
                    } else {
                        bytes = (try? DirectorySizer.fileSize(URL(fileURLWithPath: child.path)).bytes) ?? 0
                    }
                    var nested: Int?
                    if child.isDir {
                        nested = try? FileManager.default.contentsOfDirectory(atPath: child.path).count
                    }
                    return CacheBreakdownEntry(
                        name: child.name,
                        path: child.path,
                        byteCount: bytes,
                        isDirectory: child.isDir,
                        childCount: nested
                    )
                }
            }
            var out: [CacheBreakdownEntry] = []
            for await item in group {
                if let item { out.append(item) }
            }
            return out
                .sorted { $0.byteCount > $1.byteCount }
                .prefix(topN)
                .map { $0 }
        }

        return CacheDetailReport(
            path: path,
            totalBytes: total,
            immediateChildren: files + folders,
            fileCountApprox: files,
            folderCountApprox: folders,
            modified: modified,
            topEntries: entries,
            scannedAt: Date()
        )
    }
}
