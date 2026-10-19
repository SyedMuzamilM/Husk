import SwiftUI

struct TreemapView: View {
    let nodes: [DiskNode]
    let size: CGSize
    let selectedID: UUID?
    let colorMode: StorageMapColorMode
    let summary: StorageMapSummary
    let onSelect: (DiskNode) -> Void
    let onOpen: (DiskNode) -> Void

    var body: some View {
        let rects = TreemapLayout.squarify(nodes: nodes, rect: CGRect(origin: .zero, size: size))
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(rects) { rect in
                if let node = byID[rect.nodeID] {
                    TreemapGroupView(node: node, size: CGSize(width: max(0, rect.width - 4), height: max(0, rect.height - 4)),
                        selectedID: selectedID, colorMode: colorMode, summary: summary, onSelect: onSelect, onOpen: onOpen)
                        .frame(width: max(0, rect.width - 4), height: max(0, rect.height - 4))
                        .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
                }
            }
        }.frame(width: max(0, size.width), height: max(0, size.height))
    }
}
