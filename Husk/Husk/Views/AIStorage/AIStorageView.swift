import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AIStorageView: View {
    @Bindable var model: AIStorageViewModel
    @State private var choosingRepository = false
    @State private var showGuide = false

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "AI Storage", subtitle: "See what your AI tools keep, and review caches before cleanup.") {
                Button("Storage guide", systemImage: "info.circle") { showGuide = true }
                if model.isScanning {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button(model.report == nil ? "Scan AI storage" : "Rescan", systemImage: "arrow.clockwise") { model.scan() }
                        .disabled(model.isBusy)
                }
            }
            if let error = model.errorMessage {
                HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, HuskTheme.contentPadding)
            }
            if model.isScanning || model.isRemoving || model.isInspectingWorktrees {
                ProgressView(model.isScanning ? "Measuring known storage locations…" : model.isRemoving ? "Moving reviewed caches to Trash…" : "Reading Git worktree metadata…")
                    .padding().frame(maxWidth: .infinity)
            }
            if model.report == nil && !model.isScanning {
                VStack(spacing: 22) {
                    Spacer(minLength: 24)
                    Image(systemName: "cpu").font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.huskAccentText)
                        .frame(width: 116, height: 116)
                        .background(Color.huskPrimary.opacity(0.1), in: .rect(cornerRadius: 32))
                        .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(Color.huskPrimary.opacity(0.2)))
                        .accessibilityHidden(true)
                    VStack(spacing: 10) {
                        Text("Room for your next project.").font(.system(size: 28, weight: .semibold))
                        Text("Find caches, sessions and working copies from your AI tools.\nReview what can be cleaned, and keep your work protected.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    HuskPillButton(title: "Scan AI storage", systemImage: "magnifyingglass") { model.scan() }
                    Text("Codex · Claude · Gemini · OpenCode · Cursor · Local models")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                    Label("Sessions, models and worktrees are inspection only", systemImage: "lock")
                        .font(.callout).foregroundStyle(.secondary).padding(.bottom, 28)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                inventory
            }
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.remove(frozen) } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }
        .sheet(isPresented: $showGuide) { AIStorageGuide() }
        .fileImporter(isPresented: $choosingRepository, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): Task { await model.inspectWorktrees(repository: url.path) }
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
    }

    private var inventory: some View {
        VStack(spacing: 14) {
            Picker("Storage category", selection: $model.kind) {
                ForEach(AIStorageKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }.pickerStyle(.segmented).labelsHidden()
            .onChange(of: model.kind) { model.inspectedID = nil }
            HStack {
                HuskSearchField(prompt: "Search tools or paths", text: $model.searchText)
                Text("\(model.filteredItems.count) locations").foregroundStyle(.secondary).fixedSize()
            }
            if model.kind == .worktrees {
                HStack {
                    Text("A clean Git status does not prove a worktree is unused.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Inspect repository…", systemImage: "arrow.triangle.branch") { choosingRepository = true }.disabled(model.isBusy)
                }
            }
            HuskSplitView {
                Table(model.filteredItems, selection: $model.inspectedID) {
                    TableColumn("Select") { item in
                        Toggle("Select " + item.rule.tool + " cache", isOn: Binding(get: { model.selectedIDs.contains(item.id) }, set: { _ in model.toggle(item) }))
                            .labelsHidden().disabled(!item.canRemove || model.isBusy)
                    }.width(45)
                    TableColumn("Location") { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.rule.tool).font(.body.weight(.medium))
                            Text(URL(fileURLWithPath: item.path).lastPathComponent).foregroundStyle(.secondary).lineLimit(1)
                        }.padding(.vertical, 4)
                    }.width(min: 110, ideal: 150)
                    TableColumn("Size") { item in
                        Text(item.measurement.status == .unavailable ? "Not measured" : ByteFormat.string(for: item.measurement.bytes))
                            .monospacedDigit().help(item.measurement.status.rawValue)
                    }.width(110)
                }
                .scrollContentBackground(.hidden)
                .background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
                .clipShape(.rect(cornerRadius: HuskTheme.cardRadius))
                .overlay {
                    if model.filteredItems.isEmpty {
                        ContentUnavailableView("No matching locations", systemImage: model.kind.systemImage,
                            description: Text("Only existing, recognized default locations are listed. Custom tool homes and cloud-only data are not scanned."))
                    }
                }
                .frame(minWidth: 380, idealWidth: 420, maxHeight: .infinity)
                inspector.frame(minWidth: 240, idealWidth: 270, maxWidth: .infinity, maxHeight: .infinity)
            }
            if let issues = model.report?.issues, !issues.isEmpty {
                DisclosureGroup("\(issues.count) discovery issues") {
                    ScrollView {
                        ForEach(issues) { Text($0.path + " · " + $0.message).font(.callout).textSelection(.enabled) }
                    }.frame(maxHeight: 90)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ByteFormat.string(for: model.selectedBytes)) selected").font(.headline)
                    Text("\(model.selectedItems.count) caches · space is released after emptying Trash").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear") { model.selectedIDs = [] }.disabled(model.selectedIDs.isEmpty || model.isBusy)
                HuskPillButton(title: "Review cleanup", systemImage: "trash") { Task { await model.prepareRemoval() } }
                    .disabled(model.selectedItems.isEmpty || model.isBusy)
            }.padding(16).background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
        }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
    }

    private var inspector: some View {
        ScrollView {
            if model.kind == .worktrees, !model.worktrees.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Registered worktrees", systemImage: "arrow.triangle.branch").font(.title3.weight(.semibold))
                    Text("Inspection only. A clean status does not establish inactivity.").font(.callout).foregroundStyle(.secondary)
                    ForEach(model.worktrees) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.path).font(.body.monospaced()).textSelection(.enabled)
                            Text(record.branch ?? "Detached HEAD").font(.headline)
                            if record.locked { Label("Locked", systemImage: "lock").foregroundStyle(Color.huskAccentText) }
                            Text(record.status).font(.callout).foregroundStyle(.secondary)
                            Divider()
                        }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            } else if let item = model.inspectedItem {
                VStack(alignment: .leading, spacing: 16) {
                    Label(item.rule.tool, systemImage: item.rule.kind.systemImage).font(.title3.weight(.semibold))
                    SafetyBadge(label: item.safety)
                    Text(item.rule.detail).fixedSize(horizontal: false, vertical: true)
                    Text(item.path).font(.body.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let blocked = item.blockedReason { HuskNotice(message: blocked, systemImage: "lock") }
                    LabeledContent("Measurement", value: item.measurement.status.rawValue)
                    if let modified = item.measurement.modified {
                        LabeledContent("Folder modified", value: modified.formatted(date: .abbreviated, time: .omitted))
                        Text("Folder date does not establish last use.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(item.measurement.issues) { Text($0.message).font(.callout).foregroundStyle(.secondary) }
                    Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView("Inspect a location", systemImage: "sidebar.trailing", description: Text("Select a row to see its full path, activity checks and storage policy."))
            }
        }.background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
    }
}

private struct AIStorageGuide: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What can be cleaned?").font(.title2.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HuskNotice(message: "Caches are never selected automatically. Husk checks activity at review and again before moving each item to Trash.", systemImage: "checkmark.shield")
                    guide("Sessions", "Chat history, resume indexes, persistent memory and restore snapshots are personal data. Use the tool's own session manager; Husk does not read conversation content.")
                    guide("Worktrees", "Choose a repository to list registered worktrees and Git status. Locked, dirty and apparently clean working copies stay inspection-only. File age does not establish inactivity.")
                    guide("Installed tools", "Versions, plugins and runtimes can be actively referenced. Husk lists known locations; automatic removal needs installer and rollback ownership checks.")
                    guide("Grok and other tools", "Grok's web app has no verified standalone macOS cache path in this catalog. Use your browser's storage controls. Unknown tools and custom CODEX_HOME or XDG locations are not guessed.")
                    Link("Gemini session management", destination: URL(string: "https://geminicli.com/docs/cli/session-management/")!)
                    Link("OpenCode local storage", destination: URL(string: "https://opencode.ai/docs/troubleshooting/")!)
                }
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 580, height: 520)
    }
    private func guide(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
