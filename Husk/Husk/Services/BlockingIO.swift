import Foundation

/// Foundation filesystem calls are synchronous. Keep them off Swift's cooperative
/// executors and impose one process-wide concurrency limit for all scanners.
enum BlockingIO {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "dev.mzml.Husk.filesystem"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    static func run<T: Sendable>(
        _ operation: @escaping @Sendable (CancelFlag) throws -> T
    ) async throws -> T {
        let flag = CancelFlag()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.addOperation {
                    do {
                        if flag.isCancelled { throw CancellationError() }
                        continuation.resume(returning: try operation(flag))
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { flag.cancel() }
    }
}
