//
//  OptimizeService.swift
//  Husk
//

import Foundation

enum OptimizeService {
    static let tasks: [OptimizeTask] = [
        OptimizeTask(
            id: "quicklook",
            title: "Rebuild Quick Look cache",
            detail: "Resets generated file previews with qlmanage -r cache. Use this when previews are stale.",
            systemImage: "eye",
            needsAdmin: false
        )
    ]

    static func run(_ task: OptimizeTask) async -> (success: Bool, message: String) {
        switch task.id {
        case "quicklook":
            return await runProcess("/usr/bin/qlmanage", args: ["-r", "cache"])
        default:
            return (false, "Unknown task")
        }
    }

    private static func runProcess(_ launchPath: String, args: [String]) async -> (Bool, String) {
        do {
            let result = try await ProcessRunner.run(launchPath, arguments: args)
            if result.timedOut { return (false, "Command timed out and was stopped.") }
            if result.truncated { return (false, "Command exceeded the output limit and was stopped.") }
            let text = result.text + String(decoding: result.errorOutput, as: UTF8.self)
            return (result.exitCode == 0, text.isEmpty ? "Exit code \(result.exitCode)" : text)
        } catch { return (false, error.localizedDescription) }
    }
}
