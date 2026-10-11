import Darwin
import Foundation
import Testing
@testable import HuskCore

struct Fixture {
    let root: URL
    init() throws {
        root = URL(fileURLWithPath: "/private/tmp/Husk-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func file(_ name: String, bytes: Int = 4096) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(repeating: 42, count: bytes).write(to: url)
        return url
    }
    func clean() { try? FileManager.default.removeItem(at: root) }
}

struct RemovalTests {
    @Test func nestedAndDuplicateSelectionsAreUnique() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let child = try fixture.file("child")
        let candidates = [fixture.root.path, child.path, child.path].map {
            RemovalCandidate(path: $0, bytes: 10, safety: .review, reason: "fixture")
        }
        let plan = RemovalPlan.prepare(candidates, title: "fixture")
        #expect(plan.entries.count == 1)
        #expect(plan.entries.first?.path == PathSafety.canonicalPath(fixture.root.path))
        #expect(plan.estimatedBytes == 10)
    }

    @Test func staleIdentityPreventsMove() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("changing")
        let plan = RemovalPlan.prepare([RemovalCandidate(path: file.path, bytes: 10, safety: .review, reason: "fixture")], title: "fixture")
        try Data(repeating: 43, count: 8192).write(to: file)
        let result = TrashService.execute(plan, move: { _ in Issue.record("Stale file was moved"); return file })
        #expect(result.successCount == 0)
        #expect(result.failures.count == 1)
    }

    @Test func symlinkSwapPreventsMove() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("changing")
        let plan = RemovalPlan.prepare([RemovalCandidate(path: file.path, bytes: 10, safety: .review, reason: "fixture")], title: "fixture")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: URL(fileURLWithPath: "/System"))
        let result = TrashService.execute(plan, move: { _ in Issue.record("Symlink was moved"); return file })
        #expect(result.successCount == 0)
        #expect(result.failures.count == 1)
    }

    @Test func runningOwnerAndExpiredReviewPreventMoves() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("owned")
        let candidate = RemovalCandidate(path: file.path, bytes: 10, safety: .review, reason: "fixture", ownerBundleID: "test.owner")
        #expect(RemovalPlan.prepare([candidate], title: "fixture", runningBundleIDs: ["test.owner"]).entries.isEmpty)
        let plan = RemovalPlan.prepare([candidate], title: "fixture")
        let running = TrashService.execute(plan, runningBundleIDs: ["test.owner"], move: { _ in Issue.record("Running app data moved"); return file })
        #expect(running.failures.count == 1)
        let expired = RemovalPlan(id: plan.id, createdAt: Date().addingTimeInterval(-301), title: plan.title, entries: plan.entries, skipped: [])
        #expect(TrashService.execute(expired).failures.count == 1)
    }

    @Test func mixedFailureAndCancellationAreReported() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let one = try fixture.file("a"), two = try fixture.file("b")
        let plan = RemovalPlan.prepare([one, two].map { RemovalCandidate(path: $0.path, bytes: 10, safety: .review, reason: "fixture") }, title: "fixture")
        let result = TrashService.execute(plan, move: { url in
            if url.lastPathComponent == two.lastPathComponent { throw CocoaError(.fileWriteNoPermission) }
            return fixture.root.appendingPathComponent("simulated-trash")
        })
        #expect(result.successCount == 1)
        #expect(result.totalBytes == 10)
        #expect(result.failures.count == 1)
        #expect(result.hasProblems)
        let cancelled = TrashService.execute(plan, shouldCancel: { true })
        #expect(cancelled.cancelled)
        #expect(cancelled.successCount == 0)
    }

    @Test func invalidAndProtectedPathsNeverReachMutation() {
        let plan = RemovalPlan.prepare(["relative", "/", "/System", NSHomeDirectory() + "/Library"].map {
            RemovalCandidate(path: $0, bytes: 10, safety: .safe, reason: "fixture")
        }, title: "fixture")
        #expect(plan.entries.isEmpty)
        #expect(plan.skipped.count == 4)
    }
}

struct RemovalGateTests {
    @Test func concurrentOperationsAndPlanReplayAreRejected() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("gate")
        let plan = RemovalPlan.prepare([RemovalCandidate(path: file.path, bytes: 10, safety: .review, reason: "fixture")], title: "fixture")
        let service = RemovalService(recordHistory: false, move: { url in
            usleep(200_000)
            return url.appendingPathExtension("simulated-trash")
        })
        let first = Task { try await service.execute(plan) }
        try await Task.sleep(for: .milliseconds(50))
        do { _ = try await service.execute(plan); Issue.record("Concurrent execution allowed") }
        catch RemovalError.busy { }
        #expect(try await first.value.successCount == 1)
        do { _ = try await service.execute(plan); Issue.record("Plan replay allowed") }
        catch RemovalError.busy { }
    }

    @Test func nestedSelectionCannotHideCautionRisk() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let child = try fixture.file("important")
        let plan = RemovalPlan.prepare([
            RemovalCandidate(path: fixture.root.path, bytes: 10, safety: .safe, reason: "parent"),
            RemovalCandidate(path: child.path, bytes: 10, safety: .caution, reason: "personal data")
        ], title: "fixture")
        #expect(plan.entries.count == 1)
        #expect(plan.hasCaution)
    }
}

struct ExclusionTests {
    @Test func excludedDescendantBlocksParentAtReviewAndExecution() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let child = try fixture.file("excluded")
        let candidate = RemovalCandidate(path: fixture.root.path, bytes: 10, safety: .review, reason: "fixture")
        let excluded = RemovalPlan.prepare([candidate], title: "fixture", excludedPaths: [child.path])
        #expect(excluded.entries.isEmpty)
        let plan = RemovalPlan.prepare([candidate], title: "fixture", excludedPaths: [])
        let result = TrashService.execute(plan, excludedPaths: [child.path], move: { url in
            Issue.record("Excluded parent was moved")
            return url
        })
        #expect(result.successCount == 0)
        #expect(result.failures.count == 1)
    }
}
