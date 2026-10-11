//
//  TreemapView.swift
//  Husk
//

import AppKit
import SwiftUI

struct TreemapView: View {
    let nodes: [DiskNode]
    let size: CGSize
    let selectedID: UUID?
    let onSelect: (TreemapRect) -> Void
    let onOpen: (TreemapRect) -> Void

    private var rects: [TreemapRect] {
        TreemapLayout.squarify(
            nodes: nodes,
            rect: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(rects) { rect in
                let isSelected = selectedID == rect.nodeID
                let base = Color.treemapPalette[rect.colorIndex % Color.treemapPalette.count]
                Button { onSelect(rect) } label: {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(base)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.huskPrimary : Color.white.opacity(0.06),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                    .overlay(alignment: .topLeading) {
                        if rect.width > 100, rect.height > 54 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rect.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .lineLimit(1)
                                Text(ByteFormat.string(for: rect.byteCount))
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(Color.huskPrimary.opacity(0.95))
                            }
                            .padding(8)
                            .frame(maxWidth: rect.width - 6, alignment: .leading)
                        }
                    }
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                }.buttonStyle(.plain)
                    .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        onSelect(rect)
                        if rect.isDirectory { onOpen(rect) }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue(isSelected ? "Selected" : "")
                    .accessibilityLabel(rect.name + ", " + ByteFormat.string(for: rect.byteCount))
                    .accessibilityAction(named: "Select") { onSelect(rect) }
                    .accessibilityAction(named: "Open") { if rect.isDirectory { onOpen(rect) } }
                    .help("\(rect.name)\n\(rect.path)\n\(ByteFormat.string(for: rect.byteCount))")
                    .contextMenu {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: rect.path)])
                        }
                        if rect.isDirectory {
                            Button("Open Folder") {
                                onSelect(rect)
                                onOpen(rect)
                            }
                        }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(rect.path, forType: .string)
                        }
                    }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
