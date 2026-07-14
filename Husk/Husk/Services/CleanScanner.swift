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
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func reset() {
        cancelled = false
    }

    func scan(
        progress: @Sendable @escaping (CleanScanProgress) -> Void
    ) async throws -> CleanScanResult {
        cancelled = false
        let started = Date()
        let targets = Self.buildTargets()
        var collected: [CleanItem] = []
        collected.reserveCapacity(targets.count)

        let total = max(targets.count, 1)

        for (index, target) in targets.enumerated() {
            try checkCancel()

            progress(
                CleanScanProgress(
                    fraction: Double(index) / Double(total),
                    currentPath: target.path,
                    itemsFound: collected.count,
                    bytesFound: collected.reduce(0) { $0 + $1.byteCount }
                )
            )

            let url = URL(fileURLWithPath: target.path)
            guard FileManager.default.fileExists(atPath: target.path) else { continue }

            if PathSafety.isProtected(target.path) { continue }

            do {
                let sized = try DirectorySizer.size(of: url) { [cancelled] in
                    cancelled
                }
                guard sized.bytes > 0 else { continue }

                let classification: (SafetyLabel, String)
                if let s = target.safetyOverride, let r = target.reasonOverride {
                    classification = (s, r)
                } else {
                    classification = PathSafety.classifyCachePath(target.path)
                }

                guard classification.0 != .protected else { continue }

                let item = CleanItem(
                    name: target.name,
                    path: target.path,
                    categoryID: target.categoryID,
                    categoryName: target.categoryName,
                    byteCount: sized.bytes,
                    safety: classification.0,
                    reason: classification.1,
                    modified: sized.modified
                )
                collected.append(item)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Skip unreadable targets (permissions) without failing the whole scan
                continue
            }
        }

        try checkCancel()

        progress(
            CleanScanProgress(
                fraction: 1,
                currentPath: "Done",
                itemsFound: collected.count,
                bytesFound: collected.reduce(0) { $0 + $1.byteCount }
            )
        )

        let categories = Self.group(items: collected, targets: targets)
        return CleanScanResult(
            categories: categories,
            scannedAt: Date(),
            duration: Date().timeIntervalSince(started)
        )
    }

    private func checkCancel() throws {
        if cancelled { throw CancellationError() }
    }

    private static func group(items: [CleanItem], targets: [CleanTarget]) -> [CleanCategory] {
        let order = targets.map(\.categoryID)
        var uniqueOrder: [String] = []
        var seen = Set<String>()
        for id in order where !seen.contains(id) {
            seen.insert(id)
            uniqueOrder.append(id)
        }

        let meta: [String: (name: String, image: String)] = Dictionary(
            uniqueKeysWithValues: targets.map { ($0.categoryID, ($0.categoryName, $0.systemImage)) }
        )

        return uniqueOrder.compactMap { id in
            let catItems = items
                .filter { $0.categoryID == id }
                .sorted {
                    if $0.safety != $1.safety { return $0.safety < $1.safety }
                    return $0.byteCount > $1.byteCount
                }
            guard !catItems.isEmpty else { return nil }
            let m = meta[id] ?? (id, "folder")
            return CleanCategory(id: id, name: m.name, systemImage: m.image, items: catItems)
        }
    }

    static func buildTargets() -> [CleanTarget] {
        let home = NSHomeDirectory()
        let lib = (home as NSString).appendingPathComponent("Library")
        var list: [CleanTarget] = []

        // User caches — enumerate top-level entries for transparency
        let userCaches = (lib as NSString).appendingPathComponent("Caches")
        if let children = try? FileManager.default.contentsOfDirectory(atPath: userCaches) {
            for name in children.sorted() {
                if name.hasPrefix(".") { continue }
                let path = (userCaches as NSString).appendingPathComponent(name)
                list.append(
                    CleanTarget(
                        categoryID: "user-caches",
                        categoryName: "User Caches",
                        systemImage: "internaldrive",
                        name: name,
                        path: path,
                        safetyOverride: nil,
                        reasonOverride: nil
                    )
                )
            }
        }

        // Logs
        let logs = (lib as NSString).appendingPathComponent("Logs")
        if let children = try? FileManager.default.contentsOfDirectory(atPath: logs) {
            for name in children.sorted() {
                if name.hasPrefix(".") { continue }
                let path = (logs as NSString).appendingPathComponent(name)
                list.append(
                    CleanTarget(
                        categoryID: "logs",
                        categoryName: "Logs",
                        systemImage: "doc.text",
                        name: name,
                        path: path,
                        safetyOverride: .safe,
                        reasonOverride: "Log files — safe to remove"
                    )
                )
            }
        }

        // Browsers
        let browserPaths: [(String, String)] = [
            ("Safari", (lib as NSString).appendingPathComponent("Caches/com.apple.Safari")),
            ("Chrome", (home as NSString).appendingPathComponent("Library/Caches/Google/Chrome")),
            ("Firefox", (home as NSString).appendingPathComponent("Library/Caches/Firefox")),
            ("Arc", (home as NSString).appendingPathComponent("Library/Caches/Arc")),
            ("Edge", (home as NSString).appendingPathComponent("Library/Caches/com.microsoft.edgemac")),
            ("Brave", (home as NSString).appendingPathComponent("Library/Caches/BraveSoftware"))
        ]
        for (name, path) in browserPaths {
            list.append(
                CleanTarget(
                    categoryID: "browsers",
                    categoryName: "Browsers",
                    systemImage: "globe",
                    name: name,
                    path: path,
                    safetyOverride: .safe,
                    reasonOverride: "Browser cache — recreated automatically"
                )
            )
        }

        // Developer
        let derived = (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData")
        list.append(
            CleanTarget(
                categoryID: "developer",
                categoryName: "Developer",
                systemImage: "hammer",
                name: "Xcode DerivedData",
                path: derived,
                safetyOverride: .review,
                reasonOverride: "Build intermediates — recreated on next compile"
            )
        )

        let archives = (home as NSString).appendingPathComponent("Library/Developer/Xcode/Archives")
        list.append(
            CleanTarget(
                categoryID: "developer",
                categoryName: "Developer",
                systemImage: "hammer",
                name: "Xcode Archives",
                path: archives,
                safetyOverride: .caution,
                reasonOverride: "May contain archived builds you want to keep"
            )
        )

        let iosSupport = (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")
        list.append(
            CleanTarget(
                categoryID: "developer",
                categoryName: "Developer",
                systemImage: "hammer",
                name: "iOS DeviceSupport",
                path: iosSupport,
                safetyOverride: .review,
                reasonOverride: "Device symbols — re-downloaded when needed"
            )
        )

        let simCore = (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches")
        list.append(
            CleanTarget(
                categoryID: "developer",
                categoryName: "Developer",
                systemImage: "hammer",
                name: "Simulator Caches",
                path: simCore,
                safetyOverride: .safe,
                reasonOverride: "Simulator caches — regenerable"
            )
        )

        // Package manager caches
        let brew = (home as NSString).appendingPathComponent("Library/Caches/Homebrew")
        list.append(
            CleanTarget(
                categoryID: "package-managers",
                categoryName: "Package Managers",
                systemImage: "shippingbox",
                name: "Homebrew Cache",
                path: brew,
                safetyOverride: .safe,
                reasonOverride: "Homebrew download cache"
            )
        )

        let npm = (home as NSString).appendingPathComponent(".npm/_cacache")
        list.append(
            CleanTarget(
                categoryID: "package-managers",
                categoryName: "Package Managers",
                systemImage: "shippingbox",
                name: "npm Cache",
                path: npm,
                safetyOverride: .safe,
                reasonOverride: "npm package cache"
            )
        )

        let pip = (home as NSString).appendingPathComponent("Library/Caches/pip")
        list.append(
            CleanTarget(
                categoryID: "package-managers",
                categoryName: "Package Managers",
                systemImage: "shippingbox",
                name: "pip Cache",
                path: pip,
                safetyOverride: .safe,
                reasonOverride: "Python pip cache"
            )
        )

        // Local AI
        let ollama = (home as NSString).appendingPathComponent(".ollama/models")
        list.append(
            CleanTarget(
                categoryID: "local-ai",
                categoryName: "Local AI",
                systemImage: "brain",
                name: "Ollama Models",
                path: ollama,
                safetyOverride: .caution,
                reasonOverride: "Local LLM weights — large re-download if removed"
            )
        )

        let lmstudio = (home as NSString).appendingPathComponent(".lmstudio")
        list.append(
            CleanTarget(
                categoryID: "local-ai",
                categoryName: "Local AI",
                systemImage: "brain",
                name: "LM Studio",
                path: lmstudio,
                safetyOverride: .caution,
                reasonOverride: "LM Studio data and models"
            )
        )

        // System user diagnostics
        let diag = (lib as NSString).appendingPathComponent("Logs/DiagnosticReports")
        list.append(
            CleanTarget(
                categoryID: "logs",
                categoryName: "Logs",
                systemImage: "doc.text",
                name: "Diagnostic Reports",
                path: diag,
                safetyOverride: .safe,
                reasonOverride: "Crash and diagnostic reports"
            )
        )

        // Trash preview
        let trash = (home as NSString).appendingPathComponent(".Trash")
        list.append(
            CleanTarget(
                categoryID: "trash",
                categoryName: "Trash",
                systemImage: "trash",
                name: "User Trash",
                path: trash,
                safetyOverride: .review,
                reasonOverride: "Already in Trash — empty from Finder when ready"
            )
        )

        return list
    }
}
