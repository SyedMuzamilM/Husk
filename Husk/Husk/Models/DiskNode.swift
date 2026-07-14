//
//  DiskNode.swift
//  Husk
//

import Foundation

final class DiskNode: Identifiable, @unchecked Sendable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    private(set) var byteCount: Int64
    private(set) var children: [DiskNode]

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        byteCount: Int64 = 0,
        children: [DiskNode] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.byteCount = byteCount
        self.children = children
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

    func addChild(_ child: DiskNode) {
        children.append(child)
        // Keep root total as sum of children for treemap share.
        byteCount += child.byteCount
    }

    func setByteCount(_ value: Int64) {
        byteCount = value
    }

    func finalizeSizeFromChildren() {
        guard isDirectory else { return }
        byteCount = children.reduce(0) { $0 + $1.byteCount }
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
