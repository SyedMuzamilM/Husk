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
        try walk(inputURL, shouldCancel: shouldCancel, deadline: deadline, maxEntries: maxEntries)
    }

    private struct FileKey: Hashable {
        let device: Int32
        let inode: UInt64
        init(_ identity: FileIdentity) { device = identity.device; inode = identity.inode }
    }

    private static func walk(_ inputURL: URL, shouldCancel: @escaping @Sendable () -> Bool,
                             deadline: TimeInterval, maxEntries: Int,
                             observedFile: ((FileIdentity, Int64) -> Void)? = nil) throws -> SizeMeasurement {
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
        if rootValues.isUbiquitousItem == true && rootValues.ubiquitousItemDownloadingStatus != .current && rootValues.ubiquitousItemDownloadingStatus != .downloaded {
            return SizeMeasurement(status: .unavailable, issues: [OperationIssue(path: url.path, message: "Cloud-only item; not downloaded for sizing.")], totalIssueCount: 1)
        }
        if rootValues.isDirectory != true {
            let result = fileMeasurement(url, values: rootValues)
            if rootValues.isRegularFile == true { observedFile?(rootIdentity, result.bytes) }
            return result
        }
        // Enumerators report failures through this callback on the same worker.
        var errors: [OperationIssue] = []
        var errorCount = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [],
                                             errorHandler: { path, error in
            errorCount += 1
            if errors.count < 50 { errors.append(OperationIssue(path: path.path, message: error.localizedDescription)) }
            return true
        }) else { throw CocoaError(.fileReadNoPermission) }
        var seen: Set<FileKey> = []
        // Foundation produces autoreleased URLs and resource dictionaries.
        // Drain each iteration instead of retaining them until the whole scan ends.
        while let child = autoreleasepool(invoking: { enumerator.nextObject() as? URL }) {
            if shouldCancel() { throw CancellationError() }
            if result.visitedEntries >= maxEntries || started.duration(to: .now) > .seconds(deadline) {
                result.note(url.path, "Measurement limit reached; displayed size is partial.")
                break
            }
            result.visitedEntries += 1
            autoreleasepool {
                if PathSafety.shouldSkipDirectoryName(child.lastPathComponent) || PathSafety.shouldSkipForSizing(child.path)
                    || PathSafety.isSensitiveForReading(child.path) || excluded(child.path) {
                    enumerator.skipDescendants()
                    result.note(child.path, "Excluded or protected location.")
                    return
                }
                do {
                    let values = try child.resourceValues(forKeys: keys)
                    if values.isSymbolicLink == true { enumerator.skipDescendants(); return }
                    let identity = try FileIdentity.read(child.path)
                    if identity.device != rootIdentity.device {
                        enumerator.skipDescendants(); result.note(child.path, "Different volume; inspect it separately."); return
                    }
                    if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current && values.ubiquitousItemDownloadingStatus != .downloaded {
                        enumerator.skipDescendants(); result.note(child.path, "Cloud-only item; not downloaded for sizing."); return
                    }
                    if values.isRegularFile == true {
                        let key = FileKey(identity)
                        if seen.insert(key).inserted {
                            let bytes = allocated(values)
                            result.bytes += bytes
                            observedFile?(identity, bytes)
                            if values.totalFileAllocatedSize == nil && values.fileAllocatedSize == nil {
                                result.note(child.path, "Allocated size unavailable; logical size estimate used.")
                            }
                        }
                    }
                } catch { result.note(child.path, error.localizedDescription); enumerator.skipDescendants() }
            }
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

    private static func fileMeasurement(_ url: URL, values: URLResourceValues) -> SizeMeasurement {
        if values.isSymbolicLink == true { return SizeMeasurement(status: .unavailable) }
        var result = SizeMeasurement(bytes: allocated(values), modified: values.contentModificationDate)
        if values.totalFileAllocatedSize == nil && values.fileAllocatedSize == nil {
            result.note(url.path, "Allocated size unavailable; logical size estimate used.")
        }
        return result
    }

    /// Stream immediate children and measure each subtree once. The retained
    /// rows are bounded; one global budget covers discovery and measurement.
    static func listing(of inputURL: URL, maxChildren: Int = 100, includeHidden: Bool = true,
                        deadline: TimeInterval = 60, maxEntries: Int = 1_000_000) async throws -> DirectoryListing {
        let policy = ScanPreferences.excludedPaths
        var listing = try await BlockingIO.run { flag in
            try directoryListing(inputURL, maxChildren: maxChildren, includeHidden: includeHidden,
                                 deadline: deadline, maxEntries: maxEntries, shouldCancel: { flag.isCancelled })
        }
        try Task.checkCancellation()
        if policy != ScanPreferences.excludedPaths {
            listing.total.note(inputURL.path, "Exclusions changed while measuring. Scan again.")
        }
        return listing
    }

    private static func directoryListing(_ inputURL: URL, maxChildren: Int, includeHidden: Bool,
                                         deadline: TimeInterval, maxEntries: Int,
                                         shouldCancel: @escaping @Sendable () -> Bool) throws -> DirectoryListing {
        if shouldCancel() { throw CancellationError() }
        let url = URL(fileURLWithPath: PathSafety.canonicalPath(inputURL.path))
        guard !PathSafety.hasUnsafeSymlink(inputURL.path), !PathSafety.isSensitiveForReading(url.path),
              !PathSafety.shouldSkipForSizing(url.path), !ScanPreferences.isExcluded(url.path) else {
            throw RemovalError.changed("Excluded, protected, cloud, or symbolic-link location cannot be listed.")
        }
        let began = ContinuousClock.now
        let rootIdentity = try FileIdentity.read(url.path)
        let rootValues = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard rootValues.isDirectory == true else { throw CocoaError(.fileReadUnknown) }
        var total = SizeMeasurement(modified: rootValues.contentModificationDate)
        var parentFiles: Set<FileKey> = []
        var uniqueBytes: Int64 = 0
        var top = TopChildren(capacity: max(0, maxChildren))
        var childCount = 0
        let exclusions = ScanPreferences.excludedPaths.map(PathSafety.canonicalPath)
        let listingKeys = keys.union([.isHiddenKey])
        guard let enumerator = FileManager.default.enumerator(at: url,
            includingPropertiesForKeys: Array(listingKeys),
            options: [.skipsSubdirectoryDescendants], errorHandler: { path, error in
                total.note(path.path, error.localizedDescription)
                return true
            }) else { throw CocoaError(.fileReadNoPermission) }
        while true {
            if shouldCancel() { throw CancellationError() }
            let elapsed = began.duration(to: .now).components
            let remaining = deadline - Double(elapsed.seconds) - Double(elapsed.attoseconds) / 1e18
            if total.visitedEntries >= maxEntries || remaining <= 0 {
                total.note(url.path, "Listing limit reached. Sizes and item counts are partial; refresh or inspect a smaller folder.")
                break
            }
            guard let child = autoreleasepool(invoking: { enumerator.nextObject() as? URL }) else { break }
            total.visitedEntries += 1
            childCount += 1
            try autoreleasepool {
                var values: URLResourceValues?
                let sized: SizeMeasurement
                do {
                    values = try child.resourceValues(forKeys: listingKeys)
                    let identity = try FileIdentity.read(child.path)
                    if PathSafety.shouldSkipDirectoryName(child.lastPathComponent)
                        || PathSafety.isSensitiveForReading(child.path) || PathSafety.shouldSkipForSizing(child.path)
                        || exclusions.contains(where: { child.path.lowercased() == $0.lowercased() || PathSafety.isDescendant(child.path, of: $0) }) {
                        sized = SizeMeasurement(status: .unavailable,
                            issues: [OperationIssue(path: child.path, message: "Excluded, protected, or cloud location; not measured.")], totalIssueCount: 1)
                    } else if identity.isSymbolicLink || values?.isSymbolicLink == true {
                        sized = SizeMeasurement(status: .unavailable)
                    } else if identity.device != rootIdentity.device {
                        sized = SizeMeasurement(status: .unavailable,
                            issues: [OperationIssue(path: child.path, message: "Different volume; inspect it separately.")], totalIssueCount: 1)
                    } else if values?.isUbiquitousItem == true && values?.ubiquitousItemDownloadingStatus != .current && values?.ubiquitousItemDownloadingStatus != .downloaded {
                        sized = SizeMeasurement(status: .unavailable,
                            issues: [OperationIssue(path: child.path, message: "Cloud-only item; not downloaded for sizing.")], totalIssueCount: 1)
                    } else if let values, values.isDirectory != true {
                        sized = fileMeasurement(child, values: values)
                        if values.isRegularFile == true && parentFiles.insert(FileKey(identity)).inserted {
                            uniqueBytes += sized.bytes
                        }
                    } else {
                        sized = try walk(child, shouldCancel: shouldCancel, deadline: remaining,
                                         maxEntries: max(0, maxEntries - total.visitedEntries)) { identity, bytes in
                            if parentFiles.insert(FileKey(identity)).inserted { uniqueBytes += bytes }
                        }
                    }
                } catch is CancellationError { throw CancellationError() }
                catch {
                    sized = SizeMeasurement(status: .unavailable,
                        issues: [OperationIssue(path: child.path, message: error.localizedDescription)], totalIssueCount: 1)
                }
                total.visitedEntries += sized.visitedEntries
                if sized.status != .complete && sized.totalIssueCount > 0 {
                    total.status = .partial
                    total.totalIssueCount += sized.totalIssueCount
                    total.issues.append(contentsOf: sized.issues.prefix(max(0, 50 - total.issues.count)))
                }
                if includeHidden || (values?.isHidden != true && !child.lastPathComponent.hasPrefix(".")) {
                    top.insert(ChildMeasurement(name: child.lastPathComponent, path: child.path,
                        isDirectory: values?.isDirectory == true, measurement: sized))
                }
            }
        }
        total.bytes = uniqueBytes
        if (try? FileIdentity.read(url.path)) != rootIdentity {
            total.note(url.path, "Folder changed during measurement.")
        }
        let retained = top.sorted()
        return DirectoryListing(children: retained, total: total,
                                omittedBytes: max(0, total.bytes - retained.reduce(0) { $0 + $1.bytes }),
                                omittedCount: max(0, childCount - retained.count))
    }

    /// The heap root is the least useful retained row. Larger rows replace it
    /// without retaining or sorting every sibling. Path breaks equal-size ties.
    private struct TopChildren {
        let capacity: Int
        private var heap: [ChildMeasurement] = []
        init(capacity: Int) { self.capacity = capacity }
        private static func better(_ a: ChildMeasurement, _ b: ChildMeasurement) -> Bool {
            a.bytes == b.bytes ? a.path < b.path : a.bytes > b.bytes
        }
        mutating func insert(_ child: ChildMeasurement) {
            guard capacity > 0 else { return }
            if heap.count < capacity {
                heap.append(child)
                var index = heap.count - 1
                while index > 0 {
                    let parent = (index - 1) / 2
                    guard Self.better(heap[parent], heap[index]) else { break }
                    heap.swapAt(parent, index)
                    index = parent
                }
            } else if Self.better(child, heap[0]) {
                heap[0] = child
                var index = 0
                while index * 2 + 1 < heap.count {
                    var worst = index * 2 + 1
                    if worst + 1 < heap.count && Self.better(heap[worst], heap[worst + 1]) { worst += 1 }
                    guard Self.better(heap[index], heap[worst]) else { break }
                    heap.swapAt(index, worst)
                    index = worst
                }
            }
        }
        func sorted() -> [ChildMeasurement] { heap.sorted(by: Self.better) }
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
