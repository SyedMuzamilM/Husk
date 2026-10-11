import Foundation

actor StubSystemMetricsService {
    func sample(topProcessLimit: Int) async -> (SystemSnapshot, [ProcessInfoRow]) {
        (SystemSnapshot(), [])
    }
    nonisolated static func terminate(pid: Int32, force: Bool) -> Bool { false }
}

@main
struct LifetimeProbe {
    @MainActor
    static func main() async throws {
        var owner: TestableStatusViewModel? = TestableStatusViewModel()
        weak var observed = owner
        owner?.start()
        try await Task.sleep(for: .milliseconds(100))
        owner = nil
        try await Task.sleep(for: .milliseconds(100))
        print("STATUS production loop retains model after owner release:", observed != nil)
        observed?.stop()
        try await Task.sleep(for: .milliseconds(100))
        print("STATUS model released after explicit stop:", observed == nil)
    }
}
