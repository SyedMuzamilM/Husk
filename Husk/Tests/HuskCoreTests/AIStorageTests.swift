import Foundation
import Testing
@testable import HuskCore

struct AIStorageTests {
    @Test func stateRootsCannotBeRemovedThroughOtherScreens() {
        let home = NSHomeDirectory()
        for suffix in [".codex", ".codex/sessions/2026/01", ".codex/state_1.sqlite", ".codex/.tmp",
                       ".gemini/tmp/project/chats", ".gemini/oauth_creds.json", ".claude/projects",
                       ".local/share/opencode", "Library/Application Support/Codex", ".ollama/models",
                       ".local/share/claude/versions", "Library/Application Support/Cursor/User/workspaceStorage"] {
            #expect(PathSafety.isProtected(home + "/" + suffix))
            #expect(AIStorageCatalog.cacheRule(for: home + "/" + suffix) == nil)
        }
        #expect(!PathSafety.isProtected(home + "/Library/Application Support/Claude/GPUCache"))
        #expect(!PathSafety.isProtected(home + "/.cache/opencode"))
        #expect(PathSafety.isProtected(home + "/Library/Caches/Codex"))
        #expect(PathSafety.isProtected(home + "/.gemini/antigravity-browser-profile/Default"))
    }

    @Test func explicitCacheRulesDoNotMatchLookalikesOrParents() {
        let home = "/private/tmp/AI-fixture"
        #expect(AIStorageCatalog.cacheRule(for: home + "/.cache/opencode/subfolder", home: home)?.tool == "OpenCode")
        #expect(AIStorageCatalog.cacheRule(for: home + "/.cache/opencode-backup", home: home) == nil)
        #expect(AIStorageCatalog.cacheRule(for: home + "/Library/Application Support/Claude", home: home) == nil)
        #expect(AIStorageCatalog.cacheRule(for: home + "/Library/Application Support/Claude/Cache../Cookies", home: home) == nil)
        #expect(PathSafety.isProtectedAIStorage(home + "/.gemini/tmp", home: home))
        #expect(PathSafety.isProtectedAIStorage(home + "/.CODEX", home: home))
        #expect(PathSafety.isProtectedAIStorage(home + "/.GEMINI", home: home))
        #expect(AIStorageCatalog.cacheRule(for: home + "/.CACHE/OPENCODE", home: home)?.tool == "OpenCode")
    }

    @Test func processActivityFailsClosedForCLIsAndUnknownState() {
        let openCode = AIStorageCatalog.rules.first { $0.tool == "OpenCode" && $0.removable }!
        let codex = AIStorageCatalog.rules.first { $0.tool == "Codex" && $0.removable }!
        #expect(AIStorageService.Activity(commands: nil).blockedReason(for: openCode) != nil)
        #expect(AIStorageService.Activity(commands: []).blockedReason(for: openCode) != nil)
        #expect(AIStorageService.Activity(commands: ["  "]).blockedReason(for: openCode) != nil)
        #expect(AIStorageService.Activity(commands: ["/usr/local/bin/node"]).blockedReason(for: openCode) != nil)
        #expect(AIStorageService.Activity(commands: ["/usr/local/bin/opencode"]).blockedReason(for: openCode) != nil)
        #expect(AIStorageService.Activity(commands: ["/Applications/Codex.app/Contents/MacOS/Codex"]).blockedReason(for: codex) != nil)
        #expect(AIStorageService.Activity(commands: ["/usr/bin/Finder"]).blockedReason(for: openCode) == nil)
    }

