import Foundation
@main struct MemoryProbe {
    static func main() async throws {
        let path = CommandLine.arguments[1]
        let start = ContinuousClock.now
        if CommandLine.arguments.dropFirst(2).contains("--listing") {
            let result = try await DirectorySizer.listing(of: URL(fileURLWithPath: path))
            print("visited=\(result.total.visitedEntries) status=\(result.total.status.rawValue) shown=\(result.children.count) omitted=\(result.omittedCount) time=\(start.duration(to: .now))")
            return
        }
        let result = try await DirectorySizer.measure(URL(fileURLWithPath: path), useCache: false)
        print("visited=\(result.visitedEntries) status=\(result.status.rawValue) time=\(start.duration(to: .now))")
    }
}
