import Foundation

enum WorktreeInspectionService {
    /// NUL-delimited porcelain preserves paths containing spaces and newlines.
    static func parse(_ data: String) -> [GitWorktree] {
        var result: [GitWorktree] = []
        var path: String?, branch: String?
        var locked = false, prunable = false, bare = false
        func finish() {
            if let path, path.hasPrefix("/") {
                result.append(GitWorktree(path: path, branch: branch, locked: locked, prunable: prunable, bare: bare))
            }
            path = nil; branch = nil; locked = false; prunable = false; bare = false
        }
        for field in data.split(separator: "\0", omittingEmptySubsequences: false) {
            if field.isEmpty { finish() }
            else if field.hasPrefix("worktree ") { path = String(field.dropFirst(9)) }
            else if field.hasPrefix("branch ") { branch = String(field.dropFirst(7)) }
            else if field == "bare" { bare = true }
            else if field == "locked" || field.hasPrefix("locked ") { locked = true }
            else if field == "prunable" || field.hasPrefix("prunable ") { prunable = true }
        }
        finish()
        return result
    }

    static func inspect(repository: String) async throws -> [GitWorktree] {
        guard !PathSafety.hasUnsafeSymlink(repository), !ScanPreferences.isExcluded(repository),
              !PathSafety.shouldSkipForSizing(repository), (try? FileIdentity.read(repository).owner) == getuid() else { throw RemovalError.changed("Choose a local, non-excluded repository without symbolic links.") }
        let environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") }
        let base = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null"]
        let listing = try await ProcessRunner.run("/usr/bin/git", arguments: base + ["-C", repository, "worktree", "list", "--porcelain", "-z"], environment: environment)
        guard listing.exitCode == 0, !listing.timedOut, !listing.truncated else {
            throw RemovalError.changed("Git could not inspect this repository. Check its ownership and Git installation.")
        }
        var records = parse(listing.text)
        guard records.count <= 30 else { throw RemovalError.changed("More than 30 worktrees. Choose a smaller repository for a bounded inspection.") }
        let start = ContinuousClock.now
        for index in records.indices {
            try Task.checkCancellation()
            let record = records[index]
            if record.bare { records[index].status = "Bare repository"; continue }
            if record.prunable { records[index].status = "Registration may be stale; review with Git"; continue }
            if PathSafety.hasUnsafeSymlink(record.path) || ScanPreferences.isExcluded(record.path) || PathSafety.shouldSkipForSizing(record.path) || (try? FileIdentity.read(record.path).owner) != getuid() {
                records[index].status = "Skipped: redirected, excluded, unavailable or owned by another user"; continue
            }
            if start.duration(to: .now) > .seconds(20) { records[index].status = "Inspection time limit reached"; continue }
            let status = try await ProcessRunner.run("/usr/bin/git", arguments: base + ["-C", record.path, "status", "--porcelain=v1", "-z", "--untracked-files=normal", "--ignore-submodules=all"], timeout: 3, environment: environment)
            records[index].status = status.exitCode != 0 || status.timedOut || status.truncated
                ? "Status unavailable"
                : status.output.isEmpty ? "No reported changes; ignored files, submodule state and usage unknown" : "Contains changes or untracked files"
        }
        return records
    }
}
