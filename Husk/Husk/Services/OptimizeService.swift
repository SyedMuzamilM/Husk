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
            detail: "Runs qlmanage -r to refresh file previews.",
            systemImage: "eye",
            needsAdmin: false
        ),
        OptimizeTask(
            id: "dns",
            title: "Flush DNS cache",
            detail: "Resets local DNS resolver cache. Requires admin password.",
            systemImage: "network",
            needsAdmin: true
        ),
        OptimizeTask(
            id: "utsname",
            title: "Purge inactive memory (safe info)",
            detail: "macOS manages RAM automatically. Husk does not force-purge RAM — that is a placebo.",
            systemImage: "memorychip",
            needsAdmin: false
        )
    ]

    static func run(_ task: OptimizeTask) async -> (success: Bool, message: String) {
        switch task.id {
        case "quicklook":
            return await runProcess("/usr/bin/qlmanage", args: ["-r"])
        case "dns":
            // Prefer informing user — full flush needs privileged helper
            return (
                false,
                "DNS flush needs administrator privileges. Open Terminal and run: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
            )
        case "utsname":
            return (
                true,
                "Skipped intentional placebo. Your Mac already compresses and frees inactive memory when needed."
            )
        default:
            return (false, "Unknown task")
        }
    }

    private static func runProcess(_ launchPath: String, args: [String]) async -> (Bool, String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = args
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let text = String(data: data, encoding: .utf8) ?? ""
                    if process.terminationStatus == 0 {
                        cont.resume(returning: (true, text.isEmpty ? "Completed successfully." : text))
                    } else {
                        cont.resume(returning: (false, text.isEmpty ? "Exit code \(process.terminationStatus)" : text))
                    }
                } catch {
                    cont.resume(returning: (false, error.localizedDescription))
                }
            }
        }
    }
}
