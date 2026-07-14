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
    private let cancelFlag = CancelFlag()

    func cancel() {
        cancelFlag.cancel()
    }

    func reset() {
        cancelFlag.reset()
    }

    func scan(
        progress: @Sendable @escaping (CleanScanProgress) -> Void
    ) async throws -> CleanScanResult {
        cancelFlag.reset()
        let started = Date()
        let targets = Self.buildTargets()
        let total = max(targets.count, 1)
        let flag = cancelFlag

        progress(
            CleanScanProgress(
                fraction: 0,
                currentPath: "Preparing \(targets.count) targets…",
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
            items.reserveCapacity(min(targets.count, 256))

            func enqueueNext() {
                while inFlight < maxConcurrent, let target = iterator.next() {
                    inFlight += 1
                    group.addTask {
                        try await Self.measure(target: target, flag: flag)
                    }
                }
            }

            enqueueNext()

            for try await result in group {
                inFlight -= 1
                done += 1
                if flag.isCancelled { throw CancellationError() }

                if let result {
                    items.append(result)
                }

                let bytesFound = items.reduce(Int64(0)) { $0 + $1.byteCount }
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

        if flag.isCancelled { throw CancellationError() }

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
            duration: Date().timeIntervalSince(started)
        )
    }

    private static func measure(target: CleanTarget, flag: CancelFlag) async throws -> CleanItem? {
        if flag.isCancelled { throw CancellationError() }
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        if PathSafety.isProtected(target.path) { return nil }
        if PathSafety.shouldSkipForSizing(target.path) { return nil }

        do {
            let sized = try DirectorySizer.size(
                of: URL(fileURLWithPath: target.path),
                shouldCancel: { flag.isCancelled }
            )
            guard sized.bytes > 0 else { return nil }

            let classification: (SafetyLabel, String)
            if let s = target.safetyOverride, let r = target.reasonOverride {
                classification = (s, r)
            } else {
                classification = PathSafety.classifyCachePath(target.path)
            }
            guard classification.0 != .protected else { return nil }

            return CleanItem(
                name: target.name,
                path: target.path,
                categoryID: target.categoryID,
                categoryName: target.categoryName,
                byteCount: sized.bytes,
                safety: classification.0,
                reason: classification.1,
                modified: sized.modified
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    /// Groups items by category — safe with many items sharing the same category id.
    private static func group(items: [CleanItem]) -> [CleanCategory] {
        let preferredOrder = [
            "user-caches", "browsers", "logs", "developer",
            "package-managers", "local-ai", "trash"
        ]

        var buckets: [String: [CleanItem]] = [:]
        var meta: [String: (name: String, image: String)] = [:]

        for item in items {
            buckets[item.categoryID, default: []].append(item)
            if meta[item.categoryID] == nil {
                meta[item.categoryID] = (item.categoryName, icon(for: item.categoryID))
            }
        }

        var orderedIDs = preferredOrder.filter { buckets[$0] != nil }
        for id in buckets.keys where !orderedIDs.contains(id) {
            orderedIDs.append(id)
        }

        return orderedIDs.compactMap { id in
            guard var catItems = buckets[id], !catItems.isEmpty else { return nil }
            catItems.sort {
                if $0.safety != $1.safety { return $0.safety < $1.safety }
                return $0.byteCount > $1.byteCount
            }
            let m = meta[id] ?? (id, "folder")
            return CleanCategory(id: id, name: m.name, systemImage: m.image, items: catItems)
        }
    }

    private static func icon(for categoryID: String) -> String {
        switch categoryID {
        case "user-caches": "internaldrive"
        case "browsers": "globe"
        case "logs": "doc.text"
        case "developer": "hammer"
        case "package-managers": "shippingbox"
        case "local-ai": "brain"
        case "trash": "trash"
        default: "folder"
        }
    }

    static func buildTargets() -> [CleanTarget] {
        let home = NSHomeDirectory()
        let lib = (home as NSString).appendingPathComponent("Library")
        var list: [CleanTarget] = []

        func add(
            _ categoryID: String,
            _ categoryName: String,
            _ image: String,
            _ name: String,
            _ path: String,
            safety: SafetyLabel? = nil,
            reason: String? = nil
        ) {
            list.append(
                CleanTarget(
                    categoryID: categoryID,
                    categoryName: categoryName,
                    systemImage: image,
                    name: name,
                    path: path,
                    safetyOverride: safety,
                    reasonOverride: reason
                )
            )
        }

        let userCaches = (lib as NSString).appendingPathComponent("Caches")
        if let children = try? FileManager.default.contentsOfDirectory(atPath: userCaches) {
            for name in children.sorted() where !name.hasPrefix(".") {
                add(
                    "user-caches", "User Caches", "internaldrive", name,
                    (userCaches as NSString).appendingPathComponent(name)
                )
            }
        }

        let logs = (lib as NSString).appendingPathComponent("Logs")
        if let children = try? FileManager.default.contentsOfDirectory(atPath: logs) {
            for name in children.sorted() where !name.hasPrefix(".") {
                add(
                    "logs", "Logs", "doc.text", name,
                    (logs as NSString).appendingPathComponent(name),
                    safety: .safe,
                    reason: "Log files — safe to remove"
                )
            }
        }

        let browsers: [(String, String)] = [
            ("Safari", (lib as NSString).appendingPathComponent("Caches/com.apple.Safari")),
            ("Chrome", (home as NSString).appendingPathComponent("Library/Caches/Google/Chrome")),
            ("Firefox", (home as NSString).appendingPathComponent("Library/Caches/Firefox")),
            ("Arc", (home as NSString).appendingPathComponent("Library/Caches/Company.TheBrowserCompany.Arc")),
            ("Arc (legacy)", (home as NSString).appendingPathComponent("Library/Caches/Arc")),
            ("Edge", (home as NSString).appendingPathComponent("Library/Caches/com.microsoft.edgemac")),
            ("Brave", (home as NSString).appendingPathComponent("Library/Caches/BraveSoftware"))
        ]
        for (name, path) in browsers {
            add(
                "browsers", "Browsers", "globe", name, path,
                safety: .safe,
                reason: "Browser cache — recreated automatically"
            )
        }

        add(
            "developer", "Developer", "hammer", "Xcode DerivedData",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            safety: .review,
            reason: "Build intermediates — recreated on next compile"
        )
        add(
            "developer", "Developer", "hammer", "Xcode Archives",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/Archives"),
            safety: .caution,
            reason: "May contain archived builds you want to keep"
        )
        add(
            "developer", "Developer", "hammer", "iOS DeviceSupport",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            safety: .review,
            reason: "Device symbols — re-downloaded when needed"
        )
        add(
            "developer", "Developer", "hammer", "Simulator Caches",
            (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            safety: .safe,
            reason: "Simulator caches — regenerable"
        )

        add(
            "package-managers", "Package Managers", "shippingbox", "Homebrew Cache",
            (home as NSString).appendingPathComponent("Library/Caches/Homebrew"),
            safety: .safe, reason: "Homebrew download cache"
        )
        add(
            "package-managers", "Package Managers", "shippingbox", "npm Cache",
            (home as NSString).appendingPathComponent(".npm/_cacache"),
            safety: .safe, reason: "npm package cache"
        )
        add(
            "package-managers", "Package Managers", "shippingbox", "pip Cache",
            (home as NSString).appendingPathComponent("Library/Caches/pip"),
            safety: .safe, reason: "Python pip cache"
        )

        add(
            "local-ai", "Local AI", "brain", "Ollama Models",
            (home as NSString).appendingPathComponent(".ollama/models"),
            safety: .caution,
            reason: "Local LLM weights — large re-download if removed"
        )
        add(
            "local-ai", "Local AI", "brain", "LM Studio",
            (home as NSString).appendingPathComponent(".lmstudio"),
            safety: .caution,
            reason: "LM Studio data and models"
        )

        add(
            "logs", "Logs", "doc.text", "Diagnostic Reports",
            (lib as NSString).appendingPathComponent("Logs/DiagnosticReports"),
            safety: .safe, reason: "Crash and diagnostic reports"
        )

        add(
            "trash", "Trash", "trash", "User Trash",
            (home as NSString).appendingPathComponent(".Trash"),
            safety: .review,
            reason: "Already in Trash — empty from Finder when ready"
        )

        return list
    }
}
