import AppKit
import CoreML
import SwiftUI
import Vision
import ScreenCaptureKit

@main struct UISmoke {
    @MainActor static func main() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        application.activate()
        UserDefaults.standard.setVolatileDomain(["husk.compactNavigation": true], forName: UserDefaults.argumentDomain)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let permissions = PermissionService()
        let screenFilter = ProcessInfo.processInfo.environment["HUSK_UI_SCREEN_FILTER"]
        if screenFilter != "welcome" { try await verifyResultTransitions(permissions: permissions, output: output) }
        if ProcessInfo.processInfo.environment["HUSK_UI_TRANSITIONS_ONLY"] == "1" { return }
        try await verifyOnboarding(permissions: permissions, output: output)
        if ProcessInfo.processInfo.environment["HUSK_UI_ONBOARDING_ONLY"] == "1" { return }
        let clean = CleanViewModel()
        let cache = CleanItem(name: "Xcode DerivedData", path: "/Users/demo/Library/Developer/Xcode/DerivedData", categoryID: "developer", categoryName: "Developer", byteCount: 2_340_000_000, safety: .review, reason: "Build intermediates. Recreated on the next compile.")
        let safe = CleanItem(name: "npm package cache", path: "/Users/demo/.npm/_cacache", categoryID: "package-managers", categoryName: "Package Managers", byteCount: 483_000_000, safety: .safe, reason: "Downloaded package cache.")
        clean.categories = [CleanCategory(id: "developer", name: "Developer", systemImage: "hammer", items: [cache, safe])]
        clean.phase = .ready
        clean.inspectedItem = cache
        let uninspectedClean = CleanViewModel()
        uninspectedClean.categories = clean.categories
        uninspectedClean.phase = .ready
        let ai = AIStorageViewModel()
        let rule = AIStorageCatalog.rules.first { $0.tool == "Codex" && $0.removable }!
        let session = AIStorageCatalog.rules.first { $0.tool == "Gemini" && $0.kind == .sessions }!
        let aiCache = AIStorageItem(rule: rule, path: "/Users/demo/" + rule.relativePath, measurement: SizeMeasurement(bytes: 231_000_000), blockedReason: nil)
        ai.report = AIStorageReport(items: [aiCache, AIStorageItem(rule: session, path: "/Users/demo/.gemini/tmp", measurement: SizeMeasurement(bytes: 77_000_000), blockedReason: "Inspection only. Contains saved chats.")], issues: [], scannedAt: Date())
        ai.inspectedID = aiCache.id
        let uninspectedAI = AIStorageViewModel()
        uninspectedAI.report = ai.report
        let sessionAI = AIStorageViewModel()
        sessionAI.report = ai.report
        sessionAI.kind = .sessions
        let worktreeAI = AIStorageViewModel()
        let worktreeRule = AIStorageCatalog.rules.first { $0.tool == "Codex" && $0.kind == .worktrees }!
        worktreeAI.report = AIStorageReport(items: [AIStorageItem(rule: worktreeRule, path: "/Users/demo/.codex/worktrees",
            measurement: SizeMeasurement(bytes: 1_230_000_000), blockedReason: "Inspection only")], issues: [], scannedAt: Date())
        worktreeAI.kind = .worktrees
        worktreeAI.worktrees = [GitWorktree(path: "/Users/demo/Projects/working-copy", branch: "refs/heads/example",
                                          locked: true, prunable: false, bare: false, status: "Contains changes or untracked files")]
        let analyze = AnalyzeViewModel()
        analyze.capacity = DiskCapacity(totalBytes: 500_000_000_000, availableBytes: 38_000_000_000)
        analyze.root = DiskNode(name: "Home", path: "/Users/demo", isDirectory: true, byteCount: 135_000_000_000, children: [
            DiskNode(name: "Desktop", path: "/Users/demo/Desktop", isDirectory: true, byteCount: 41_000_000_000, children: [
                DiskNode(name: "atlas", path: "/Users/demo/Desktop/atlas", isDirectory: true, byteCount: 16_000_000_000),
                DiskNode(name: "pebble", path: "/Users/demo/Desktop/pebble", isDirectory: true, byteCount: 8_000_000_000),
                DiskNode(name: "orbit", path: "/Users/demo/Desktop/orbit", isDirectory: true, byteCount: 7_000_000_000)]),
            DiskNode(name: "Library", path: "/Users/demo/Library", isDirectory: true, byteCount: 34_000_000_000, children: [
                DiskNode(name: "CoreSimulator", path: "/Users/demo/Library/Developer/CoreSimulator", isDirectory: true, byteCount: 14_000_000_000),
                DiskNode(name: "Android SDK", path: "/Users/demo/Library/Android", isDirectory: true, byteCount: 12_000_000_000),
                DiskNode(name: "DerivedData", path: cache.path, isDirectory: true, byteCount: cache.byteCount)]),
            DiskNode(name: "Projects", path: "/Users/demo/Projects", isDirectory: true, byteCount: 30_000_000_000, children: [
                DiskNode(name: "Design workspace", path: "/Users/demo/Projects/design", isDirectory: true, byteCount: 18_000_000_000),
                DiskNode(name: "Mobile app", path: "/Users/demo/Projects/mobile", isDirectory: true, byteCount: 12_000_000_000)]),
            DiskNode(name: ".android", path: "/Users/demo/.android", isDirectory: true, byteCount: 18_000_000_000),
            DiskNode(name: ".gradle", path: "/Users/demo/.gradle", isDirectory: true, byteCount: 8_000_000_000),
            DiskNode(name: "npm cache", path: safe.path, isDirectory: true, byteCount: safe.byteCount),
            DiskNode(name: "Downloads", path: "/Users/demo/Downloads", isDirectory: true, byteCount: 3_000_000_000)
        ])
        let apps = AppsViewModel()
        let app = AppEntry(id: "demo", name: "Example Editor", path: "/Applications/Example.app", bundleIdentifier: "dev.example.Editor", version: "2.4", byteCount: 480_000_000, isFromSystem: false, completeness: .complete)
        apps.apps = [app]; apps.selectedApp = app
        apps.leftovers = [LeftoverItem(path: "/Users/demo/Library/Caches/dev.example.Editor", byteCount: 37_000_000, kind: "Application cache", safety: .review)]
        let uninspectedApps = AppsViewModel()
        uninspectedApps.apps = [app]
        let status = StatusViewModel()
        status.snapshot = SystemSnapshot(cpuAvailable: true, memoryAvailable: true, diskAvailable: true,
            cpuPercent: 12, memoryUsedBytes: 8_500_000_000, memoryTotalBytes: 16_000_000_000,
            diskFreeBytes: 128_000_000_000, diskTotalBytes: 512_000_000_000,
            memoryPressure: "Normal", swapUsedBytes: 0, processCount: 204, loadAverage1: 1.2)
        status.processes = [
            ProcessInfoRow(pid: 101, name: "Example Editor", path: nil, cpuPercent: 4.2, memoryBytes: 480_000_000, threadCount: 12, isOwnedByUser: true),
            ProcessInfoRow(pid: 202, name: "Preview", path: nil, cpuPercent: 0.2, memoryBytes: 85_000_000, threadCount: 5, isOwnedByUser: true)
        ]
        let review = RemovalPlan(id: UUID(), createdAt: Date(), title: "Review cache cleanup", entries: [], skipped: [OperationIssue(path: "/Users/demo/.codex/sessions", message: "Protected session history cannot be removed.")])
        var result = TrashResult()
        result.destinations = [TrashDestination(originalPath: "/Users/demo/Library/Caches/example", trashPath: "/Users/demo/.Trash/example")]
        result.totalBytes = 128_000_000
        let tests: [(String, AnyView, String)] = [
            ("cleanup-start", AnyView(CleanView(model: CleanViewModel())), "Scan storage"),
            ("cleanup-results", AnyView(CleanView(model: clean)), "Review cleanup"),
            ("cleanup-unselected", AnyView(CleanView(model: uninspectedClean)), "Xcode DerivedData"),
            ("ai-start", AnyView(AIStorageView(model: AIStorageViewModel())), "Scan AI storage"),
            ("ai-results", AnyView(AIStorageView(model: ai)), "Review cleanup"),
            ("ai-unselected", AnyView(AIStorageView(model: uninspectedAI)), "Codex"),
            ("ai-sessions", AnyView(AIStorageView(model: sessionAI)), "Gemini"),
            ("ai-worktrees", AnyView(AIStorageView(model: worktreeAI)), "Registered worktrees"),
            ("storage-start", AnyView(AnalyzeView(model: AnalyzeViewModel(), cleanup: clean)), "Choose folder"),
            ("storage-results", AnyView(AnalyzeView(model: analyze, cleanup: clean)), "Desktop"),
            ("applications", AnyView(AppsView(model: apps)), "Review removal"),
            ("applications-unselected", AnyView(AppsView(model: uninspectedApps)), "Example Editor"),
            ("status", AnyView(StatusView(model: status)), "Search process name or PID"),
            ("maintenance", AnyView(OptimizeView()), "Review reset"),
            ("settings", AnyView(SettingsView()), "Theme"),
            ("welcome", AnyView(OnboardingView(onFinished: {})), "Continue"),
            ("welcome-review", AnyView(HuskWelcomeTour(initialPageIndex: 1, onContinue: {})), "Review before cleanup"),
            ("welcome-ai", AnyView(HuskWelcomeTour(initialPageIndex: 2, onContinue: {})), "Continue to setup"),
            ("welcome-permissions", AnyView(OnboardingPermissionView(onBack: {}, onFinished: {})), "Get started"),
            ("review", AnyView(RemovalReviewSheet(plan: review, confirm: { _ in fatalError("Smoke tests must not remove files") })), "Move to Trash"),
            ("result", AnyView(RemovalResultSheet(result: result)), "Done")
        ]
        for appearance in ["light", "dark"] {
            for width in [960.0, 1200.0] {
                for (name, content, expected) in tests {
                    if let screenFilter, !name.hasPrefix(screenFilter) { continue }
                    let section: AppSection = name.hasPrefix("ai-") ? .aiStorage : name.hasPrefix("storage-") ? .analyze : name.hasPrefix("applications") ? .apps : name == "status" ? .status : name == "maintenance" ? .optimize : name == "settings" ? .settings : .clean
                    let view = name == "review" || name == "result" || name.hasPrefix("welcome") ? content : AnyView(FixtureShell(content: content, section: section))
                    let screenWidth = name.hasPrefix("welcome") ? Double(HuskTheme.onboardingWidth) : width
                    let height = name.hasPrefix("welcome") ? Double(HuskTheme.onboardingHeight) : width == 960 ? 640.0 : 720.0
                    let root = view.environment(permissions).preferredColorScheme(appearance == "dark" ? .dark : .light)
                        .environment(\.controlActiveState, .active)
                        .frame(width: screenWidth, height: height)
                        .ignoresSafeArea(edges: .top)
                    let controller = NSHostingController(rootView: root)
                    controller.sizingOptions = []
                    let hosting = controller.view
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: screenWidth, height: height), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.contentViewController = controller
                    window.setContentSize(NSSize(width: screenWidth, height: height))
                    window.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
                    window.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for: .milliseconds(180))
                    hosting.layoutSubtreeIfNeeded()
                    precondition(abs(window.contentLayoutRect.width - screenWidth) < 1, "Fixture window changed width")
                    let cgImage = try await capture(window)
                    let bitmap = NSBitmapImageRep(cgImage: cgImage)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
                    try png.write(to: output.appendingPathComponent("\(name)-\(appearance)-\(Int(width)).png"))
                    // Keep synchronous Vision work off the main actor so inference can schedule its callbacks.
                    let observations = appearance == "light" && width == 960 ? try await Task.detached { try recognizedText(cgImage) }.value : []
                    let labels = observations.map(\.text)
                    if !observations.isEmpty && !labels.contains(where: { normalized($0).contains(normalized(expected)) }) {
                        throw NSError(domain: "UISmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name) missing rendered control \(expected): \(labels)"])
                    }
                    if name.hasSuffix("unselected") || name == "ai-sessions" || name == "ai-worktrees" {
                        guard let table = descendants(hosting).compactMap({ $0 as? NSTableView }).first,
                              (table.enclosingScrollView?.contentView.bounds.height ?? 0) >= 180 else {
                            throw NSError(domain: "UISmoke", code: 7, userInfo: [NSLocalizedDescriptionKey: name + " has a collapsed table viewport"])
                        }
                    }
                    if name == "cleanup-results", appearance == "light", width == 960 {
                        try click("Select Safe", observations: observations, window: window)
                        try await Task.sleep(for: .milliseconds(150))
                        precondition(clean.selectedIDs.contains(safe.id), "Native Select Safe action did not update selection")
                        clean.clearSelection()
                        print("PASS native Select Safe mouse action")
                    }
                    if name == "storage-results", appearance == "light", width == 960 {
                        try await clickLabel("Select Safe", in: window)
                        precondition(clean.selectedIDs == [safe.id], "Map recommendations selected an unsafe item")
                        let selection = NSBitmapImageRep(cgImage: try await capture(window))
                        try selection.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("storage-selected-light-960.png"))
                        clean.clearSelection()
                        try await clickLabel("Cleanup", in: window)
                        let cleanupColors = NSBitmapImageRep(cgImage: try await capture(window))
                        try cleanupColors.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("storage-cleanup-colors-light-960.png"))
                        try await clickLabel("Category", in: window)
                        try await clickLabel("List", in: window)
                        precondition(descendants(hosting).contains { $0 is NSTableView }, "Map list toggle did not show a table")
                        try await clickLabel("Map", in: window)
                        print("PASS storage recommendation selection and map/list controls")
                    }
                    print("PASS \(name) \(appearance) \(Int(width)) native window capture" + (!observations.isEmpty ? " and visible control text" : ""))
                    fflush(stdout)
                    window.close()
                }
            }
        }
        // Selection models under the same rendered views must retain stable identity.
        clean.toggle(safe)
        precondition(clean.selectedItems.map(\.id) == [safe.id])
        clean.clearSelection()
        precondition(clean.selectedItems.isEmpty)
        ai.toggle(aiCache)
        precondition(ai.selectedBytes == 231_000_000)
        ai.kind = .sessions
        precondition(ai.filteredItems.count == 1 && !ai.filteredItems[0].canRemove)
        print("PASS selection transitions and protected session controls")
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ai", with: "al").filter { $0.isLetter || $0.isNumber }
    }

    @MainActor static func verifyResultTransitions(permissions: PermissionService, output: URL) async throws {
        for width in [960.0, 1200.0] {
            let model = CleanViewModel()
            let height = width == 960 ? 640.0 : 720.0
            let root = FixtureShell(content: AnyView(CleanView(model: model)), section: .clean)
                .environment(permissions).preferredColorScheme(.dark)
                .frame(width: width, height: height).ignoresSafeArea(edges: .top)
            let controller = NSHostingController(rootView: root)
            controller.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                                  styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentViewController = controller
            window.setContentSize(NSSize(width: width, height: height))
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(180))
            model.phase = .scanning(CleanScanProgress(fraction: 0.5, currentPath: "/Users/demo/Library/Caches", itemsFound: 90, bytesFound: 100_000_000))
            try await Task.sleep(for: .milliseconds(180))
            model.categories = [CleanCategory(id: "fixture", name: "Developer", systemImage: "hammer", items: (0..<180).map {
                CleanItem(name: "Cache fixture \($0)", path: "/Users/demo/Library/Caches/fixture\($0)", categoryID: "fixture", categoryName: "Developer", byteCount: Int64(180 - $0) * 1_000_000,
                          safety: .review, reason: "Disposable demonstration cache")
            })]
            model.phase = .ready
            try await Task.sleep(for: .milliseconds(300))
            controller.view.layoutSubtreeIfNeeded()
            let snapshot = try await capture(window)
            let bitmap = NSBitmapImageRep(cgImage: snapshot)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("cleanup-transition-dark-\(Int(width)).png"))
            let observations = try await Task.detached { try recognizedText(snapshot) }.value
            guard observations.contains(where: { $0.text.contains("Cache fixture") }) else {
                throw NSError(domain: "UISmoke", code: 5, userInfo: [NSLocalizedDescriptionKey: "Scan-to-results transition hides every row with no inspector selection at \(Int(width))px."])
            }
            guard let table = descendants(controller.view).compactMap({ $0 as? NSTableView }).first,
                  let scroll = table.enclosingScrollView, scroll.contentView.bounds.height >= 180 else {
                throw NSError(domain: "UISmoke", code: 6, userInfo: [NSLocalizedDescriptionKey: "Results table collapsed below 180pt after scanning at \(Int(width))px."])
            }
            print("PASS scan-to-results with 180 rows and no selection at \(Int(width))px, table viewport \(Int(scroll.contentView.bounds.height))pt")
            fflush(stdout)
            table.scrollRowToVisible(table.numberOfRows - 1)
            try await Task.sleep(for: .milliseconds(180))
            try await requireText("Cache fixture 179", in: window)
            model.searchText = "no-matching-fixture"
            try await Task.sleep(for: .milliseconds(180))
            try await requireText("No matching items", in: window)
            model.searchText = ""
            model.phase = .scanning(CleanScanProgress(fraction: 1, currentPath: "/Users/demo/Library/Caches", itemsFound: 180, bytesFound: model.totalBytes))
            try await Task.sleep(for: .milliseconds(180))
            model.phase = .ready
            try await Task.sleep(for: .milliseconds(180))
            try await requireText("Cache fixture 0", in: window)
            print("PASS results scroll, empty search and repeated scan transition at \(Int(width))px")
            window.close()

            let ai = AIStorageViewModel()
            ai.isScanning = true
            let rule = AIStorageCatalog.rules.first { $0.tool == "Codex" && $0.removable }!
            try await verifyLoadedTable("ai", content: AnyView(AIStorageView(model: ai)), section: .aiStorage, width: width,
                                        expected: "Codex", permissions: permissions, output: output) {
                ai.report = AIStorageReport(items: [AIStorageItem(rule: rule, path: "/Users/demo/" + rule.relativePath,
                    measurement: SizeMeasurement(bytes: 231_000_000), blockedReason: nil)], issues: [], scannedAt: Date())
                ai.isScanning = false
            }
            let apps = AppsViewModel()
            apps.isLoadingApps = true
            try await verifyLoadedTable("applications", content: AnyView(AppsView(model: apps)), section: .apps, width: width,
                                        expected: "Example Editor", permissions: permissions, output: output) {
                apps.apps = [AppEntry(id: "fixture", name: "Example Editor", path: "/Applications/Example.app",
                                     bundleIdentifier: "dev.example.Editor", version: "2.4", byteCount: 480_000_000,
                                     isFromSystem: false, completeness: .complete)]
                apps.isLoadingApps = false
            }
            let analyze = AnalyzeViewModel()
            let clean = CleanViewModel()
            try await verifyLoadedTable("storage", content: AnyView(AnalyzeView(model: analyze, cleanup: clean)), section: .analyze, width: width,
                                        expected: "Design workspace", permissions: permissions, output: output) {
                analyze.root = DiskNode(name: "Projects", path: "/Users/demo/Projects", isDirectory: true, byteCount: 1_000_000_000,
                    children: [DiskNode(name: "Design workspace", path: "/Users/demo/Projects/Design workspace", isDirectory: true, byteCount: 1_000_000_000)])
            }
            let status = StatusViewModel()
            try await verifyLoadedTable("status", content: AnyView(StatusView(model: status)), section: .status, width: width,
                                        expected: "Example process", permissions: permissions, output: output) {
                status.processes = [ProcessInfoRow(pid: 101, name: "Example process", path: nil, cpuPercent: 1.2,
                                                   memoryBytes: 120_000_000, threadCount: 4, isOwnedByUser: true)]
            }
        }
    }

    @MainActor static func verifyLoadedTable(_ name: String, content: AnyView, section: AppSection, width: Double,
        expected: String, permissions: PermissionService, output: URL, load: () -> Void) async throws {
        let height = width == 960 ? 640.0 : 720.0
        let root = FixtureShell(content: content, section: section).environment(permissions).preferredColorScheme(.dark)
            .frame(width: width, height: height).ignoresSafeArea(edges: .top)
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = controller
        window.setContentSize(NSSize(width: width, height: height))
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(180))
        load()
        try await Task.sleep(for: .milliseconds(250))
        controller.view.layoutSubtreeIfNeeded()
        try await requireText(expected, in: window)
        if name == "storage" {
            try await clickLabel("List", in: window)
            try await Task.sleep(for: .milliseconds(150))
        }
        guard let table = descendants(controller.view).compactMap({ $0 as? NSTableView }).first,
              (table.enclosingScrollView?.contentView.bounds.height ?? 0) >= 180 else {
            throw NSError(domain: "UISmoke", code: 9, userInfo: [NSLocalizedDescriptionKey: name + " table collapsed after data arrived"])
        }
        let bitmap = NSBitmapImageRep(cgImage: try await capture(window))
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)-transition-dark-\(Int(width)).png"))
        print("PASS \(name) asynchronous data-to-table transition at \(Int(width))px")
        fflush(stdout)
        window.close()
    }

    @MainActor static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    @MainActor static func verifyOnboarding(permissions: PermissionService, output: URL) async throws {
        // New instances use the same welcome path as the persisted Settings replay action.
        for (appearance, reduceMotion) in [("light", false), ("dark", true)] {
            var completions = 0
            let root = OnboardingView(reduceMotionOverride: reduceMotion, onFinished: { completions += 1 })
                .environment(permissions)
                .environment(\.controlActiveState, .active).preferredColorScheme(appearance == "dark" ? .dark : .light)
                .frame(width: HuskTheme.onboardingWidth, height: HuskTheme.onboardingHeight).ignoresSafeArea(edges: .top)
            let controller = NSHostingController(rootView: root)
            controller.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: HuskTheme.onboardingWidth, height: HuskTheme.onboardingHeight),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentViewController = controller
            window.setContentSize(NSSize(width: HuskTheme.onboardingWidth, height: HuskTheme.onboardingHeight))
            window.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(200))
            try await requireText("Welcome to Husk", in: window)
            try await clickLabel("Continue", in: window)
            try await requireText("Review before cleanup", in: window)
            sendKey("\u{f702}", keyCode: 123, window: window)
            try await Task.sleep(for: .milliseconds(350))
            try await requireText("Welcome to Husk", in: window)
            sendKey("\r", keyCode: 36, window: window)
            try await Task.sleep(for: .milliseconds(350))
            try await requireText("Review before cleanup", in: window)
            try await clickLabel("Continue", in: window)
            try await requireText("AI storage, protected", in: window)
            try await clickLabel("Continue to setup", in: window)
            try await requireText("Your Mac. Your permission", in: window)
            precondition(completions == 0, "The tour must not mark onboarding complete before optional setup")
            try await clickLabel("Back to tour", in: window)
            try await requireText("Welcome to Husk", in: window)
            // The skip circle is inset 30pt horizontally and below the native window controls.
            try sendClick(NSPoint(x: 530, y: 536), window: window)
            try await Task.sleep(for: .milliseconds(350))
            try await requireText("Your Mac. Your permission", in: window)
            precondition(completions == 0, "Skipping the tour must still offer optional setup")
            try await clickLabel("Get started", in: window)
            precondition(completions == 1, "Get started must complete onboarding once without requiring disk access")
            print("PASS native tour forward, back, Return, skip, setup and completion; \(appearance), Reduce Motion \(reduceMotion)")
            fflush(stdout)
            window.close()
        }
    }

    @MainActor static func requireText(_ expected: String, in window: NSWindow) async throws {
        let snapshot = try await capture(window)
        let observations = try await Task.detached { try recognizedText(snapshot) }.value
        guard observations.contains(where: { normalized($0.text).contains(normalized(expected)) }) else {
            throw NSError(domain: "UISmoke", code: 8, userInfo: [NSLocalizedDescriptionKey: "Onboarding missing " + expected + ": " + observations.map(\.text).joined(separator: " | ")])
        }
    }

    @MainActor static func clickLabel(_ text: String, in window: NSWindow) async throws {
        let snapshot = try await capture(window)
        let observations = try await Task.detached { try recognizedText(snapshot) }.value
        try click(text, observations: observations, window: window)
        try await Task.sleep(for: .milliseconds(350))
    }

    @MainActor static func sendKey(_ characters: String, keyCode: UInt16, window: NSWindow) {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode) else { fatalError("No key event") }
        if !window.performKeyEquivalent(with: event) { window.sendEvent(event) }
    }
    @MainActor static func capture(_ window: NSWindow) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else { throw NSError(domain: "UISmoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "Window capture needs Screen Recording access for the test runner."]) }
        var target: SCWindow?
        for _ in 0..<4 {
            // Desktop-independent window captures also work when another app changes the active Space.
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            target = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) })
            if target != nil { break }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            try await Task.sleep(for: .milliseconds(300))
        }
        guard let target else {
            throw NSError(domain: "UISmoke", code: 10, userInfo: [NSLocalizedDescriptionKey: "Fixture window was not listed after bounded capture-service retries."])
        }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width * window.backingScaleFactor)
        configuration.height = Int(window.frame.height * window.backingScaleFactor)
        configuration.showsCursor = false
        for attempt in 0..<3 {
            do {
                return try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: target), configuration: configuration)
            } catch let error as NSError where error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && error.code == -3811 && attempt < 2 {
                // The capture service can briefly reject a new stream after closing the previous fixture window.
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        throw NSError(domain: "UISmoke", code: 4, userInfo: [NSLocalizedDescriptionKey: "Window capture exhausted its bounded retries."])
    }
    struct TextObservation: Sendable {
        let text: String
        let boundingBox: CGRect
    }

    static func recognizedText(_ image: CGImage) throws -> [TextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // CPU inference keeps this fixture check independent of Neural Engine resource availability.
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { TextObservation(text: $0.string, boundingBox: observation.boundingBox) }
        }
    }

    @MainActor static func click(_ text: String, observations: [TextObservation], window: NSWindow) throws {
        guard let observation = observations.first(where: { normalized($0.text) == normalized(text) })
                ?? observations.first(where: { $0.text.localizedCaseInsensitiveContains(text) }),
              let content = window.contentView else {
            throw NSError(domain: "UISmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing click target " + text])
        }
        let rect = observation.boundingBox
        let point = NSPoint(x: rect.midX * content.bounds.width, y: rect.midY * window.frame.height)
        try sendClick(point, window: window)
    }

    @MainActor static func sendClick(_ point: NSPoint, window: NSWindow) throws {
        for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1) else { fatalError("No mouse event") }
            window.sendEvent(event)
        }
    }

}

private struct FixtureShell: View {
    let content: AnyView
    @State var section: AppSection
    var body: some View {
        HStack(spacing: 0) {
            IconRail(selection: $section, freeSpace: "48 GB")
            ZStack {
                HuskBackground()
                content.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 12)
            }
        }.ignoresSafeArea(edges: .top).tint(Color.huskAccentText)
    }
}
