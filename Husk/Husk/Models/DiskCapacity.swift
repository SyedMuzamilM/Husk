import Foundation

struct DiskCapacity: Equatable, Sendable {
    let totalBytes: Int64
    let availableBytes: Int64
    var usedBytes: Int64 { max(0, totalBytes - availableBytes) }

    static func read(at path: String) async throws -> DiskCapacity {
        try await BlockingIO.run { _ in
            let values = try URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity else {
                throw CocoaError(.fileReadUnknown)
            }
            return DiskCapacity(totalBytes: Int64(total), availableBytes: Int64(available))
        }
    }
}
