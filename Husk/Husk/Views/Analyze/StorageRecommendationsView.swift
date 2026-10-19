import SwiftUI

struct StorageRecommendationsView: View {
    @Bindable var model: CleanViewModel
    let onInspect: (CleanItem) -> Void
    @State private var filter = "All"

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recommendations").font(.headline)
                    Spacer()
                    if !model.categories.isEmpty {
                        Button("Rescan cleanup locations", systemImage: "arrow.clockwise") { model.startScan() }
                            .labelStyle(.iconOnly).disabled(model.isBusy)
                    }
                }
                Text("Known cleanup locations on this Mac.").font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            Divider()
            if case .failed(let message) = model.phase { HuskNotice(message: message, systemImage: "exclamationmark.triangle").padding(10) }
            if model.isScanning {
                ProgressView("Measuring cleanup locations…").padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
                Button("Cancel cleanup scan") { model.cancelScan() }.padding(16)
            } else if model.categories.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "checklist").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(model.lastResult == nil ? "Scan for cleanup options" : "No cleanup locations found").font(.headline)
                    Text("Folder size and color do not establish that a file is disposable.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Scan cleanup locations", systemImage: "magnifyingglass") { model.startScan() }.disabled(model.isBusy)
                }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Picker("Recommendations", selection: $filter) {
                    Text("All").tag("All"); Text("Caches").tag("Caches"); Text("Review").tag("Review")
                }.pickerStyle(.segmented).labelsHidden().padding(12)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filter != "Review" { section("Regenerable caches", items: model.storageSummary.safeItems, color: .safeLabel) }
                        if filter != "Caches" {
                            section("Review first", items: model.storageSummary.reviewItems, color: .reviewLabel)
                            section("Inspection only", items: model.storageSummary.inspectionItems, color: .secondary)
                        }
                    }
                }.frame(maxHeight: .infinity)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Text(ByteFormat.string(for: model.selectedBytes)).fontWeight(.semibold).monospacedDigit()
                        Text("selected · \(model.selectedItems.count) items").foregroundStyle(.secondary)
                        Spacer()
                        if !model.selectedItems.isEmpty { Button("Clear") { model.clearSelection() }.buttonStyle(.borderless).disabled(model.isBusy) }
                    }.font(.callout)
                    HStack {
                        Button("Select Safe") {
                            model.selectMapCaches()
                        }.disabled(model.isBusy || model.storageSummary.safeItems.isEmpty)
                        Spacer(minLength: 0)
                        Button("Review cleanup") { Task { await model.prepareRemoval() } }
                            .buttonStyle(.borderedProminent).disabled(model.selectedItems.isEmpty || model.isBusy)
                    }.controlSize(.small)
                    Text("Moves go to Trash. Space is released after Trash is emptied.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.huskSurface, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.huskBorder))
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder private func section(_ title: String, items: [CleanItem], color: Color) -> some View {
        if !items.isEmpty {
            HStack {
                Text(title).foregroundStyle(color)
                Spacer()
                Text(ByteFormat.string(for: items.reduce(0) { $0 + $1.byteCount })).monospacedDigit().foregroundStyle(.secondary)
            }.font(.caption).padding(.horizontal, 14).padding(.vertical, 8).background(Color.huskSurfaceLow)
            ForEach(items) { item in
                HStack(spacing: 9) {
                    Button {
                        model.toggle(item)
                    } label: {
                        Image(systemName: item.safety == .protected ? "lock" : model.selectedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.safety == .protected ? Color.secondary : Color.primary)
                    }.buttonStyle(.plain).disabled(!item.safety.isSelectable || model.isBusy)
                        .accessibilityLabel("Select " + item.name)
                        .accessibilityValue(model.selectedIDs.contains(item.id) ? "Selected" : "Not selected")
                    Button { onInspect(item) } label: {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.callout.weight(.medium)).lineLimit(1)
                                Text(item.path.replacingOccurrences(of: NSHomeDirectory(), with: "~", options: .anchored))
                                    .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                if item.completeness != .complete { Text("Partial estimate").font(.caption).foregroundStyle(Color.reviewLabel) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(ByteFormat.string(for: item.byteCount)).font(.callout.monospacedDigit()).lineLimit(1)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).help(item.reason + "\n" + item.path)
                }.padding(.horizontal, 14).padding(.vertical, 12)
                Divider()
            }
        }
    }
}
