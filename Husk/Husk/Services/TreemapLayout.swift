//
//  TreemapLayout.swift
//  Husk
//

import CoreGraphics
import Foundation

/// Squarified treemap (Bruls, Huizing & van Wijk).
enum TreemapLayout {
    static func squarify(nodes: [DiskNode], rect: CGRect) -> [TreemapRect] {
        let items = nodes.filter { $0.byteCount > 0 }.sorted { $0.byteCount > $1.byteCount }
        guard !items.isEmpty else { return [] }
        var result: [TreemapRect] = []
        pack(items: items, rect: rect, color: 0, into: &result)
        return result
    }

    private static func pack(
        items: [DiskNode],
        rect: CGRect,
        color: Int,
        into result: inout [TreemapRect]
    ) {
        guard !items.isEmpty, rect.width > 2, rect.height > 2 else { return }

        var remaining = items
        var free = rect
        var colorIndex = color

        while !remaining.isEmpty {
            let remainingSum = remaining.reduce(Int64(0)) { $0 + $1.byteCount }
            guard remainingSum > 0 else { break }

            var row: [DiskNode] = []
            var bestWorst: CGFloat = .greatestFiniteMagnitude

            while !remaining.isEmpty {
                var trial = row
                trial.append(remaining[0])
                let w = worstAspect(trial, free: free, remainingSum: remainingSum)
                if row.isEmpty || w <= bestWorst {
                    bestWorst = w
                    row = trial
                    remaining.removeFirst()
                } else {
                    break
                }
            }

            let rowSum = row.reduce(Int64(0)) { $0 + $1.byteCount }
            guard rowSum > 0 else { break }

            let isHorizontal = free.width >= free.height
            let rowFraction = CGFloat(rowSum) / CGFloat(remainingSum)

            if isHorizontal {
                let rowWidth = free.width * rowFraction
                var y = free.minY
                for node in row {
                    let h = free.height * CGFloat(node.byteCount) / CGFloat(rowSum)
                    result.append(
                        makeRect(
                            node: node,
                            x: free.minX,
                            y: y,
                            width: max(rowWidth, 0),
                            height: max(h, 0),
                            colorIndex: colorIndex
                        )
                    )
                    colorIndex += 1
                    y += h
                }
                free.origin.x += rowWidth
                free.size.width = max(free.width - rowWidth, 0)
            } else {
                let rowHeight = free.height * rowFraction
                var x = free.minX
                for node in row {
                    let w = free.width * CGFloat(node.byteCount) / CGFloat(rowSum)
                    result.append(
                        makeRect(
                            node: node,
                            x: x,
                            y: free.minY,
                            width: max(w, 0),
                            height: max(rowHeight, 0),
                            colorIndex: colorIndex
                        )
                    )
                    colorIndex += 1
                    x += w
                }
                free.origin.y += rowHeight
                free.size.height = max(free.height - rowHeight, 0)
            }
        }
    }

    private static func makeRect(
        node: DiskNode,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        colorIndex: Int
    ) -> TreemapRect {
        TreemapRect(
            id: UUID(),
            nodeID: node.id,
            name: node.name,
            path: node.path,
            byteCount: node.byteCount,
            x: x,
            y: y,
            width: width,
            height: height,
            colorIndex: colorIndex % 8,
            isDirectory: node.isDirectory
        )
    }

    private static func worstAspect(_ row: [DiskNode], free: CGRect, remainingSum: Int64) -> CGFloat {
        let rowSum = row.reduce(Int64(0)) { $0 + $1.byteCount }
        guard rowSum > 0, remainingSum > 0 else { return .greatestFiniteMagnitude }
        let side = min(free.width, free.height)
        guard side > 0 else { return .greatestFiniteMagnitude }

        let area = free.width * free.height * CGFloat(rowSum) / CGFloat(remainingSum)
        let rowSide = area / side
        var worst: CGFloat = 0
        for n in row {
            let a = area * CGFloat(n.byteCount) / CGFloat(rowSum)
            let other = a / max(rowSide, 0.001)
            let ratio = max(rowSide / max(other, 0.001), other / max(rowSide, 0.001))
            worst = max(worst, ratio)
        }
        return worst
    }
}
