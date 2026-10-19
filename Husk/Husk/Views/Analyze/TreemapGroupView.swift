import AppKit
import SwiftUI

struct TreemapGroupView: View {
    let node: DiskNode
    let size: CGSize
    let selectedID: UUID?
    let colorMode: StorageMapColorMode
    let summary: StorageMapSummary
    let onSelect: (DiskNode) -> Void
    let onOpen: (DiskNode) -> Void
    @Environment(\.colorScheme) private var scheme

    private var color: Color { colorMode.color(for: node, summary: summary) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(scheme == .dark ? 0.20 : 0.10))
            if size.width > 75, size.height > 72, !node.children.isEmpty {
                Button { onOpen(node) } label: {
                    HStack(spacing: 4) {
                        Text(node.name).font(.caption.weight(.medium)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(ByteFormat.string(for: node.byteCount)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                    }.padding(.horizontal, 7).frame(height: 26).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open " + node.path).accessibilityLabel("Open " + node.name)
                let children = node.mapChildren
                let byID = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
                let rects = TreemapLayout.squarify(nodes: children, rect: CGRect(x: 3, y: 27, width: max(0, size.width - 6), height: max(0, size.height - 30)))
                ForEach(rects) { rect in
                    if let child = byID[rect.nodeID] {
                        tile(child, size: CGSize(width: max(0, rect.width - 3), height: max(0, rect.height - 3)))
                            .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
                    }
                }
            } else {
                tile(node, size: size)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selectedID == node.id ? Color.huskPrimary : color.opacity(0.4), lineWidth: selectedID == node.id ? 2 : 1))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func tile(_ item: DiskNode, size: CGSize) -> some View {
        let tint = colorMode.color(for: item, summary: summary)
        return Button { onSelect(item) } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5).fill(tint.opacity(scheme == .dark ? 0.32 : 0.14))
                if summary.safety(for: item.path) == .safe, !item.isAggregate {
                    Canvas { context, bounds in
                        var lines = Path()
                        for offset in stride(from: -bounds.height, through: bounds.width, by: 8) {
                            lines.move(to: CGPoint(x: offset, y: bounds.height))
                            lines.addLine(to: CGPoint(x: offset + bounds.height, y: 0))
                        }
                        context.stroke(lines, with: .color(Color.safeLabel.opacity(0.28)), lineWidth: 1)
                    }.clipShape(.rect(cornerRadius: 5)).accessibilityHidden(true)
                }
                if size.width > 52, size.height > 32 {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 1)
                        if size.height > 46 {
                            Text(ByteFormat.string(for: item.byteCount))
                                .font(.system(size: size.width > 110 && size.height > 100 ? 17 : 12, weight: .medium, design: .monospaced))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }.padding(7)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selectedID == item.id ? Color.huskPrimary : tint.opacity(0.35), lineWidth: selectedID == item.id ? 2 : 1))
            .frame(width: max(0, size.width), height: max(0, size.height)).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onKeyPress(.return) {
            guard item.isDirectory, !item.isAggregate else { return .ignored }
            onOpen(item)
            return .handled
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { if item.isDirectory && !item.isAggregate { onOpen(item) } })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name + ", " + ByteFormat.string(for: item.byteCount) + ", " + item.completeness.rawValue)
        .accessibilityValue(selectedID == item.id ? "Selected" : "")
        .accessibilityAction(named: "Open folder") { if item.isDirectory && !item.isAggregate { onOpen(item) } }
        .help(item.name + "\n" + item.path + "\n" + ByteFormat.string(for: item.byteCount))
        .contextMenu {
            if !item.isAggregate {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                if item.isDirectory { Button("Open folder") { onOpen(item) } }
                Button("Copy path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.path, forType: .string) }
            }
        }
    }
}
