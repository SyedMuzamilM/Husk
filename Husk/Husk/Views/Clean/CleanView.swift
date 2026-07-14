//
//  CleanView.swift
//  Husk
//

import AppKit
import SwiftUI

struct CleanView: View {
    @Bindable var model: CleanViewModel
    @Environment(PermissionService.self) private var permissions
    @State private var confirmTrash = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
            if showsBottomBar {
                bottomBar
            }
        }
        .confirmationDialog(
            "Move \(model.selectedItems.count) item(s) to Trash?",
            isPresented: $confirmTrash,
            titleVisibility: .visible
        ) {
            Button("Move \(ByteFormat.string(for: model.selectedBytes)) to Trash", role: .destructive) {
                Task { await model.moveSelectionToTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items go to Trash only — never permanently shredded.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .huskStartCleanScan)) { _ in
            if !model.isScanning { model.startScan() }
        }
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
                    Text("No husk found. Nice.")
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
        HStack(spacing: 12) {
            categoryList
                .frame(width: 280)
            detailPane
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.bottom, 8)
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CATEGORY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.huskTextMuted)
                Spacer()
                Text("SIZE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.huskTextMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Color.huskBorder)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.filteredCategories) { category in
                        ForEach(category.items) { item in
                            categoryRow(item)
                        }
                    }
                }
                .padding(8)
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

    private func categoryRow(_ item: CleanItem) -> some View {
        let selected = model.inspectedItem?.id == item.id
        return Button {
            model.inspect(item)
        } label: {
            HStack(spacing: 10) {
                Button {
                    model.toggle(item)
                } label: {
                    Image(systemName: model.selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.selectedIDs.contains(item.id) ? Color.huskPrimary : Color.huskTextMuted)
                }
                .buttonStyle(.plain)
                .disabled(!item.safety.isSelectable)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.huskText)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        SafetyBadge(label: item.safety)
                        Text(item.categoryName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.huskTextMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(ByteFormat.string(for: item.byteCount))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.huskPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.huskPrimary.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                confirmTrash = true
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
