//
//  DiskNode.swift
//  Husk
//

import Foundation

struct DiskNode: Identifiable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let completeness: ScanCompleteness
    let omittedCount: Int
    let omittedBytes: Int64
    let issues: [OperationIssue]
    let byteCount: Int64
    let children: [DiskNode]

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        byteCount: Int64 = 0,
        children: [DiskNode] = [],
        completeness: ScanCompleteness = .complete,
        omittedCount: Int = 0, omittedBytes: Int64 = 0, issues: [OperationIssue] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.byteCount = byteCount
        self.children = children
        self.completeness = completeness
        self.omittedCount = omittedCount
        self.omittedBytes = omittedBytes
        self.issues = issues
    }

    var url: URL { URL(fileURLWithPath: path) }

    func sortedChildren(bySize: Bool = true) -> [DiskNode] {
        if bySize {
            return children.sorted { $0.byteCount > $1.byteCount }
        }
        return children.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }


}

struct TreemapRect: Identifiable, Equatable, Sendable {
    let id: UUID
    let nodeID: UUID
    let name: String
    let path: String
    let byteCount: Int64
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let colorIndex: Int
    let isDirectory: Bool
}
