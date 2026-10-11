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

        let discovery = try await BlockingIO.run { _ in
            var issues: [OperationIssue] = []
            for path in [NSHomeDirectory() + "/Library/Caches", NSHomeDirectory() + "/Library/Logs"] {
                do { _ = try FileManager.default.contentsOfDirectory(atPath: path) }
                catch { issues.append(OperationIssue(path: path, message: error.localizedDescription)) }
            }
            return (Self.buildTargets(), issues)
        }
        var targets = discovery.0
        var coverageIssues = discovery.1

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

        targets = Self.uniqueTargets(targets)
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
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        if PathSafety.isProtected(target.path) { return nil }
        if PathSafety.shouldSkipForSizing(target.path) { return nil }

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
        var byPath: [String: CleanTarget] = [:]
        for target in targets where !ScanPreferences.isExcluded(target.path) {
            let path = PathSafety.canonicalPath(target.path)
            if byPath[path] == nil || target.safetyOverride != nil { byPath[path] = target }
        }
        let sorted = byPath.values.sorted { $0.path < $1.path }
        return sorted.filter { candidate in
            !sorted.contains { other in
                other.path != candidate.path && PathSafety.isDescendant(PathSafety.canonicalPath(other.path), of: PathSafety.canonicalPath(candidate.path))
            }
        }
    }

    static func buildTargets(home: String = NSHomeDirectory()) -> [CleanTarget] {
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
                    safety: .review,
                    reason: "Review diagnostics and log history before removal"
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
            safety: .review, reason: "pnpm content-addressable store")
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

        add("package-managers", "Package Managers", "shippingbox", "Pub Cache",
            (home as NSString).appendingPathComponent(".pub-cache"),
            safety: .review, reason: "Flutter/Dart dependency cache")
        add("package-managers", "Package Managers", "shippingbox", "Deno Cache",
            (home as NSString).appendingPathComponent("Library/Caches/deno"),
            safety: .safe, reason: "Deno modules and compiler cache")
        add("package-managers", "Package Managers", "shippingbox", "Swift PM Cache",
            (home as NSString).appendingPathComponent("Library/Caches/org.swift.swiftpm"),
            safety: .safe, reason: "Swift Package Manager repositories cache")
        add("package-managers", "Package Managers", "shippingbox", "Cypress Cache",
            (home as NSString).appendingPathComponent("Library/Caches/Cypress"),
            safety: .review, reason: "Cypress binary installations")
        add("package-managers", "Package Managers", "shippingbox", "Cargo Registry Index",
            (home as NSString).appendingPathComponent(".cargo/registry/index"),
            safety: .safe, reason: "Rust crate registry index")
        add("package-managers", "Package Managers", "shippingbox", "Cargo Git DB",
            (home as NSString).appendingPathComponent(".cargo/git/db"),
            safety: .review, reason: "Rust git dependencies database")
        add("package-managers", "Package Managers", "shippingbox", "Poetry Cache",
            (home as NSString).appendingPathComponent("Library/Caches/pypoetry"),
            safety: .review, reason: "Poetry virtual environments and package cache")
        add("package-managers", "Package Managers", "shippingbox", "pip Cache (Home)",
            (home as NSString).appendingPathComponent(".cache/pip"),
            safety: .safe, reason: "Python pip download cache")

        let support = (lib as NSString).appendingPathComponent("Application Support")
        // Shared explicit AI rules; sessions, models, versions and worktrees never become cache targets.
        for rule in AIStorageCatalog.rules where rule.removable {
            add("ai-agents", "AI Caches", "cpu", rule.tool + " · " + (rule.relativePath as NSString).lastPathComponent,
                rule.path(home: home), safety: .review, reason: rule.detail)
        }

        add("ai-agents", "AI Agents", "cpu", "Ollama App Cache",
            (home as NSString).appendingPathComponent("Library/Caches/com.electron.ollama"),
            safety: .safe, reason: "Ollama Desktop client cache")
        add("ai-agents", "AI Agents", "cpu", "LM Studio App Cache",
            (home as NSString).appendingPathComponent("Library/Caches/lm-studio"),
            safety: .safe, reason: "LM Studio Desktop client cache")





        // Local AI models





        // IDEs & Editor system caches (keep user preferences and configurations intact)
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
            safety: .review, reason: "JetBrains IDE logs")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Xcode cache",
            (home as NSString).appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            safety: .safe, reason: "Xcode app cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "JetBrains Caches",
            (home as NSString).appendingPathComponent("Library/Caches/JetBrains"),
            safety: .review, reason: "IntelliJ, PyCharm, WebStorm, CLion cache and indexing data")

        // Dynamically discover installed Android Studio version caches
        let googleCaches = (home as NSString).appendingPathComponent("Library/Caches/Google")
        if let children = try? FileManager.default.contentsOfDirectory(atPath: googleCaches) {
            for name in children where name.lowercased().contains("android") {
                add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Android Studio (\(name))",
                    (googleCaches as NSString).appendingPathComponent(name),
                    safety: .review, reason: "Android Studio system and build cache")
            }
        }

        // Heavy virtualization/container developer environments

        add(
            "logs", "Logs", "doc.text", "Diagnostic Reports",
            (lib as NSString).appendingPathComponent("Logs/DiagnosticReports"),
            safety: .review, reason: "Crash and diagnostic reports"
        )


        return uniqueTargets(list)
    }
}
