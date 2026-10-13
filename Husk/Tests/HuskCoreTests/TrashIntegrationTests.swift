import Foundation
import Testing
@testable import HuskCore

struct TrashIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["HUSK_RUN_TRASH_INTEGRATION"] == "1"))
    func disposableFileMovesThroughRealTrashAndCanBeRestored() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let original = try fixture.file("Husk-integration-\(UUID().uuidString)")
        let payload = try Data(contentsOf: original)
        let plan = RemovalPlan.prepare([
            RemovalCandidate(path: original.path, bytes: Int64(payload.count), safety: .caution,
                             reason: "Disposable integration fixture")
        ], title: "Fixture", excludedPaths: [])
        #expect(plan.entries.count == 1)
        let result = TrashService.execute(plan, excludedPaths: [])
        let destination = try #require(result.destinations.first)
        let trashed = URL(fileURLWithPath: destination.trashPath)
        // Recovery is limited to the destination returned for our new fixture.
        defer {
            if FileManager.default.fileExists(atPath: trashed.path),
               !FileManager.default.fileExists(atPath: original.path) {
                try? FileManager.default.moveItem(at: trashed, to: original)
            }
        }
        #expect(!result.hasProblems)
        #expect(!FileManager.default.fileExists(atPath: original.path))
        #expect(try Data(contentsOf: trashed) == payload)
        try FileManager.default.moveItem(at: trashed, to: original)
        #expect(try Data(contentsOf: original) == payload)
        #expect(!FileManager.default.fileExists(atPath: trashed.path))
    }
}
