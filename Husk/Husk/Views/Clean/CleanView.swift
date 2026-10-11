//
//  CleanView.swift
//  Husk
//

import AppKit
import SwiftUI

struct CleanView: View {
    @Bindable var model: CleanViewModel
    @Environment(PermissionService.self) private var permissions
    @State private var inspectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let error = model.removalError { Text(error).foregroundStyle(.orange).textSelection(.enabled).padding(.horizontal) }
            if let issues = model.lastResult?.coverageIssues, !issues.isEmpty {
                DisclosureGroup("Scan coverage: \(issues.count) issues") {
                    ForEach(issues) { Text($0.path + " · " + $0.message).font(.caption).textSelection(.enabled) }
                }.foregroundStyle(.orange).padding(.horizontal, HuskTheme.contentPadding)
            }
            content
            if showsBottomBar {
                bottomBar
            }
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.moveSelectionToTrash(frozen) } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }

    }

    private var showsBottomBar: Bool {
        !model.categories.isEmpty && !model.isScanning
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskTextMuted)
                    .lineLimit(1)
            }
            Spacer()
            if !permissions.hasFullDiskAccess {
                Button {
                    permissions.openFullDiskAccessSettings()
                } label: {
                    Label("Full Disk Access", systemImage: "lock.open")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().strokeBorder(Color.huskBorder))
                        .foregroundStyle(Color.huskTextSecondary)
                }
                .buttonStyle(.plain)
            }
            if model.isScanning {
                Button("Cancel") { model.cancelScan() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.huskTextSecondary)
            } else if !model.categories.isEmpty {
                Button {
                    model.startScan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.huskSurfaceHigh))
                        .foregroundStyle(Color.huskText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var titleText: String {
        switch model.phase {
        case .idle, .scanning: return "Clean"
        default: return "Caches & Derived Data"
        }
    }

    private var subtitleText: String {
        switch model.phase {
        case .idle:
            return "Peel regenerable clutter. Preview every path. Trash only."
        case .scanning(let p):
            return "Scanning… \(Int(p.fraction * 100))% · \(p.itemsFound) items · \(ByteFormat.string(for: p.bytesFound))"
        case .ready:
            if let r = model.lastResult {
                return "Review items ready for pruning · \(ByteFormat.string(for: r.totalBytes)) found in \(String(format: "%.1f", r.duration))s"
            }
            return "Review items ready for pruning."
        case .trashing:
            return "Moving to Trash…"
        case .finished(let b, let n):
            return "Moved \(n) item(s) · \(ByteFormat.string(for: b)) to Trash"
        case .failed(let m):
            return m
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            heroReady
        case .scanning(let progress):
            heroScanning(progress)
        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.cautionLabel)
                Text(message).foregroundStyle(Color.huskTextSecondary)
                HuskPillButton(title: "Try Again", systemImage: "arrow.clockwise") {
                    model.startScan()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .trashing:
            ProgressView("Moving to Trash…")
                .tint(Color.huskPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            if model.categories.isEmpty {
                VStack(spacing: 12) {
                    Text("No items found in measured locations.")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.huskText)
                    HuskPillButton(title: "Scan Again", systemImage: "arrow.clockwise") {
                        model.startScan()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsLayout
            }
        }
    }

    private var heroReady: some View {
        VStack(spacing: 20) {
            Spacer()
            HuskBrandMark(size: 148, showGlow: true, glowRadius: 36)
            Text("Ready to peel.")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.huskText)
            Text("Caches, AI agents, node_modules, DerivedData — regenerable clutter only.")
                .font(.system(size: 13))
                .foregroundStyle(Color.huskTextMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Text("NOTHING DELETED UNTIL YOU SELECT IT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.huskTextMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().strokeBorder(Color.huskBorder))
            HuskPillButton(title: "Scan", systemImage: "sparkle.magnifyingglass") {
                model.startScan()
            }
            .padding(.top, 4)
            Spacer()
            Text("ZERO TELEMETRY · LOCAL ONLY · TRASH ONLY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color.huskTextMuted.opacity(0.7))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heroScanning(_ progress: CleanScanProgress) -> some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView(value: progress.fraction)
                .tint(Color.huskPrimary)
                .frame(width: 280)
            Text("\(Int(progress.fraction * 100))%")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.huskPrimary)
            Text(progress.currentPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.huskTextMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Text("\(progress.itemsFound) items · \(ByteFormat.string(for: progress.bytesFound))")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.huskTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results (stitch-inspired split)

    private var resultsLayout: some View {
        HSplitView {
            categoryList
                .frame(minWidth: 440, idealWidth: 510)
            detailPane
                .frame(minWidth: 230, maxWidth: .infinity)
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.bottom, 8)
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            // 1. Search Bar: A subtle dark textfield for matching paths and names on-the-fly.
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.huskTextMuted)
                TextField("Search caches, paths…", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskText)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.huskTextMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.huskSurfaceHigh.opacity(0.6)))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // 2. Filter Chips: Horizontal pills representing different cache groups.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CleanFilter.allCases) { filter in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                model.selectedFilter = filter
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filter.systemImage)
                                    .font(.system(size: 9))
                                Text(filter.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(model.selectedFilter == filter ? Color.huskPrimary : Color.huskSurfaceHigh.opacity(0.8))
                            )
                            .foregroundStyle(model.selectedFilter == filter ? Color.huskOnPrimary : Color.huskTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider().overlay(Color.huskBorder)

            // 3. Header & Sort Options: Displays number of items and sort trigger.
            HStack {
                Text("\(model.filteredItems.count) ITEMS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.huskTextMuted)
                Spacer()
                Menu {
                    Picker("Sort By", selection: $model.sortOption) {
                        ForEach(CleanSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(model.sortOption.rawValue)
                        Image(systemName: "arrow.up.and.down.text.left.to.right")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.huskTextSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(Color.huskBorder)

            Table(model.filteredItems, selection: $inspectedID) {
                TableColumn("Select") { item in
                    Toggle("Select " + item.name, isOn: Binding(
                        get: { model.selectedIDs.contains(item.id) },
                        set: { _ in model.toggle(item) }
                    )).labelsHidden().disabled(!item.safety.isSelectable)
                }.width(45)
                TableColumn("Item") { item in
                    VStack(alignment: .leading) {
                        Text(item.name).lineLimit(1)
                        Text(item.categoryName).font(.caption).foregroundStyle(.secondary)
                    }
                }.width(min: 130, ideal: 190)
                TableColumn("Size") { item in
                    VStack(alignment: .trailing) {
                        Text(ByteFormat.string(for: item.byteCount)).monospacedDigit()
                        if item.completeness != .complete { Text(item.completeness.rawValue).font(.caption) }
                    }
                }.width(90)
                TableColumn("Risk") { item in SafetyBadge(label: item.safety) }.width(80)
            }
            .onChange(of: inspectedID) { _, id in
                if let item = model.filteredItems.first(where: { $0.id == id }) { model.inspect(item) }
            }

        }
        .background(
            RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                .fill(Color.huskSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                        .strokeBorder(Color.huskBorder)
                )
        )
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = model.inspectedItem {
            CacheDetailPanel(
                item: item,
                report: model.cacheDetail,
                isLoading: model.isLoadingDetail,
                onReveal: { path in
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                },
                onToggleSelect: { model.toggle(item) },
                isSelected: model.selectedIDs.contains(item.id)
            )
            .background(
                RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                    .fill(Color.huskSurface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                            .strokeBorder(Color.huskBorder)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.huskTextMuted)
                Text("Select an item")
                    .font(.headline)
                    .foregroundStyle(Color.huskText)
                Text("Inspect path, safety, and largest contents before peeling.")
                    .font(.caption)
                    .foregroundStyle(Color.huskTextMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                    .fill(Color.huskSurface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                            .strokeBorder(Color.huskBorder)
                    )
            )
        }
    }

    private var bottomBar: some View {
        HStack {
            Text("\(ByteFormat.string(for: model.selectedBytes)) SELECTED")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.huskTextMuted)
            Text("· \(model.selectedItems.count) items")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.huskTextSecondary)
            Spacer()
            Button("Select Safe") { model.selectAllSafe() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.huskTextSecondary)
            Button("Clear") { model.clearSelection() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.huskTextSecondary)
                .disabled(model.selectedIDs.isEmpty)
            HuskPillButton(
                title: "Move to Trash",
                systemImage: "trash",
                prominent: true
            ) {
                Task { await model.prepareRemoval() }
            }
            .opacity(model.selectedItems.isEmpty ? 0.45 : 1)
            .disabled(model.selectedItems.isEmpty || model.isBusy)
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.vertical, 14)
        .background(Color.huskSurfaceLow.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.huskBorder).frame(height: 1)
        }
    }
}
