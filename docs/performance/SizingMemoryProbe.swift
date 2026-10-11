import Foundation
@main struct MemoryProbe {
    static func main() async throws {
        let path = CommandLine.arguments[1]
        let start = ContinuousClock.now
        let result = try await DirectorySizer.measure(URL(fileURLWithPath: path), useCache: false)
        print("visited=\(result.visitedEntries) status=\(result.status.rawValue) time=\(start.duration(to: .now))")
    }
}
