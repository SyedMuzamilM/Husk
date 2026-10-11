import Foundation

/// Allocated-byte estimates. Hidden files and packages are included; hardlinks
/// are counted once per traversal. APFS clones/snapshots prevent a guarantee of
/// uniquely reclaimable bytes. No file contents or cloud placeholders are read.
enum DirectorySizer {
    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        .contentModificationDateKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey
    ]

    static func measurement(of inputURL: URL, shouldCancel: @escaping @Sendable () -> Bool = { false },
                            deadline: TimeInterval = 20, maxEntries: Int = 1_000_000) throws -> SizeMeasurement {
        if PathSafety.hasUnsafeSymlink(inputURL.path) { return SizeMeasurement(status: .unavailable) }
        let url = URL(fileURLWithPath: PathSafety.canonicalPath(inputURL.path))
        if shouldCancel() { throw CancellationError() }
        var result = SizeMeasurement()
        let started = ContinuousClock.now
        let fm = FileManager.default
        let exclusions = ScanPreferences.excludedPaths.map(PathSafety.canonicalPath)
        func excluded(_ path: String) -> Bool {
            exclusions.contains { path.lowercased() == $0.lowercased() || PathSafety.isDescendant(path, of: $0) }
        }
        if PathSafety.hasUnsafeSymlink(url.path) || excluded(PathSafety.canonicalPath(url.path)) || PathSafety.shouldSkipForSizing(url.path) || PathSafety.isSensitiveForReading(PathSafety.canonicalPath(url.path)) {
            return SizeMeasurement(status: .unavailable, issues: [OperationIssue(path: url.path, message: "Excluded, protected, cloud, or symbolic-link location.")], totalIssueCount: 1)
        }
        let rootIdentity = try FileIdentity.read(url.path)
        let rootValues = try url.resourceValues(forKeys: keys)
        result.modified = rootValues.contentModificationDate
        guard rootValues.isSymbolicLink != true else {
            result.status = .unavailable
            result.note(url.path, "Symbolic link excluded.")
            result.status = .unavailable
            return result
        }
        guard !ScanPreferences.isExcluded(url.path), !PathSafety.shouldSkipForSizing(url.path),
              !PathSafety.isSensitiveForReading(url.path) else {
            result.note(url.path, "Excluded or protected location; not measured.")
            result.status = .unavailable
            return result
        }
        if rootValues.isDirectory != true { return try fileMeasurement(url) }
        // Enumerators report failures through this callback on the same worker.
        var errors: [OperationIssue] = []
        var errorCount = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [],
                                             errorHandler: { path, error in
            errorCount += 1
            if errors.count < 50 { errors.append(OperationIssue(path: path.path, message: error.localizedDescription)) }
            return true
        }) else { throw CocoaError(.fileReadNoPermission) }
        var seen: Set<String> = []
        while let child = enumerator.nextObject() as? URL {
            if shouldCancel() { throw CancellationError() }
            if result.visitedEntries >= maxEntries || started.duration(to: .now) > .seconds(deadline) {
                result.note(url.path, "Measurement limit reached; displayed size is partial.")
                break
            }
            result.visitedEntries += 1
            if PathSafety.shouldSkipDirectoryName(child.lastPathComponent) || PathSafety.shouldSkipForSizing(child.path)
                || PathSafety.isSensitiveForReading(child.path) || excluded(child.path) {
                enumerator.skipDescendants()
                result.note(child.path, "Excluded or protected location.")
                continue
            }
            do {
                let values = try child.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                let identity = try FileIdentity.read(child.path)
                if identity.device != rootIdentity.device {
                    enumerator.skipDescendants(); result.note(child.path, "Different volume; inspect it separately."); continue
                }
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current && values.ubiquitousItemDownloadingStatus != .downloaded {
                    enumerator.skipDescendants(); result.note(child.path, "Cloud-only item; not downloaded for sizing."); continue
                }
                if values.isRegularFile == true {
                    let key = "\(identity.device):\(identity.inode)"
                    if seen.insert(key).inserted {
                        result.bytes += allocated(values)
                        if values.totalFileAllocatedSize == nil && values.fileAllocatedSize == nil {
                            result.note(child.path, "Allocated size unavailable; logical size estimate used.")
                        }
                    }
                }
            } catch { result.note(child.path, error.localizedDescription); enumerator.skipDescendants() }
        }
        if errorCount > 0 {
            result.status = .partial
            result.totalIssueCount += errorCount
            result.issues.append(contentsOf: errors.prefix(max(0, 50 - result.issues.count)))
        }
        if (try? FileIdentity.read(url.path)) != rootIdentity {
            result.note(url.path, "Folder changed during measurement.")
        }
        return result
    }

    static func measure(_ url: URL, useCache: Bool = true) async throws -> SizeMeasurement {
        try Task.checkCancellation()
        if useCache, let cached = await SizeCache.shared.get(url.path) { return cached }
        let policy = ScanPreferences.excludedPaths
        var result = try await BlockingIO.run { flag in
            try measurement(of: url, shouldCancel: { flag.isCancelled })
        }
        try Task.checkCancellation()
        if policy != ScanPreferences.excludedPaths { result.note(url.path, "Exclusions changed while measuring. Scan again.") }
        if useCache { await SizeCache.shared.store(result, for: url.path, exclusions: policy) }
        return result
    }

    private static func allocated(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
    }

    private static func fileMeasurement(_ url: URL) throws -> SizeMeasurement {
        let values = try url.resourceValues(forKeys: keys)
        if values.isSymbolicLink == true { return SizeMeasurement(status: .unavailable) }
        var result = SizeMeasurement(bytes: allocated(values), modified: values.contentModificationDate)
        if values.totalFileAllocatedSize == nil && values.fileAllocatedSize == nil {
            result.note(url.path, "Allocated size unavailable; logical size estimate used.")
        }
        return result
    }

    /// Measure every eligible child before choosing the largest displayed items.
    /// Parent totals use a single traversal for consistent hardlink accounting.
    static func listing(of inputURL: URL, maxChildren: Int = 100, includeHidden: Bool = true) async throws -> DirectoryListing {
        let url = URL(fileURLWithPath: PathSafety.canonicalPath(inputURL.path))
        guard !PathSafety.hasUnsafeSymlink(inputURL.path), !PathSafety.isSensitiveForReading(url.path),
              !PathSafety.shouldSkipForSizing(url.path), !ScanPreferences.isExcluded(url.path) else {
            throw RemovalError.changed("Excluded, protected, cloud, or symbolic-link location cannot be listed.")
        }
        let began = ContinuousClock.now
        let urls = try await BlockingIO.run { flag in
            if flag.isCancelled { throw CancellationError() }
            return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys),
                                                               options: includeHidden ? [] : [.skipsHiddenFiles])
        }
        let total = try await measure(url)
        let children = try await withThrowingTaskGroup(of: ChildMeasurement.self) { group in
            var iterator = urls.sorted { $0.path < $1.path }.makeIterator()
            func enqueue() {
                if let child = iterator.next() {
                    group.addTask {
                        try Task.checkCancellation()
                        let isDirectory = (try? await BlockingIO.run { _ in
                            try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                        }) ?? false
                        let sized: SizeMeasurement
                        do {
                            if began.duration(to: .now) > .seconds(60) {
                                sized = SizeMeasurement(status: .unavailable, issues: [OperationIssue(path: child.path, message: "Listing time budget reached.")], totalIssueCount: 1)
                            } else { sized = try await measure(child) }
                        }
                        catch is CancellationError { throw CancellationError() }
                        catch {
                            sized = SizeMeasurement(status: .unavailable,
                                issues: [OperationIssue(path: child.path, message: error.localizedDescription)], totalIssueCount: 1)
                        }
                        return ChildMeasurement(name: child.lastPathComponent, path: child.path,
                                                isDirectory: isDirectory, measurement: sized)
                    }
                }
            }
            for _ in 0..<4 { enqueue() }
            var results: [ChildMeasurement] = []
            for try await child in group { results.append(child); enqueue() }
            return results.sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
        }
        let retained = Array(children.prefix(maxChildren))
        return DirectoryListing(children: retained, total: total,
                                omittedBytes: max(0, total.bytes - retained.reduce(0) { $0 + $1.bytes }),
                                omittedCount: max(0, children.count - retained.count))
    }


}

actor SizeCache {
    static let shared = SizeCache()
    private struct Entry { let identity: FileIdentity; let result: SizeMeasurement; let date: Date; let exclusions: [String] }
    private var entries: [String: Entry] = [:]
    func get(_ path: String) -> SizeMeasurement? {
        guard let entry = entries[path], Date().timeIntervalSince(entry.date) < 10,
              entry.exclusions == ScanPreferences.excludedPaths, !ScanPreferences.isExcluded(path), (try? FileIdentity.read(path)) == entry.identity else { return nil }
        return entry.result
    }
    func store(_ result: SizeMeasurement, for path: String, exclusions: [String]) {
        guard result.status == .complete, let identity = try? FileIdentity.read(path) else { return }
        if entries.count >= 256 { entries.removeAll() }
        entries[path] = Entry(identity: identity, result: result, date: Date(), exclusions: exclusions)
    }
    func clear() { entries.removeAll() }
}
