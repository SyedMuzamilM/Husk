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
            header
            if case .scanning(let progress) = model.phase {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            Divider()
            content
            Divider()
            bottomBar
        }
        .navigationTitle("Clean")
        .confirmationDialog(
            "Move \(model.selectedItems.count) item(s) to Trash?",
            isPresented: $confirmTrash,
            titleVisibility: .visible
        ) {
            Button(
                "Move \(ByteFormat.string(for: model.selectedBytes)) to Trash",
                role: .destructive
            ) {
                Task { await model.moveSelectionToTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items are moved to Trash only — never permanently shredded. Empty Trash in Finder when ready.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .huskStartCleanScan)) { _ in
            if !model.isScanning {
                model.startScan()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Peel the husk")
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if !permissions.hasFullDiskAccess {
                Button {
                    permissions.openFullDiskAccessSettings()
                } label: {
                    Label("Full Disk Access", systemImage: "lock.open")
                }
                .help("Some caches stay hidden without Full Disk Access")
            }

            Button("Select Safe") {
                model.selectAllSafe()
            }
            .disabled(model.categories.isEmpty || model.isBusy)

            if model.isScanning {
                Button("Cancel", role: .cancel) {
                    model.cancelScan()
                }
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Button {
                    model.startScan()
                } label: {
                    Label(model.categories.isEmpty ? "Scan" : "Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.isBusy)
            }
        }
        .padding(16)
    }

    private var subtitle: String {
        switch model.phase {
        case .idle:
            return "Scan regenerable caches and developer leftovers. Click an item for a detailed breakdown."
        case .scanning(let p):
            return "Scanning… \(Int(p.fraction * 100))% · \(p.itemsFound) found · \(ByteFormat.string(for: p.bytesFound)) · \(p.currentPath)"
        case .ready:
            if let r = model.lastResult {
                return "Found \(ByteFormat.string(for: r.totalBytes)) across \(r.allItems.count) items in \(String(format: "%.1f", r.duration))s — select a row for details"
            }
            return "Review items, then move selected to Trash."
        case .trashing:
            return "Moving selected items to Trash…"
        case .finished(let bytes, let count):
            return "Moved \(count) item(s) · \(ByteFormat.string(for: bytes)) to Trash. Empty Trash in Finder when ready."
        case .failed(let message):
            return message
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            EmptyStateView(
                systemImage: "leaf",
                title: "Ready to scan",
                message: "Husk looks for regenerable caches, logs, Xcode data, package manager caches, and local AI models. Every path is shown before delete — click any result for a full content breakdown.",
                actionTitle: "Scan Now"
            ) {
                model.startScan()
            }

        case .scanning(let progress):
            VStack(spacing: 18) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 360)
                Text("\(Int(progress.fraction * 100))%")
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text(progress.currentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Text("\(progress.itemsFound) items · \(ByteFormat.string(for: progress.bytesFound))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .failed(let message):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Scan failed",
                message: message,
                actionTitle: "Try Again"
            ) {
                model.startScan()
            }

        case .trashing:
            ProgressView("Moving to Trash…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        default:
            if model.categories.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "No husk found. Nice.",
                    message: "Nothing large matched the current clean profiles — or sizes were zero.",
                    actionTitle: "Scan Again"
                ) {
                    model.startScan()
                }
            } else {
                resultsSplit
            }
        }
    }

    private var resultsSplit: some View {
        HSplitView {
            resultsList
                .frame(minWidth: 420)

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
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sidebar.trailing")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Select a cache for details")
                        .font(.headline)
                    Text("See size, safety, path, and the largest folders or files inside.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            }
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by name or path", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text(ByteFormat.string(for: model.totalBytes))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            List(selection: Binding(
                get: { model.inspectedItem?.id },
                set: { id in
                    if let id,
                       let item = model.categories.flatMap(\.items).first(where: { $0.id == id }) {
                        model.inspect(item)
                    }
                }
            )) {
                ForEach(model.filteredCategories) { category in
                    Section {
                        ForEach(category.items) { item in
                            CleanItemRow(
                                item: item,
                                isSelected: model.selectedIDs.contains(item.id),
                                isInspected: model.inspectedItem?.id == item.id,
                                onToggle: { model.toggle(item) },
                                onInspect: { model.inspect(item) },
                                onReveal: {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                }
                            )
                            .tag(item.id)
                        }
                    } header: {
                        HStack {
                            Label(category.name, systemImage: category.systemImage)
                            Text("\(category.items.count)")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                            Spacer()
                            Text(ByteFormat.string(for: category.totalBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button("Safe") { model.selectAll(in: category, onlySafe: true) }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            Button("None") { model.deselectAll(in: category) }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text("\(model.selectedItems.count) selected")
                .foregroundStyle(.secondary)
            SizeText(bytes: model.selectedBytes)

            Spacer()

            Button("Clear") {
                model.clearSelection()
            }
            .disabled(model.selectedIDs.isEmpty || model.isBusy)

            Button {
                confirmTrash = true
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .disabled(model.selectedItems.isEmpty || model.isBusy)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(16)
        .background(.bar)
    }
}

struct CleanItemRow: View {
    let item: CleanItem
    let isSelected: Bool
    var isInspected: Bool = false
    let onToggle: () -> Void
    var onInspect: (() -> Void)? = nil
    let onReveal: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!item.safety.isSelectable)
            .accessibilityLabel(isSelected ? "Deselect" : "Select")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    SafetyBadge(label: item.safety)
                    if isInspected {
                        Text("Details")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                Text(item.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let count = item.entryCount {
                        Text("· \(count) entries")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                SizeText(bytes: item.byteCount)
                Button("Reveal", action: onReveal)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onInspect?()
        }
        .contextMenu {
            Button("Show details") { onInspect?() }
            Button("Reveal in Finder", action: onReveal)
            if item.safety.isSelectable {
                Button(isSelected ? "Deselect" : "Select for Trash", action: onToggle)
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            }
        }
        .opacity(item.safety == .protected ? 0.5 : 1)
    }
}