    @Test func discoveryKeepsSessionsAndIgnoresRedirectedCaches() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for suffix in [".codex/sessions", ".gemini/tmp/project/chats", ".cache", "Library/Application Support/Claude/GPUCache"] {
            try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent(suffix), withIntermediateDirectories: true)
        }
        let chat = fixture.root.appendingPathComponent(".gemini/tmp/project/chats/session.json")
        try Data("private fixture transcript".utf8).write(to: chat)
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent(".cache/opencode"), withDestinationURL: fixture.root.appendingPathComponent(".codex/sessions"))
        let report = try await AIStorageService.scan(home: fixture.root.path)
        #expect(report.items.contains { $0.rule.kind == .sessions && $0.rule.tool == "Gemini" && !$0.canRemove })
        #expect(!report.items.contains { $0.rule.removable && $0.rule.tool == "OpenCode" })
        #expect(report.issues.count == 1)
        #expect(try Data(contentsOf: chat) == Data("private fixture transcript".utf8))
    }

    @Test @MainActor func selectionCannotIncludeDataBlockedOrPartialItems() {
        let model = AIStorageViewModel()
        let cache = AIStorageCatalog.rules.first { $0.removable }!
        let sessions = AIStorageCatalog.rules.first { $0.kind == .sessions }!
        let eligible = AIStorageItem(rule: cache, path: "/tmp/cache", measurement: SizeMeasurement(bytes: 4096), blockedReason: nil)
        let partial = AIStorageItem(rule: cache, path: "/tmp/partial", measurement: SizeMeasurement(bytes: 8192, status: .partial), blockedReason: nil)
        let blocked = AIStorageItem(rule: cache, path: "/tmp/active", measurement: SizeMeasurement(bytes: 8192), blockedReason: "Running")
        let data = AIStorageItem(rule: sessions, path: "/tmp/sessions", measurement: SizeMeasurement(bytes: 8192), blockedReason: nil)
        model.report = AIStorageReport(items: [eligible, partial, blocked, data], issues: [], scannedAt: Date())
        for item in model.items { model.toggle(item) }
        #expect(model.selectedItems.map(\.id) == [eligible.id])
        #expect(model.selectedBytes == 4096)
        model.kind = .sessions
        #expect(model.filteredItems.map(\.id) == [data.id])
        model.searchText = "nonexistent"
        #expect(model.filteredItems.isEmpty)
    }

    @Test func genericScanSharesOnlyExplicitCacheRules() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let targets = CleanScanner.buildTargets(home: fixture.root.path).filter { $0.categoryID == "ai-agents" }
        #expect(!targets.isEmpty)
        #expect(!targets.contains { $0.path.contains("/.codex/") || $0.path.contains("/.gemini/tmp") || $0.path.contains("/.local/share/opencode") })
        for rule in AIStorageCatalog.rules where rule.removable {
            #expect(targets.contains { $0.path == rule.path(home: fixture.root.path) && $0.safetyOverride == .review })
        }
    }
}

struct WorktreeTests {
    @Test func porcelainPreservesUnusualPathsAndFlags() {
        let records = WorktreeInspectionService.parse("worktree /tmp/a b\nline\0HEAD abc\0branch refs/heads/topic\0locked needs review\0\0worktree /tmp/stale\0HEAD def\0detached\0prunable gitdir missing\0\0")
        #expect(records.count == 2)
        #expect(records[0].path == "/tmp/a b\nline")
        #expect(records[0].branch == "refs/heads/topic")
        #expect(records[0].locked)
        #expect(records[1].prunable)
        #expect(records[1].branch == nil)
    }

    @Test func repositoryInspectionReportsDirtyAndLockedWithoutMutation() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let repo = fixture.root.appendingPathComponent("repository")
        let tree = fixture.root.appendingPathComponent("working copy")
        let initResult = try await ProcessRunner.run("/usr/bin/git", arguments: ["init", repo.path])
        #expect(initResult.exitCode == 0)
        let commit = try await ProcessRunner.run("/usr/bin/git", arguments: ["-C", repo.path, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false", "commit", "--allow-empty", "-m", "Fixture"])
        #expect(commit.exitCode == 0)
        let add = try await ProcessRunner.run("/usr/bin/git", arguments: ["-C", repo.path, "worktree", "add", "-b", "fixture", tree.path])
        #expect(add.exitCode == 0)
        try Data("uncommitted".utf8).write(to: tree.appendingPathComponent("keep.txt"))
        let lock = try await ProcessRunner.run("/usr/bin/git", arguments: ["-C", repo.path, "worktree", "lock", tree.path])
        #expect(lock.exitCode == 0)
        let records = try await WorktreeInspectionService.inspect(repository: repo.path)
        let linked = try #require(records.first { $0.path == tree.path })
        #expect(linked.locked)
        #expect(linked.status == "Contains changes or untracked files")
        #expect(FileManager.default.fileExists(atPath: tree.appendingPathComponent("keep.txt").path))
        let after = try await ProcessRunner.run("/usr/bin/git", arguments: ["-C", repo.path, "worktree", "list", "--porcelain", "-z"])
        #expect(WorktreeInspectionService.parse(after.text).count == records.count)
    }
}

private actor ActivityFixture {
    var running = false
    func setRunning() { running = true }
    func reason() -> String? { running ? "Owner started after review" : nil }
}

struct AIExecutionTests {
    @Test func activityIsRevalidatedBetweenReviewAndMove() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("cache")
        let activity = ActivityFixture()
        let service = RemovalService(recordHistory: false, move: { _ in
            Issue.record("Active owner reached Trash"); return file
        }, activityCheck: { _ in await activity.reason() })
        let plan = await service.prepare([RemovalCandidate(path: file.path, bytes: 4096, safety: .review, reason: "fixture")], title: "fixture")
        #expect(plan.entries.count == 1)
        await activity.setRunning()
        let result = try await service.execute(plan)
        #expect(result.successCount == 0)
        #expect(result.failures.first?.error == "Owner started after review")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
