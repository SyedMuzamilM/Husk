import AppKit
import Foundation
import Vision
import ScreenCaptureKit

/// Runs the production SwiftUI scene in a private fixture app, without scanning or cleanup.
@MainActor enum WindowSmoke {
    private static var observer: NSObjectProtocol?
    private static var results: [String] = []

    static func configure() {
        precondition(Bundle.main.bundleIdentifier == "dev.husk.WindowSmoke")
        UserDefaults.standard.set(false, forKey: "husk.hasCompletedOnboarding")
        UserDefaults.standard.set("light", forKey: "husk.appearance")
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification,
                                                         object: nil, queue: .main) { _ in
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(600))
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSRunningApplication.current.activate(options: .activateAllWindows)
                    var mainWindow: NSWindow?
                    for _ in 0..<100 {
                        mainWindow = NSApplication.shared.windows.first(where: { $0.contentView != nil && !$0.isSheet })
                        if mainWindow != nil { break }
                        try await Task.sleep(for: .milliseconds(200))
                    }
                    guard let window = mainWindow else {
                        throw NSError(domain: "WindowSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "No main window"])
                    }
                    try checkCompact(window, state: "first launch")
                    try await clickLabel("Continue", in: window)
                    try await clickLabel("Continue", in: window)
                    try await clickLabel("Continue to setup", in: window)
                    guard !UserDefaults.standard.bool(forKey: "husk.hasCompletedOnboarding") else {
                        throw NSError(domain: "WindowSmoke", code: 6, userInfo: [NSLocalizedDescriptionKey: "Tour completed before optional setup"])
                    }
                    try await clickLabel("Get started", in: window)
                    guard UserDefaults.standard.bool(forKey: "husk.hasCompletedOnboarding") else {
                        throw NSError(domain: "WindowSmoke", code: 4, userInfo: [NSLocalizedDescriptionKey: "Get started did not persist completion"])
                    }
                    results.append("PASS Get started persists completion without disk access")
                    try await Task.sleep(for: .milliseconds(600))
                    let mainSize = window.contentLayoutRect.size
                    guard mainSize.width >= 960, mainSize.height >= 640 else {
                        throw NSError(domain: "WindowSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "Main app did not expand: \(mainSize)"])
                    }
                    results.append("PASS full app expands to \(Int(mainSize.width))×\(Int(mainSize.height))")
                    UserDefaults.standard.set(false, forKey: "husk.hasCompletedOnboarding")
                    try await Task.sleep(for: .milliseconds(600))
                    try checkCompact(window, state: "replay")
                    results.append("PASS window lifecycle")
                    writeResult()
                    NSApplication.shared.terminate(nil)
                } catch {
                    results.append("FAIL \(error)")
                    writeResult()
                    exit(1)
                }
            }
        }
    }

    private static func checkCompact(_ window: NSWindow, state: String) throws {
        let size = window.contentLayoutRect.size
        guard abs(size.width - 560) < 1, abs(size.height - 600) < 1 else {
            throw NSError(domain: "WindowSmoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "Onboarding did not shrink for \(state): \(size)"])
        }
        results.append("PASS compact onboarding at \(Int(size.width))×\(Int(size.height)) for \(state)")
    }

    @MainActor static func clickLabel(_ text: String, in window: NSWindow) async throws {
        let snapshot = try await capture(window)
        let observations = try await Task.detached { try recognizedText(snapshot) }.value
        try click(text, observations: observations, window: window)
        try await Task.sleep(for: .milliseconds(350))
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

    nonisolated static func recognizedText(_ image: CGImage) throws -> [TextObservation] {
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
        try sendClick(point, window: window)
    }

    @MainActor static func sendClick(_ point: NSPoint, window: NSWindow) throws {
        for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1) else { fatalError("No mouse event") }
            window.sendEvent(event)
        }
    }

    private static func writeResult() {
        let result = results.joined(separator: "\n") + "\n"
        print(result)
        fflush(stdout)
        if let path = CommandLine.arguments.first(where: { $0.hasSuffix("/window-result.txt") }) {
            try? result.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
