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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(Color.huskPrimary)
                        Text(item.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.huskText)
                            .lineLimit(2)
                    }
                    Text(item.reason)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.huskTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(ByteFormat.string(for: item.byteCount))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.huskPrimary)
                    Text("TOTAL SIZE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.huskTextMuted)
                }
            }
            .padding(18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metaBlock
                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small).tint(Color.huskPrimary)
                            Text("Analyzing contents…")
                                .font(.caption)
                                .foregroundStyle(Color.huskTextMuted)
                        }
                    } else if let report {
                        breakdown(report)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            Divider().overlay(Color.huskBorder)

            HStack {
                Button("Reveal") { onReveal(item.path) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.huskTextSecondary)
                Spacer()
                Button(isSelected ? "Deselect" : "Select") {
                    onToggleSelect()
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundStyle(Color.huskPrimary)
                .disabled(!item.safety.isSelectable)
                Button("Exclude") {
                    UserDefaults.standard.set(ScanPreferences.excludedPaths + [item.path], forKey: "husk.excludedPaths")
                }
            }
            .padding(14)
        }
    }

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            labelBlock("WHY REMOVE THIS?", item.reason)
            labelBlock("PATH", item.path, mono: true)
            HStack(spacing: 16) {
                labelBlock("SAFETY", item.safety.title)
                if let c = item.entryCount {
                    labelBlock("ENTRIES", "\(c)")
                }
                if let m = item.modified {
                    labelBlock("MODIFIED", m.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.huskSurfaceHigh.opacity(0.55))
        )
    }

    private func breakdown(_ report: CacheDetailReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Size " + report.completeness.rawValue + " · Other: " + ByteFormat.string(for: report.omittedBytes)).font(.callout)
            ForEach(report.issues) { Text($0.message).font(.caption).foregroundStyle(.orange) }
            Text("LARGEST CONTENTS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.huskTextMuted)

            if report.topEntries.isEmpty {
                Text("No readable children.")
                    .font(.caption)
                    .foregroundStyle(Color.huskTextMuted)
            } else {
                ForEach(report.topEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.name)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.huskText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(ByteFormat.string(for: entry.byteCount))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.huskPrimary)
                        }
                        GeometryReader { geo in
                            let frac = report.totalBytes > 0
                                ? CGFloat(entry.byteCount) / CGFloat(report.totalBytes)
                                : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(Color.huskPrimary.opacity(0.75))
                                    .frame(width: max(4, geo.size.width * min(frac, 1)))
                            }
                        }
                        .frame(height: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onReveal(entry.path) }
                    .contextMenu {
                        Button("Reveal") { onReveal(entry.path) }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.path, forType: .string)
                        }
                    }
                }
            }
        }
    }

    private func labelBlock(_ title: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.huskTextMuted)
            Text(value)
                .font(mono ? .system(size: 11, design: .monospaced) : .system(size: 12))
                .foregroundStyle(Color.huskTextSecondary)
                .textSelection(.enabled)
                .lineLimit(mono ? 3 : 4)
        }
    }
}
