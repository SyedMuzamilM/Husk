import Foundation
import Testing
@testable import HuskCore

struct BenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["HUSK_RUN_BENCHMARKS"] == "1"))
    func metadataTraversalAndCancellation() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for count in [10_000, 100_000] {
            let directory = fixture.root.appendingPathComponent("count-\(count)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for index in 0..<count {
                let file = directory.appendingPathComponent("file-\(index)")
                #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
            }
            for pass in 1...2 {
                let began = ContinuousClock.now
                let measurement = try await DirectorySizer.measure(directory, useCache: false)
                print("BENCH count=\(count) pass=\(pass) elapsed=\(began.duration(to: .now)) visited=\(measurement.visitedEntries) coverage=\(measurement.status.rawValue)")
                #expect(measurement.visitedEntries == count || measurement.status == .partial)
            }
            let task = Task { try await DirectorySizer.measure(directory, useCache: false) }
            try await Task.sleep(for: .milliseconds(25))
            let cancelledAt = ContinuousClock.now
            task.cancel()
            do { _ = try await task.value; Issue.record("Cancelled traversal returned success") }
            catch is CancellationError {
                print("BENCH count=\(count) cancellation=\(cancelledAt.duration(to: .now))")
            }
        }
    }
}
