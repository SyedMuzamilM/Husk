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
        let clean = CleanViewModel()
        let cache = CleanItem(name: "Xcode DerivedData", path: "/Users/demo/Library/Developer/Xcode/DerivedData", categoryID: "developer", categoryName: "Developer", byteCount: 2_340_000_000, safety: .review, reason: "Build intermediates. Recreated on the next compile.")
        let safe = CleanItem(name: "npm package cache", path: "/Users/demo/.npm/_cacache", categoryID: "package-managers", categoryName: "Package Managers", byteCount: 483_000_000, safety: .safe, reason: "Downloaded package cache.")
        clean.categories = [CleanCategory(id: "developer", name: "Developer", systemImage: "hammer", items: [cache, safe])]
        clean.phase = .ready
        clean.inspectedItem = cache
        let ai = AIStorageViewModel()
        let rule = AIStorageCatalog.rules.first { $0.tool == "Codex" && $0.removable }!
        let session = AIStorageCatalog.rules.first { $0.tool == "Gemini" && $0.kind == .sessions }!
        let aiCache = AIStorageItem(rule: rule, path: "/Users/demo/" + rule.relativePath, measurement: SizeMeasurement(bytes: 231_000_000), blockedReason: nil)
        ai.report = AIStorageReport(items: [aiCache, AIStorageItem(rule: session, path: "/Users/demo/.gemini/tmp", measurement: SizeMeasurement(bytes: 77_000_000), blockedReason: "Inspection only. Contains saved chats.")], issues: [], scannedAt: Date())
        ai.inspectedID = aiCache.id
        let analyze = AnalyzeViewModel()
        analyze.root = DiskNode(name: "Projects", path: "/Users/demo/Projects", isDirectory: true, byteCount: 3_040_000_000, children: [DiskNode(name: "Design workspace", path: "/Users/demo/Projects/Design workspace", isDirectory: true, byteCount: 2_190_000_000), DiskNode(name: "Archive.zip", path: "/Users/demo/Projects/Archive.zip", isDirectory: false, byteCount: 850_000_000)])
        let apps = AppsViewModel()
        let app = AppEntry(id: "demo", name: "Example Editor", path: "/Applications/Example.app", bundleIdentifier: "dev.example.Editor", version: "2.4", byteCount: 480_000_000, isFromSystem: false, completeness: .complete)
        apps.apps = [app]; apps.selectedApp = app
        apps.leftovers = [LeftoverItem(path: "/Users/demo/Library/Caches/dev.example.Editor", byteCount: 37_000_000, kind: "Application cache", safety: .review)]
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
            ("ai-start", AnyView(AIStorageView(model: AIStorageViewModel())), "Scan AI storage"),
            ("ai-results", AnyView(AIStorageView(model: ai)), "Review cleanup"),
            ("storage-start", AnyView(AnalyzeView(model: AnalyzeViewModel())), "Choose folder"),
            ("storage-results", AnyView(AnalyzeView(model: analyze)), "Refresh"),
            ("applications", AnyView(AppsView(model: apps)), "Review removal"),
            ("status", AnyView(StatusView(model: status)), "Search process name or PID"),
            ("maintenance", AnyView(OptimizeView()), "Review reset"),
            ("settings", AnyView(SettingsView()), "Theme"),
            ("welcome", AnyView(OnboardingView(onFinished: {})), "Get started"),
            ("review", AnyView(RemovalReviewSheet(plan: review, confirm: { _ in fatalError("Smoke tests must not remove files") })), "Move to Trash"),
            ("result", AnyView(RemovalResultSheet(result: result)), "Done")
        ]
        for appearance in ["light", "dark"] {
            for width in [960.0, 1200.0] {
                for (name, content, expected) in tests {
                    let section: AppSection = name.hasPrefix("ai-") ? .aiStorage : name.hasPrefix("storage-") ? .analyze : name == "applications" ? .apps : name == "status" ? .status : name == "maintenance" ? .optimize : name == "settings" ? .settings : .clean
                    let view = name == "review" || name == "result" || name == "welcome" ? content : AnyView(FixtureShell(content: content, section: section))
                    let height = width == 960 ? 640.0 : 720.0
                    let root = view.environment(permissions).preferredColorScheme(appearance == "dark" ? .dark : .light)
                        .environment(\.controlActiveState, .active)
                        .frame(width: width, height: height)
                        .ignoresSafeArea(edges: .top)
                    let controller = NSHostingController(rootView: root)
                    controller.sizingOptions = []
                    let hosting = controller.view
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: width == 960 ? 640 : 720), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.contentViewController = controller
                    window.setContentSize(NSSize(width: width, height: height))
                    window.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
                    window.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for: .milliseconds(180))
                    hosting.layoutSubtreeIfNeeded()
                    precondition(abs(window.contentLayoutRect.width - width) < 1, "Fixture window changed width")
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
                    if name == "cleanup-results", appearance == "light", width == 960 {
                        try click("Select Safe", observations: observations, window: window)
                        try await Task.sleep(for: .milliseconds(150))
                        precondition(clean.selectedIDs.contains(safe.id), "Native Select Safe action did not update selection")
                        clean.clearSelection()
                        print("PASS native Select Safe mouse action")
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
    @MainActor static func capture(_ window: NSWindow) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else { throw NSError(domain: "UISmoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "Window capture needs Screen Recording access for the test runner."]) }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let target = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else { fatalError("Fixture window not listed") }
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
        guard let observation = observations.first(where: { $0.text.localizedCaseInsensitiveContains(text) }),
              let content = window.contentView else {
            throw NSError(domain: "UISmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing click target " + text])
        }
        let rect = observation.boundingBox
        let point = NSPoint(x: rect.midX * content.bounds.width, y: rect.midY * window.frame.height)
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
        }.ignoresSafeArea(edges: .top).tint(Color.huskPrimary)
    }
}
