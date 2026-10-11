import Foundation

struct OperationRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let title: String
    let destinations: [TrashDestination]
    let issues: [OperationIssue]
    let cancelled: Bool
}

actor OperationJournal {
    static let shared = OperationJournal()
    private let directory: URL
    private var file: URL { directory.appendingPathComponent("operations.json") }

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("Husk", isDirectory: true)) {
        self.directory = directory
    }

    private func checkPaths() throws {
        guard !PathSafety.hasUnsafeSymlink(directory.path), !PathSafety.hasUnsafeSymlink(file.path) else {
            throw RemovalError.changed("Operation history path is a symbolic link. History was not read or written.")
        }
    }

    func records() throws -> [OperationRecord] {
        try checkPaths()
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let size = try FileIdentity.read(file.path).size
        guard size < 8 * 1024 * 1024 else { throw RemovalError.changed("Operation history exceeds its size limit.") }
        let all = try JSONDecoder().decode([OperationRecord].self, from: Data(contentsOf: file))
        let retained = Array(all.filter { $0.date > Date().addingTimeInterval(-30 * 86400) }.prefix(100))
        if retained.count != all.count { try write(retained) }
        return retained
    }

    private func write(_ records: [OperationRecord]) throws {
        try checkPaths()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try JSONEncoder().encode(records)
        guard data.count < 8 * 1024 * 1024 else { throw RemovalError.changed("Operation history exceeds its size limit.") }
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    func record(plan: RemovalPlan, result: TrashResult) throws {
        guard UserDefaults.standard.object(forKey: "husk.keepOperationHistory") as? Bool != false else { return }
        let record = OperationRecord(id: plan.id, date: Date(), title: plan.title, destinations: result.destinations,
                                     issues: result.skipped + result.failures.map { OperationIssue(path: $0.path, message: $0.error) },
                                     cancelled: result.cancelled)
        try write(Array(([record] + (try records())).prefix(100)))
    }

    func clear() throws {
        try checkPaths()
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}
