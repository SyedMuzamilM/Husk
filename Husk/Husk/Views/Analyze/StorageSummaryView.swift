import SwiftUI

struct StorageSummaryView: View {
    let capacity: DiskCapacity?
    let summary: StorageMapSummary
    let measuredBytes: Int64?
    let hasCleanupScan: Bool

    var body: some View {
        HStack(spacing: 0) {
            metric("Available now", value: capacity.map { ByteFormat.string(for: $0.availableBytes) } ?? "Unknown",
                   note: "Actual volume free space")
            Divider()
            metric("Regenerable caches", value: hasCleanupScan ? ByteFormat.string(for: summary.safeBytes) : "Not scanned",
                   note: "\(summary.safeItems.count) verified \(summary.safeItems.count == 1 ? "location" : "locations")", color: .safeLabel)
            Divider()
            metric("Needs review", value: hasCleanupScan ? ByteFormat.string(for: summary.reviewBytes) : "Not scanned",
                   note: "\(summary.reviewItems.count) \(summary.reviewItems.count == 1 ? "location" : "locations")", color: .reviewLabel)
            Divider()
            metric("Mapped here", value: measuredBytes.map { ByteFormat.string(for: $0) } ?? "Not scanned",
                   note: "Allocated size estimate")
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.huskSurface, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.huskBorder))
        .accessibilityElement(children: .contain)
    }

    private func metric(_ title: String, value: String, note: String, color: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label { Text(title).lineLimit(1) } icon: { Circle().fill(color).frame(width: 5, height: 5) }
                .font(.callout).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .monospaced).weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .accessibilityElement(children: .combine)
    }
}
