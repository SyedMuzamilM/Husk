import Darwin
import Foundation

struct CommandResult: Sendable {
    let output: Data
    let errorOutput: Data
    let exitCode: Int32
    let timedOut: Bool
    let truncated: Bool
    var text: String { String(decoding: output, as: UTF8.self) }
}

/// Internal fixed commands only. Both pipes are drained while the child runs.
/// A dedicated worker owns launch, cancellation, termination, and reaping.
enum ProcessRunner {
    static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 5,
                    outputLimit: Int = 4 * 1024 * 1024, environment: [String: String]? = nil) async throws -> CommandResult {
        try await BlockingIO.run { flag in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment { process.environment = environment }
            let stdout = Pipe(), stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = FileHandle.nullDevice
            try process.run()
            stdout.fileHandleForWriting.closeFile()
            stderr.fileHandleForWriting.closeFile()
            let handles = [stdout.fileHandleForReading, stderr.fileHandleForReading]
            defer { handles.forEach { $0.closeFile() } }
            for handle in handles { _ = fcntl(handle.fileDescriptor, F_SETFL, O_NONBLOCK) }
            var buffers = [Data(), Data()]
            var ended = [false, false]
            var truncated = false
            var timedOut = false
            let began = ContinuousClock.now
            var stopTime: ContinuousClock.Instant?
            var bytes = [UInt8](repeating: 0, count: 16_384)
            while true {
                for index in 0..<2 where !ended[index] {
                    // Bound each pass so a continuously writing process cannot
                    // starve deadline/cancellation checks.
                    for _ in 0..<16 {
                        let count = Darwin.read(handles[index].fileDescriptor, &bytes, bytes.count)
                        if count > 0 {
                            let available = max(0, outputLimit - buffers[index].count)
                            buffers[index].append(contentsOf: bytes.prefix(min(count, available)))
                            if count > available { truncated = true }
                        } else {
                            if count == 0 { ended[index] = true }
                            break
                        }
                    }
                }
                let now = ContinuousClock.now
                if stopTime == nil && (flag.isCancelled || began.duration(to: now) > .seconds(timeout) || truncated) {
                    timedOut = !flag.isCancelled && !truncated
                    stopTime = now
                    if process.isRunning { process.terminate() }
                }
                if let stopTime, stopTime.duration(to: now) > .milliseconds(200) {
                    if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
                    break
                }
                if !process.isRunning && ended.allSatisfy({ $0 }) { break }
                usleep(10_000)
            }
            process.waitUntilExit()
            if flag.isCancelled { throw CancellationError() }
            return CommandResult(output: buffers[0], errorOutput: buffers[1], exitCode: process.terminationStatus,
                                 timedOut: timedOut, truncated: truncated)
        }
    }
}
