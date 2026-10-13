import Foundation

enum ScanCompleteness: String, Codable, Sendable {
    case complete, partial, unavailable
}

struct SizeMeasurement: Sendable {
    var bytes: Int64 = 0
    var modified: Date? = nil
    var status: ScanCompleteness = .complete
    var issues: [OperationIssue] = []
    var visitedEntries = 0
    var totalIssueCount = 0

    mutating func note(_ path: String, _ message: String) {
        status = .partial
        totalIssueCount += 1
        if issues.count < 50 { issues.append(OperationIssue(path: path, message: message)) }
    }
}

struct ChildMeasurement: Identifiable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let measurement: SizeMeasurement
    var bytes: Int64 { measurement.bytes }
}

struct DirectoryListing: Sendable {
    let children: [ChildMeasurement]
    var total: SizeMeasurement
    let omittedBytes: Int64
    let omittedCount: Int
}
