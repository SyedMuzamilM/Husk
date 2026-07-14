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
            rect: CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ForEach(rects) { rect in
                let isSelected = selectedID == rect.nodeID
                let color = Color.treemapPalette[rect.colorIndex % Color.treemapPalette.count]

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(isSelected ? 0.92 : 0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.primary.opacity(0.75) : Color.primary.opacity(0.10),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .overlay(alignment: .topLeading) {
                        if rect.width > 52, rect.height > 28 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rect.name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                Text(ByteFormat.string(for: rect.byteCount))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                            .padding(6)
                            .frame(maxWidth: rect.width - 4, alignment: .leading)
                        }
                    }
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelect(rect)
                        if rect.isDirectory {
                            onOpen(rect)
                        }
                    }
                    .onTapGesture(count: 1) {
                        onSelect(rect)
                    }
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
                    .accessibilityLabel("\(rect.name), \(ByteFormat.string(for: rect.byteCount))")
                    .accessibilityAddTraits(rect.isDirectory ? [.isButton] : [])
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
