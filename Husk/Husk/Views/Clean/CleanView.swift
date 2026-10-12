import AppKit
import SwiftUI

struct CleanView: View {
    @Bindable var model: CleanViewModel
    @State private var inspectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Cleanup", subtitle: subtitle) {
                if model.isScanning { Button("Cancel") { model.cancelScan() } }
                else if !model.categories.isEmpty { Button("Rescan", systemImage: "arrow.clockwise") { model.startScan() }.disabled(model.isBusy) }
            }
            if let error = model.removalError { HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, HuskTheme.contentPadding) }
            if let issues = model.lastResult?.coverageIssues, !issues.isEmpty {
                DisclosureGroup("\(issues.count) scan coverage issues") {
                    ScrollView { ForEach(issues) { Text($0.path + " · " + $0.message).font(.callout).textSelection(.enabled) } }.frame(maxHeight: 100)
                }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, 12)
            }
            content
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.moveSelectionToTrash(frozen) } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }
    }

    private var subtitle: String {
        switch model.phase {
        case .idle: "Find caches and build data. You review every removal."
        case .scanning: "Measuring known locations. Your files stay in place."
        case .ready: "\(ByteFormat.string(for: model.totalBytes)) measured across \(model.categories.flatMap(\.items).count) locations."
        case .trashing: "Moving the reviewed selection to Trash."
        case .finished(let bytes, let count): "Moved \(count) items to Trash, about \(ByteFormat.string(for: bytes))."
        case .failed(let message): message
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                HuskBrandMark(size: 148, showGlow: true, glowRadius: 36).accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text("Ready to peel.").font(.system(size: 30, weight: .semibold))
                    Text("Find regenerable caches and build data.\nReview every path before cleanup.")
                        .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Label("Nothing moves until you review it", systemImage: "checkmark.shield")
                    .font(.callout).foregroundStyle(Color.huskAccentText)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.huskPrimary.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.huskPrimary.opacity(0.2)))
                HuskPillButton(title: "Scan storage", systemImage: "sparkle.magnifyingglass") { model.startScan() }
                    .padding(.top, 10)
                Spacer(minLength: 20)
                Text("LOCAL SCANS  ·  TRASH ONLY  ·  NO TELEMETRY")
                    .font(.caption.weight(.medium)).tracking(1).foregroundStyle(.secondary)
                    .padding(.bottom, 28)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning(let progress):
            VStack(alignment: .leading, spacing: 18) {
                Label("Scanning storage", systemImage: "magnifyingglass").font(.title2.weight(.semibold))
                ProgressView(value: progress.fraction).tint(Color.huskPrimary)
                Text("\(Int(progress.fraction * 100))% · \(progress.itemsFound) locations · \(ByteFormat.string(for: progress.bytesFound))").monospacedDigit()
                Text(progress.currentPath).font(.body.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }.padding(32).frame(maxWidth: 520).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .trashing:
            ProgressView("Moving reviewed items to Trash…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Scan could not finish", systemImage: "exclamationmark.triangle")
            } description: { Text(message) } actions: {
                Button("Try again") { model.startScan() }
            }
        default:
            results
        }
    }

    private var results: some View {
        VStack(spacing: 14) {
            HuskSplitView {
                VStack(spacing: 12) {
                    HuskSearchField(prompt: "Search caches or paths", text: $model.searchText)
                    Picker("Category", selection: $model.selectedFilter) {
                        ForEach(CleanFilter.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                    HStack {
                        Text("\(model.filteredItems.count) locations").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Sort", selection: $model.sortOption) {
                            ForEach(CleanSortOption.allCases) { Text($0.rawValue).tag($0) }
                        }.frame(width: 135)
                    }
                    Table(model.filteredItems, selection: $inspectedID) {
                        TableColumn("Select") { item in
                            Toggle("Select " + item.name, isOn: Binding(get: { model.selectedIDs.contains(item.id) }, set: { _ in model.toggle(item) }))
                                .labelsHidden().disabled(!item.safety.isSelectable || model.isBusy)
                        }.width(45)
                        TableColumn("Item") { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).lineLimit(1)
                                Text(item.categoryName).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                            }.padding(.vertical, 4)
                        }.width(min: 120, ideal: 170)
                        TableColumn("Size") { item in
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteFormat.string(for: item.byteCount)).monospacedDigit()
                                if item.completeness != .complete { Text(item.completeness.rawValue).font(.callout).foregroundStyle(.secondary) }
                            }
                        }.width(95)
                        TableColumn("Risk") { item in SafetyBadge(label: item.safety) }.width(85)
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: inspectedID) { _, id in
                        if let item = model.filteredItems.first(where: { $0.id == id }) { model.inspect(item) }
                        else { model.clearInspection() }
                    }
                    .overlay {
                        if model.filteredItems.isEmpty {
                            ContentUnavailableView("No matching items", systemImage: "magnifyingglass", description: Text("Change your search or category, or rescan storage."))
                        }
                    }
                }.padding(12)
                .background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: HuskTheme.cardRadius).strokeBorder(Color.huskBorder))
                .frame(minWidth: 460, idealWidth: 490, maxHeight: .infinity)
                inspector.frame(minWidth: 240, idealWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 12) {
                Image(systemName: "tray.full").font(.title2).foregroundStyle(Color.huskAccentText)
                    .frame(width: 44, height: 44).background(Color.huskPrimary.opacity(0.08), in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ByteFormat.string(for: model.selectedBytes)) selected").font(.headline)
                    Text("\(model.selectedItems.count) items · allocated estimate").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select Safe") { model.selectAllSafe() }.disabled(model.isBusy)
                Button("Clear") { model.clearSelection() }.disabled(model.selectedIDs.isEmpty || model.isBusy)
                HuskPillButton(title: "Review cleanup", systemImage: "trash") { Task { await model.prepareRemoval() } }
                    .disabled(model.selectedItems.isEmpty || model.isBusy)
            }.padding(16).background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
        }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
    }

    @ViewBuilder private var inspector: some View {
        if let item = model.inspectedItem {
            CacheDetailPanel(item: item, report: model.cacheDetail, isLoading: model.isLoadingDetail,
                onReveal: { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: $0)]) },
                onToggleSelect: { model.toggle(item) }, isSelected: model.selectedIDs.contains(item.id))
                .background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
        } else {
            ContentUnavailableView("Inspect an item", systemImage: "sidebar.trailing", description: Text("Select a row to review its path, risk and largest contents."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
        }
    }
}
