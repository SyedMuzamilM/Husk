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
        .onAppear {
            if model.categories.isEmpty, !model.isScanning {
                // idle until user starts
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Peel the husk")
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !permissions.hasFullDiskAccess {
                Button {
                    permissions.openFullDiskAccessSettings()
                } label: {
                    Label("Grant Full Disk Access", systemImage: "lock.open")
                }
                .buttonStyle(.bordered)
            }

            Button {
                model.selectAllSafe()
            } label: {
                Text("Select Safe")
            }
            .disabled(model.categories.isEmpty || model.isScanning)

            if model.isScanning {
                Button("Cancel", role: .cancel) {
                    model.cancelScan()
                }
            } else {
                Button {
                    model.startScan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .padding(16)
    }

    private var subtitle: String {
        switch model.phase {
        case .idle:
            return "Scan regenerable caches and developer leftovers. Preview every path."
        case .scanning(let p):
            return "Scanning… \(Int(p.fraction * 100))% · \(p.itemsFound) items · \(ByteFormat.string(for: p.bytesFound))"
        case .ready:
            if let r = model.lastResult {
                return "Found \(ByteFormat.string(for: r.totalBytes)) in \(r.allItems.count) items · \(String(format: "%.1fs", r.duration))"
            }
            return "Review items, then move selected to Trash."
        case .trashing:
            return "Moving to Trash…"
        case .finished(let bytes, let count):
            return "Moved \(count) item(s) · \(ByteFormat.string(for: bytes)) to Trash."
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
                title: "No husk found yet",
                message: "Scan your Mac for regenerable caches, logs, and developer artifacts. Nothing is deleted until you choose it.",
                actionTitle: "Scan Now"
            ) {
                model.startScan()
            }

        case .scanning(let progress):
            VStack(spacing: 20) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 420)
                Text(progress.currentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Scan failed",
                message: message,
                actionTitle: "Try Again"
            ) {
                model.startScan()
            }

        default:
            if model.categories.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "No husk found. Nice.",
                    message: "Nothing large matched the current clean profiles.",
                    actionTitle: "Scan Again"
                ) {
                    model.startScan()
                }
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by name or path", text: $model.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            List {
                ForEach(model.filteredCategories) { category in
                    Section {
                        ForEach(category.items) { item in
                            CleanItemRow(
                                item: item,
                                isSelected: model.selectedIDs.contains(item.id),
                                onToggle: { model.toggle(item) },
                                onReveal: {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                }
                            )
                        }
                    } header: {
                        HStack {
                            Label(category.name, systemImage: category.systemImage)
                            Spacer()
                            SizeText(bytes: category.totalBytes)
                                .font(.caption.monospacedDigit())
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
            if case .scanning(let p) = model.phase {
                ProgressView(value: p.fraction)
                    .frame(width: 120)
            }

            Text("\(model.selectedItems.count) selected")
                .foregroundStyle(.secondary)
            SizeText(bytes: model.selectedBytes)

            Spacer()

            Button("Clear selection") {
                model.clearSelection()
            }
            .disabled(model.selectedIDs.isEmpty)

            Button {
                confirmTrash = true
            } label: {
                Label(
                    "Move to Trash",
                    systemImage: "trash"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .disabled(model.selectedItems.isEmpty || model.isScanning)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(16)
        .background(.bar)
    }
}

struct CleanItemRow: View {
    let item: CleanItem
    let isSelected: Bool
    let onToggle: () -> Void
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
                HStack {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    SafetyBadge(label: item.safety)
                }
                Text(item.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .onTapGesture(perform: onToggle)
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            if item.safety.isSelectable {
                Button(isSelected ? "Deselect" : "Select", action: onToggle)
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            }
        }
        .opacity(item.safety == .protected ? 0.5 : 1)
    }
}
