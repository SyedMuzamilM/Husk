//
//  CacheDetailPanel.swift
//  Husk
//

import AppKit
import SwiftUI

struct CacheDetailPanel: View {
    let item: CleanItem
    let report: CacheDetailReport?
    let isLoading: Bool
    var onReveal: (String) -> Void
    var onToggleSelect: () -> Void
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache details")
                        .font(.headline)
                    Text(item.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer()
                SafetyBadge(label: item.safety)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryBlock
                    if isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing contents…")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let report {
                        breakdownBlock(report)
                    }
                }
                .padding(16)
            }

            Divider()
            HStack {
                Button("Reveal in Finder") {
                    onReveal(item.path)
                }
                Button(isSelected ? "Deselect" : "Select for Trash") {
                    onToggleSelect()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Path", item.path, mono: true)
            detailRow("Size", ByteFormat.string(for: item.byteCount))
            detailRow("Category", item.categoryName)
            detailRow("Why", item.reason)
            if let modified = item.modified {
                detailRow(
                    "Modified",
                    modified.formatted(date: .abbreviated, time: .shortened)
                )
            }
            if let report {
                detailRow("Immediate items", "\(report.immediateChildren) (\(report.folderCountApprox) folders · \(report.fileCountApprox) files)")
                if let mod = report.modified, item.modified == nil {
                    detailRow("Modified", mod.formatted(date: .abbreviated, time: .shortened))
                }
            }
            if let count = item.entryCount {
                detailRow("Top-level entries", "\(count)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func breakdownBlock(_ report: CacheDetailReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Largest contents")
                .font(.subheadline.weight(.semibold))
            Text("Top \(report.topEntries.count) items inside this path (one level).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if report.topEntries.isEmpty {
                Text("No readable children.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.topEntries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            if let c = entry.childCount {
                                Text("\(c) items inside")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Text(ByteFormat.string(for: entry.byteCount))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Reveal") { onReveal(entry.path) }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.path, forType: .string)
                        }
                    }
                    .onTapGesture(count: 2) {
                        onReveal(entry.path)
                    }

                    // Share bar
                    GeometryReader { geo in
                        let fraction = report.totalBytes > 0
                            ? CGFloat(entry.byteCount) / CGFloat(report.totalBytes)
                            : 0
                        Capsule()
                            .fill(Color.accentColor.opacity(0.25))
                            .frame(width: max(4, geo.size.width * min(fraction, 1)), height: 4)
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .caption.monospaced() : .callout)
                .textSelection(.enabled)
                .lineLimit(mono ? 3 : 4)
            }
    }
}
