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
    let isAggregate: Bool

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        byteCount: Int64 = 0,
        children: [DiskNode] = [],
        completeness: ScanCompleteness = .complete,
        omittedCount: Int = 0, omittedBytes: Int64 = 0, issues: [OperationIssue] = [], isAggregate: Bool = false
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
        self.isAggregate = isAggregate
    }

    var url: URL { URL(fileURLWithPath: path) }

    var mapChildren: [DiskNode] {
        let remainder = max(0, byteCount - children.reduce(0) { $0 + $1.byteCount })
        guard remainder > 0, !children.isEmpty || omittedBytes > 0 else { return children }
        var stableID = id.uuid
        stableID.0 ^= 0xff
        return children + [DiskNode(id: UUID(uuid: stableID), name: "Other & unmeasured", path: path,
            isDirectory: false, byteCount: remainder, completeness: .partial, isAggregate: true)]
    }

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
