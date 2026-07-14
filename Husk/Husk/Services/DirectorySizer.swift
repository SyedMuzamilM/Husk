//
//  DirectorySizer.swift
//  Husk
//

import Foundation

/// Fast directory size calculation.
/// Prefers `/usr/bin/du` (native, much faster) with a pure-Swift enumerator fallback.
enum DirectorySizer: Sendable {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .nameKey
    ]

    /// Soft cap for Swift fallback enumeration (prevents multi-minute freezes).
    private static let maxEnumeratorFiles = 250_000

    static func size(
        of url: URL,
        shouldCancel: @escaping () -> Bool = { false }
    ) throws -> (bytes: Int64, modified: Date?) {
        if shouldCancel() { throw CancellationError() }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, nil)
        }

        if !isDir.boolValue {
            return try fileSize(url)
        }

        // Packages (.app): still walk / du the bundle.
        if let duBytes = duSize(path: url.path, shouldCancel: shouldCancel) {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            return (duBytes, modified)
        }

        return try enumerateSize(of: url, shouldCancel: shouldCancel)
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

    /// Immediate children with sizes. Uses concurrent `du` for directories.
    static func childSizes(
        of url: URL,
        maxChildren: Int = 40,
        shouldCancel: @escaping @Sendable () -> Bool = { false }
    ) async throws -> [(name: String, path: String, isDirectory: Bool, bytes: Int64)] {
        let fm = FileManager.default
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        if shouldCancel() { throw CancellationError() }

        struct Child: Sendable {
            let name: String
            let path: String
            let isDirectory: Bool
        }

        var pending: [Child] = []
        pending.reserveCapacity(contents.count)

        for child in contents {
            if shouldCancel() { throw CancellationError() }
            let name = child.lastPathComponent
            if PathSafety.shouldSkipDirectoryName(name) { continue }
            if PathSafety.isProtected(child.path) { continue }
            // Skip cloud / network traps that hang sizing
            if PathSafety.shouldSkipForSizing(child.path) { continue }

            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            let isPackage = values?.isPackage == true
            let isDir = values?.isDirectory == true && !isPackage

            pending.append(Child(name: name, path: child.path, isDirectory: isDir || isPackage))
        }

        // Cap work for responsiveness
        let limited = Array(pending.prefix(max(maxChildren * 2, maxChildren)))

        return try await withThrowingTaskGroup(of: (String, String, Bool, Int64)?.self) { group in
            for child in limited {
                group.addTask {
                    if shouldCancel() { return nil }
                    let bytes: Int64
                    if child.isDirectory {
                        bytes = (try? DirectorySizer.size(
                            of: URL(fileURLWithPath: child.path),
                            shouldCancel: shouldCancel
                        ).bytes) ?? 0
                    } else {
                        bytes = (try? DirectorySizer.fileSize(URL(fileURLWithPath: child.path)).bytes) ?? 0
                    }
                    guard bytes > 0 else {
                        // Keep zero-size visible folders so treemap isn't empty of known names
                        return (child.name, child.path, child.isDirectory, max(bytes, 0))
                    }
                    return (child.name, child.path, child.isDirectory, bytes)
                }
            }

            var results: [(String, String, Bool, Int64)] = []
            for try await item in group {
                if shouldCancel() { throw CancellationError() }
                if let item { results.append(item) }
            }

            return results
                .sorted { $0.3 > $1.3 }
                .prefix(maxChildren)
                .map { ($0.0, $0.1, $0.2, $0.3) }
        }
    }

    // MARK: - Private

    /// `du -sk` returns kilobytes; multiply by 1024.
    private static func duSize(path: String, shouldCancel: @escaping () -> Bool) -> Int64? {
        if shouldCancel() { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Poll so we can respect cancel without waiting forever.
        while process.isRunning {
            if shouldCancel() {
                process.terminate()
                return nil
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)
        else { return nil }

        // Output: "12345\t/path"
        let kbString = text.split(whereSeparator: { $0 == "\t" || $0 == " " }).first
            .map(String.init) ?? ""
        guard let kb = Int64(kbString) else { return nil }
        return kb * 1024
    }

    private static func enumerateSize(
        of url: URL,
        shouldCancel: @escaping () -> Bool
    ) throws -> (bytes: Int64, modified: Date?) {
        var total: Int64 = 0
        var latest: Date?
        var fileCount = 0

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return (0, nil)
        }

        while let item = enumerator.nextObject() as? URL {
            fileCount += 1
            if fileCount & 0x3FF == 0 { // every 1024 entries
                if shouldCancel() { throw CancellationError() }
            }
            if fileCount > maxEnumeratorFiles {
                break
            }

            let values = try? item.resourceValues(forKeys: resourceKeys)
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true { continue }

            let size = values?.totalFileAllocatedSize
                ?? values?.fileAllocatedSize
                ?? values?.fileSize
                ?? 0
            total += Int64(size)

            if let mod = values?.contentModificationDate {
                if latest == nil || mod > latest! {
                    latest = mod
                }
            }
        }

        return (total, latest)
    }
}
