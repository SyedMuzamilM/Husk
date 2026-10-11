import AppKit
import SwiftUI

struct CacheDetailPanel: View {
    let item: CleanItem
    let report: CacheDetailReport?
    let isLoading: Bool
    var onReveal: (String) -> Void
    var onToggleSelect: () -> Void
    var isSelected: Bool
    @State private var excluded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(item.name).font(.title3.weight(.semibold)).textSelection(.enabled)
                    Text(ByteFormat.string(for: item.byteCount)).font(.title2.weight(.semibold)).monospacedDigit()
                    SafetyBadge(label: item.safety)
                    Text(item.reason).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location").font(.headline)
                        Text(item.path).font(.body.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                    LabeledContent("Size coverage", value: item.completeness.rawValue)
                    if let date = item.modified { LabeledContent("Modified", value: date.formatted(date: .abbreviated, time: .omitted)) }
                    Divider()
                    if isLoading { ProgressView("Measuring contents…") }
                    else if let report { breakdown(report) }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            VStack(spacing: 10) {
                HStack {
                    Button("Reveal", systemImage: "folder") { onReveal(item.path) }
                    Spacer()
                    Button(isSelected ? "Deselect" : "Select") { onToggleSelect() }.disabled(!item.safety.isSelectable || excluded)
                }
                Button(excluded ? "Excluded from future scans" : "Exclude from future scans", systemImage: "eye.slash") {
                    UserDefaults.standard.set(Array(Set(ScanPreferences.excludedPaths + [item.path])).sorted(), forKey: "husk.excludedPaths")
                    if isSelected { onToggleSelect() }
                    excluded = true
                    Task { await SizeCache.shared.clear() }
                }.disabled(excluded).frame(maxWidth: .infinity)
            }.padding(14)
        }
        .onChange(of: item.id, initial: true) { excluded = ScanPreferences.isExcluded(item.path) }
    }
    private func breakdown(_ report: CacheDetailReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Largest contents").font(.headline)
            Text("\(report.completeness.rawValue.capitalized) · Other \(ByteFormat.string(for: report.omittedBytes))").font(.callout).foregroundStyle(.secondary)
            ForEach(report.issues) { Text($0.message).font(.callout).foregroundStyle(.secondary) }
            if report.topEntries.isEmpty { Text("No readable children.").foregroundStyle(.secondary) }
            ForEach(report.topEntries) { entry in
                Button { onReveal(entry.path) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.name).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(ByteFormat.string(for: entry.byteCount)).monospacedDigit()
                        }
                        ProgressView(value: report.totalBytes > 0 ? min(1, Double(entry.byteCount) / Double(report.totalBytes)) : 0)
                            .tint(Color.huskPrimary).accessibilityHidden(true)
                    }
                }.buttonStyle(.plain).help("Reveal " + entry.path)
                    .accessibilityLabel("Reveal " + entry.name + ", " + ByteFormat.string(for: entry.byteCount))
            }
        }
    }
}
