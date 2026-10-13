//
//  CleanScanner.swift
//  Husk
//

import Foundation

struct CleanTarget: Sendable {
    let categoryID: String
    let categoryName: String
    let systemImage: String
    let name: String
    let path: String
    let safetyOverride: SafetyLabel?
    let reasonOverride: String?
}

/// Concurrent, cancellable scanner for regenerable caches and developer artifacts.
actor CleanScanner {
    func scan(
        progress: @Sendable @escaping (CleanScanProgress) -> Void
    ) async throws -> CleanScanResult {
        let started = Date()

        progress(
            CleanScanProgress(
                fraction: 0,
                currentPath: "Preparing targets…",
                itemsFound: 0,
                bytesFound: 0
            )
        )

        let discovery = try await BlockingIO.run { flag in
            try Self.discoverTargets(shouldCancel: { flag.isCancelled })
        }
        var targets = discovery.targets
        var coverageIssues = discovery.issues

        // Opt-in project cache inspection. Unverified outputs remain protected.
        progress(
            CleanScanProgress(
                fraction: 0.02,
                currentPath: "Finding project artifacts…",
                itemsFound: 0,
                bytesFound: 0
            )
        )
        let artifacts = try await BlockingIO.run { cancellation in
            ProjectArtifactService.discovery(maxDepth: 4, maxHits: 60) { cancellation.isCancelled }
        }
        try Task.checkCancellation()
        coverageIssues += artifacts.issues
        for a in artifacts.artifacts {
            targets.append(
                CleanTarget(
                    categoryID: "project-artifacts",
                    categoryName: "Project Artifacts",
                    systemImage: "shippingbox.and.arrow.backward",
                    name: a.name,
                    path: a.path,
                    safetyOverride: a.safety,
                    reasonOverride: a.reason
                )
            )
        }

        let discoveredTargets = targets
        targets = try await BlockingIO.run { _ in Self.uniqueTargets(discoveredTargets) }
        let total = max(targets.count, 1)
        progress(
            CleanScanProgress(
                fraction: 0.05,
                currentPath: "Sizing \(targets.count) targets…",
                itemsFound: 0,
                bytesFound: 0
            )
        )

        let collected: [CleanItem] = try await withThrowingTaskGroup(of: CleanItem?.self) { group in
            var iterator = targets.makeIterator()
            var inFlight = 0
            let maxConcurrent = 6
            var done = 0
            var items: [CleanItem] = []
            var bytesFound: Int64 = 0
            items.reserveCapacity(min(targets.count, 256))

            func enqueueNext() {
                while inFlight < maxConcurrent, let target = iterator.next() {
                    inFlight += 1
                    group.addTask {
                        try await Self.measure(target: target)
                    }
                }
            }

            enqueueNext()

            for try await result in group {
                inFlight -= 1
                done += 1
                try Task.checkCancellation()

                if let result {
                    items.append(result)
                    bytesFound += result.byteCount
                }

                progress(
                    CleanScanProgress(
                        fraction: min(1, Double(done) / Double(total)),
                        currentPath: result?.name ?? "Scanning…",
                        itemsFound: items.count,
                        bytesFound: bytesFound
                    )
                )
                enqueueNext()
            }

            return items
        }

        try Task.checkCancellation()

        let categories = Self.group(items: collected)
        progress(
            CleanScanProgress(
                fraction: 1,
                currentPath: "Done",
                itemsFound: collected.count,
                bytesFound: collected.reduce(0) { $0 + $1.byteCount }
            )
        )

        return CleanScanResult(
            categories: categories,
            scannedAt: Date(),
            duration: Date().timeIntervalSince(started),
            coverageIssues: coverageIssues
        )
    }

    private static func measure(target: CleanTarget) async throws -> CleanItem? {
        try Task.checkCancellation()
        let eligible = try await BlockingIO.run { _ in
            FileManager.default.fileExists(atPath: target.path)
                && !PathSafety.isProtected(target.path)
                && !PathSafety.shouldSkipForSizing(target.path)
        }
        guard eligible else { return nil }

        let sized: SizeMeasurement
        do { sized = try await DirectorySizer.measure(URL(fileURLWithPath: target.path)) }
        catch is CancellationError { throw CancellationError() }
        catch { sized = SizeMeasurement(status: .unavailable, issues: [OperationIssue(path: target.path, message: error.localizedDescription)], totalIssueCount: 1) }
        let classification = target.safetyOverride.flatMap { safety in target.reasonOverride.map { (safety, $0) } }
            ?? PathSafety.classifyCachePath(target.path)
        let owner = ownerBundleID(for: target.path)
        let coverage = sized.status == .complete ? "" : " Size \(sized.status.rawValue). \(sized.issues.first?.message ?? "")"
        return CleanItem(name: target.name, path: target.path, categoryID: target.categoryID,
                         categoryName: target.categoryName, byteCount: sized.bytes,
                         safety: sized.status == .unavailable ? .protected : classification.0,
                         reason: classification.1 + coverage, modified: sized.modified,
                         completeness: sized.status, ownerBundleID: owner)
    }

    static func ownerBundleID(for path: String) -> String? {
        if let rule = AIStorageCatalog.cacheRule(for: path) { return rule.ownerBundleID }
        let name = URL(fileURLWithPath: path).lastPathComponent
        if name.hasPrefix("com.") || name.hasPrefix("org.") { return name }
        let owners = ["Chrome": "com.google.Chrome", "Firefox": "org.mozilla.firefox", "Cursor": "com.todesktop.230313mzl4w4u92",
                      "Claude": "com.anthropic.claudefordesktop", "Code": "com.microsoft.VSCode", "BraveSoftware": "com.brave.Browser"]
        return owners.first { path.split(separator: "/").contains(Substring($0.key)) }?.value
    }

    /// Groups items by category and sorts them.
    /// Categories are sorted by total size (biggest first), and items inside are sorted by size (biggest first).
    /// This ensures that the largest clutter is prioritized and shown on top.
    private static func group(items: [CleanItem]) -> [CleanCategory] {
        var buckets: [String: [CleanItem]] = [:]
        var meta: [String: (name: String, image: String)] = [:]

        // Distribute scan items into their respective category buckets
        for item in items {
            buckets[item.categoryID, default: []].append(item)
            if meta[item.categoryID] == nil {
                meta[item.categoryID] = (item.categoryName, icon(for: item.categoryID))
            }
        }

        // Map buckets to CleanCategory models, sorting items inside each bucket by size (biggest first)
        let unsortedCategories = buckets.keys.compactMap { id -> CleanCategory? in
            guard var catItems = buckets[id], !catItems.isEmpty else { return nil }
            // Sort items inside this category purely by size descending (biggest first)
            catItems.sort { $0.byteCount > $1.byteCount }
            let m = meta[id] ?? (id, icon(for: id))
            return CleanCategory(id: id, name: m.name, systemImage: m.image, items: catItems)
        }

        // Sort categories by their total size (biggest first) to prioritize large space reclaim targets
        return unsortedCategories.sorted { $0.totalBytes > $1.totalBytes }
    }

    private static func icon(for categoryID: String) -> String {
        switch categoryID {
        case "user-caches": "internaldrive"
        case "browsers": "globe"
        case "logs": "doc.text"
        case "developer": "hammer"
        case "package-managers": "shippingbox"
        case "ai-agents": "cpu"
        case "local-ai": "brain"
        case "project-artifacts": "shippingbox.and.arrow.backward"
        case "ide": "chevron.left.forwardslash.chevron.right"
        case "trash": "trash"
        default: "folder"
        }
    }

    static func uniqueTargets(_ targets: [CleanTarget]) -> [CleanTarget] {
        let exclusions = ScanPreferences.excludedPaths.map { PathSafety.canonicalPath($0).lowercased() }
        var byPath: [String: CleanTarget] = [:]
        for target in targets {
            let path = PathSafety.canonicalPath(target.path)
            guard !exclusions.contains(where: { path.lowercased() == $0 || PathSafety.isDescendant(path, of: $0) }) else { continue }
            if byPath[path] == nil || target.safetyOverride != nil { byPath[path] = target }
        }
        // Keep specific leaves instead of overlapping broad parents. Normalize
        // once per target and walk its ancestors, avoiding all-pairs filesystem calls.
        let paths = Set(byPath.keys.map { $0.lowercased() })
        var parents = Set<String>()
        for path in paths {
            var ancestor = (path as NSString).deletingLastPathComponent
            while !ancestor.isEmpty {
                if paths.contains(ancestor) { parents.insert(ancestor) }
                if ancestor == "/" { break }
                ancestor = (ancestor as NSString).deletingLastPathComponent
            }
        }
        return byPath.keys.sorted().compactMap { parents.contains($0.lowercased()) ? nil : byPath[$0] }
    }

    static func buildTargets(home: String = NSHomeDirectory()) -> [CleanTarget] {
        uniqueTargets((try? discoverTargets(home: home))?.targets ?? [])
    }

    struct TargetDiscovery: Sendable {
        let targets: [CleanTarget]
        let issues: [OperationIssue]
    }

    /// Stream immediate children once, with one discovery budget for all roots.
    static func discoverTargets(home: String = NSHomeDirectory(), maxEntries: Int = 10_000,
                                deadline: TimeInterval = 10,
                                shouldCancel: @Sendable () -> Bool = { false }) throws -> TargetDiscovery {
        if shouldCancel() { throw CancellationError() }
        var targets = CleanTargetCatalog.targets(home: home)
        var issues: [OperationIssue] = []
        let roots = [("Library/Caches", "user-caches", "User Caches"),
                     ("Library/Logs", "logs", "Logs"),
                     ("Library/Caches/Google", "ide", "Editors & IDEs")]
        var visited = 0
        let start = ContinuousClock.now
        for (suffix, category, title) in roots {
            let root = URL(fileURLWithPath: home).appendingPathComponent(suffix)
            if shouldCancel() { throw CancellationError() }
            guard !PathSafety.hasUnsafeSymlink(root.path), !ScanPreferences.isExcluded(root.path) else {
                issues.append(OperationIssue(path: root.path, message: "Excluded or redirected discovery location."))
                continue
            }
            do { _ = try FileIdentity.read(root.path) }
            catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT) { continue }
            catch { issues.append(OperationIssue(path: root.path, message: error.localizedDescription)); continue }
            guard let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles], errorHandler: { path, error in
                    if issues.count < 50 { issues.append(OperationIssue(path: path.path, message: error.localizedDescription)) }
                    return true
                }) else { continue }
            while true {
                if shouldCancel() { throw CancellationError() }
                guard visited < maxEntries, start.duration(to: .now) < .seconds(deadline) else {
                    issues.append(OperationIssue(path: root.path, message: "Discovery limit reached; some cleanup locations were not inspected."))
                    return TargetDiscovery(targets: targets, issues: issues)
                }
                guard let child = autoreleasepool(invoking: { iterator.nextObject() as? URL }) else { break }
                visited += 1
                let name = child.lastPathComponent
                if category == "ide", !name.lowercased().contains("android") { continue }
                targets.append(CleanTarget(categoryID: category, categoryName: title,
                    systemImage: icon(for: category), name: name, path: child.path,
                    safetyOverride: category == "user-caches" ? nil : .review,
                    reasonOverride: category == "logs" ? "Review diagnostics and log history before removal"
                        : category == "ide" ? "Android Studio system and build cache" : nil))
            }
        }
        return TargetDiscovery(targets: targets, issues: issues)
    }
}
