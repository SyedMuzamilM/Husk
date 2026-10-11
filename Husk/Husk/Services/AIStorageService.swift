import Foundation

enum AIStorageService {
    static func scan(home: String = NSHomeDirectory()) async throws -> AIStorageReport {
        let discovered = try await BlockingIO.run { flag in
            var found: [(AIStorageRule, String)] = []
            var issues: [OperationIssue] = []
            for rule in AIStorageCatalog.rules {
                if flag.isCancelled { throw CancellationError() }
                let path = rule.path(home: home)
                do {
                    let identity = try FileIdentity.read(path)
                    guard identity.owner == getuid(), !PathSafety.hasUnsafeSymlink(path), !ScanPreferences.isExcluded(path) else {
                        issues.append(OperationIssue(path: path, message: "Excluded, redirected, or owned by another user.")); continue
                    }
                    found.append((rule, path))
                } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT) {
                    continue
                } catch { issues.append(OperationIssue(path: path, message: error.localizedDescription)) }
            }
            return (found, issues)
        }
        var items: [AIStorageItem] = []
        // One bounded process probe for the scan, fresh probes again at review and execution.
        let activity = await activitySnapshot()
        for (rule, path) in discovered.0 {
            try Task.checkCancellation()
            let measurement: SizeMeasurement
            do { measurement = try await DirectorySizer.measure(URL(fileURLWithPath: path)) }
            catch is CancellationError { throw CancellationError() }
            catch { measurement = SizeMeasurement(status: .unavailable, issues: [OperationIssue(path: path, message: error.localizedDescription)], totalIssueCount: 1) }
            let reason = rule.removable ? activity.blockedReason(for: rule) : "Inspection only. " + rule.detail
            items.append(AIStorageItem(rule: rule, path: path, measurement: measurement, blockedReason: reason))
        }
        return AIStorageReport(items: items.sorted { $0.measurement.bytes > $1.measurement.bytes }, issues: discovered.1, scannedAt: Date())
    }

    struct Activity: Sendable {
        let commands: [String]?
        func blockedReason(for rule: AIStorageRule) -> String? {
            guard let commands, commands.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                return "Process activity could not be verified. Cleanup is blocked."
            }
            let names: [String]
            switch rule.tool {
            case "Codex": names = ["codex"]
            case "Claude": names = ["claude"]
            case "Cursor": names = ["cursor"]
            case "Gemini", "Antigravity": names = ["gemini", "antigravity"]
            case "OpenCode": names = ["opencode"]
            default: names = [rule.tool.lowercased()]
            }
            if commands.contains(where: { command in names.contains { command.lowercased().contains($0) } }) {
                return "\(rule.tool) has a running process. Quit it, then scan again."
            }
            // CLIs can run under unnamed JS runtimes. Activity cannot be attributed reliably.
            if rule.ownerBundleID == nil || rule.tool == "Gemini" {
                if commands.contains(where: { ["node", "bun", "deno"].contains(URL(fileURLWithPath: $0).lastPathComponent.lowercased()) }) {
                    return "A JavaScript runtime is running. Husk cannot prove this CLI cache is inactive."
                }
            }
            return nil
        }
    }

    static func activitySnapshot() async -> Activity {
        do {
            let result = try await ProcessRunner.run("/bin/ps", arguments: ["-axo", "comm="], outputLimit: 1_048_576)
            guard result.exitCode == 0, !result.timedOut, !result.truncated else { return Activity(commands: nil) }
            return Activity(commands: result.text.split(separator: "\n").map(String.init))
        } catch { return Activity(commands: nil) }
    }

    static func removalBlock(for path: String) async -> String? {
        guard let rule = AIStorageCatalog.cacheRule(for: path) else { return nil }
        return await activitySnapshot().blockedReason(for: rule)
    }
}
