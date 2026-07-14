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
        let flag = cancelFlag

        progress(
            CleanScanProgress(
                fraction: 0,
                currentPath: "Preparing targets…",
                itemsFound: 0,
                bytesFound: 0
            )
        )

        var targets = Self.buildTargets()

        // Mole-style project purge discovery (node_modules, target, .next, …)
        progress(
            CleanScanProgress(
                fraction: 0.02,
                currentPath: "Finding project artifacts…",
                itemsFound: 0,
                bytesFound: 0
            )
        )
        let artifacts = ProjectArtifactService.discover(maxDepth: 4, maxHits: 60) {
            flag.isCancelled
        }
        if flag.isCancelled { throw CancellationError() }
        for a in artifacts {
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

            // Cheap top-level inventory for the detail pane (not a full recursive count).
            let entryCount = try? FileManager.default.contentsOfDirectory(atPath: target.path).count

            return CleanItem(
                name: target.name,
                path: target.path,
                categoryID: target.categoryID,
                categoryName: target.categoryName,
                byteCount: sized.bytes,
                safety: classification.0,
                reason: classification.1,
                modified: sized.modified,
                entryCount: entryCount
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
            "package-managers", "ai-agents", "local-ai",
            "project-artifacts", "ide", "trash"
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
        case "ai-agents": "cpu"
        case "local-ai": "brain"
        case "project-artifacts": "shippingbox.and.arrow.backward"
        case "ide": "chevron.left.forwardslash.chevron.right"
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

        // Package managers (Mole-aligned)
        add("package-managers", "Package Managers", "shippingbox", "Homebrew Cache",
            (home as NSString).appendingPathComponent("Library/Caches/Homebrew"),
            safety: .safe, reason: "Homebrew download cache")
        add("package-managers", "Package Managers", "shippingbox", "npm _cacache",
            (home as NSString).appendingPathComponent(".npm/_cacache"),
            safety: .safe, reason: "npm package cache")
        add("package-managers", "Package Managers", "shippingbox", "npm _npx",
            (home as NSString).appendingPathComponent(".npm/_npx"),
            safety: .safe, reason: "npx temporary package cache")
        add("package-managers", "Package Managers", "shippingbox", "pnpm store",
            (home as NSString).appendingPathComponent("Library/pnpm/store"),
            safety: .safe, reason: "pnpm content-addressable store")
        add("package-managers", "Package Managers", "shippingbox", "Yarn cache",
            (home as NSString).appendingPathComponent("Library/Caches/Yarn"),
            safety: .safe, reason: "Yarn package cache")
        add("package-managers", "Package Managers", "shippingbox", "Bun install cache",
            (home as NSString).appendingPathComponent(".bun/install/cache"),
            safety: .safe, reason: "Bun package install cache")
        add("package-managers", "Package Managers", "shippingbox", "pip Cache",
            (home as NSString).appendingPathComponent("Library/Caches/pip"),
            safety: .safe, reason: "Python pip cache")
        add("package-managers", "Package Managers", "shippingbox", "uv cache",
            (home as NSString).appendingPathComponent(".cache/uv"),
            safety: .safe, reason: "uv Python package cache")
        add("package-managers", "Package Managers", "shippingbox", "Cargo registry cache",
            (home as NSString).appendingPathComponent(".cargo/registry/cache"),
            safety: .safe, reason: "Rust crate download cache")
        add("package-managers", "Package Managers", "shippingbox", "Go build cache",
            (home as NSString).appendingPathComponent("Library/Caches/go-build"),
            safety: .safe, reason: "Go compiler cache")
        add("package-managers", "Package Managers", "shippingbox", "Gradle caches",
            (home as NSString).appendingPathComponent(".gradle/caches"),
            safety: .review, reason: "Gradle dependency caches")
        add("package-managers", "Package Managers", "shippingbox", "CocoaPods cache",
            (home as NSString).appendingPathComponent("Library/Caches/CocoaPods"),
            safety: .safe, reason: "CocoaPods download cache")
        add("package-managers", "Package Managers", "shippingbox", "Turbo cache",
            (home as NSString).appendingPathComponent(".turbo/cache"),
            safety: .safe, reason: "Turborepo remote/local cache")
        add("package-managers", "Package Managers", "shippingbox", "Vite cache",
            (home as NSString).appendingPathComponent(".cache/vite"),
            safety: .safe, reason: "Vite bundler cache")
        add("package-managers", "Package Managers", "shippingbox", "Webpack cache",
            (home as NSString).appendingPathComponent(".cache/webpack"),
            safety: .safe, reason: "Webpack cache")
        add("package-managers", "Package Managers", "shippingbox", "Hugging Face cache",
            (home as NSString).appendingPathComponent(".cache/huggingface"),
            safety: .caution, reason: "ML model/dataset downloads — large re-download")

        // AI coding agents & IDEs (Mole-inspired; caches only — preserve sessions/auth)
        let support = (lib as NSString).appendingPathComponent("Application Support")
        add("ai-agents", "AI Agents", "cpu", "Claude Code app cache",
            (support as NSString).appendingPathComponent("Claude/Cache"),
            safety: .safe, reason: "Claude Desktop web/app cache — sessions preserved elsewhere")
        add("ai-agents", "AI Agents", "cpu", "Claude Code GPU cache",
            (support as NSString).appendingPathComponent("Claude/GPUCache"),
            safety: .safe, reason: "Claude Desktop GPU cache")
        add("ai-agents", "AI Agents", "cpu", "Claude Code Code Cache",
            (support as NSString).appendingPathComponent("Claude/Code Cache"),
            safety: .safe, reason: "Claude Desktop Chromium code cache")
        add("ai-agents", "AI Agents", "cpu", "Cursor Cache",
            (support as NSString).appendingPathComponent("Cursor/Cache"),
            safety: .safe, reason: "Cursor editor Chromium cache")
        add("ai-agents", "AI Agents", "cpu", "Cursor CachedData",
            (support as NSString).appendingPathComponent("Cursor/CachedData"),
            safety: .safe, reason: "Cursor V8 cached data")
        add("ai-agents", "AI Agents", "cpu", "Cursor GPUCache",
            (support as NSString).appendingPathComponent("Cursor/GPUCache"),
            safety: .safe, reason: "Cursor GPU cache")
        add("ai-agents", "AI Agents", "cpu", "Cursor logs",
            (support as NSString).appendingPathComponent("Cursor/logs"),
            safety: .safe, reason: "Cursor application logs")
        add("ai-agents", "AI Agents", "cpu", "Cursor Agent versions",
            (home as NSString).appendingPathComponent(".local/share/cursor-agent/versions"),
            safety: .review, reason: "Old Cursor Agent CLI builds — keep latest")
        add("ai-agents", "AI Agents", "cpu", "Claude Code CLI versions",
            (home as NSString).appendingPathComponent(".local/share/claude/versions"),
            safety: .review, reason: "Old Claude Code CLI versions")
        add("ai-agents", "AI Agents", "cpu", "Codex CLI temp",
            (home as NSString).appendingPathComponent(".codex/.tmp"),
            safety: .safe, reason: "Codex temporary files (sessions/auth preserved)")
        add("ai-agents", "AI Agents", "cpu", "Codex CLI logs",
            (home as NSString).appendingPathComponent(".codex/log"),
            safety: .safe, reason: "Codex log files")
        add("ai-agents", "AI Agents", "cpu", "Gemini CLI temp",
            (home as NSString).appendingPathComponent(".gemini/tmp"),
            safety: .safe, reason: "Gemini CLI temp work files")
        add("ai-agents", "AI Agents", "cpu", "Antigravity browser cache",
            (home as NSString).appendingPathComponent(".gemini/antigravity-browser-profile/Default/Cache"),
            safety: .safe, reason: "Gemini Antigravity browser cache")
        add("ai-agents", "AI Agents", "cpu", "Continue.dev cache",
            (home as NSString).appendingPathComponent(".continue/index"),
            safety: .review, reason: "Continue.dev index/cache")
        add("ai-agents", "AI Agents", "cpu", "Aider cache",
            (home as NSString).appendingPathComponent(".aider"),
            safety: .review, reason: "Aider local cache/history — review first")

        // Local AI models
        add("local-ai", "Local AI Models", "brain", "Ollama models",
            (home as NSString).appendingPathComponent(".ollama/models"),
            safety: .caution, reason: "Local LLM weights — large re-download if removed")
        add("local-ai", "Local AI Models", "brain", "LM Studio",
            (home as NSString).appendingPathComponent(".lmstudio"),
            safety: .caution, reason: "LM Studio models and data")
        add("local-ai", "Local AI Models", "brain", "Hugging Face hub",
            (home as NSString).appendingPathComponent(".cache/huggingface/hub"),
            safety: .caution, reason: "Downloaded HF models")

        // IDEs
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "VS Code Cache",
            (support as NSString).appendingPathComponent("Code/Cache"),
            safety: .safe, reason: "VS Code Chromium cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "VS Code CachedData",
            (support as NSString).appendingPathComponent("Code/CachedData"),
            safety: .safe, reason: "VS Code cached extension data")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Zed cache",
            (home as NSString).appendingPathComponent("Library/Caches/Zed"),
            safety: .safe, reason: "Zed editor cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "JetBrains logs",
            (home as NSString).appendingPathComponent("Library/Logs/JetBrains"),
            safety: .safe, reason: "JetBrains IDE logs")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Xcode cache",
            (home as NSString).appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            safety: .safe, reason: "Xcode app cache")

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
