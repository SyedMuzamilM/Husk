//
//  AppsView.swift
//  Husk
//

import SwiftUI

struct AppsView: View {
    @Bindable var model: AppsViewModel
    @State private var confirmUninstall = false

    var body: some View {
        HSplitView {
            appList
                .frame(minWidth: 280, idealWidth: 320)

            detail
                .frame(minWidth: 400)
        }
        .navigationTitle("Apps")
        .onAppear {
            if model.apps.isEmpty {
                model.loadApps()
            }
        }
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $confirmUninstall,
            titleVisibility: .visible
        ) {
            Button(
                "Move \(ByteFormat.string(for: model.reclaimableBytes)) to Trash",
                role: .destructive
            ) {
                Task { await model.uninstallSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app bundle and selected leftovers will be moved to Trash. You can restore from Trash if needed.")
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Applications")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    model.loadApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoadingApps)
            }
            .padding(16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps", text: $model.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if model.isLoadingApps {
                ProgressView("Loading apps…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.filteredApps, selection: Binding(
                    get: { model.selectedApp?.id },
                    set: { id in
                        if let id, let app = model.apps.first(where: { $0.id == id }) {
                            model.select(app)
                        }
                    }
                )) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .lineLimit(1)
                            Text(app.bundleIdentifier ?? "Unknown bundle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if app.byteCount > 0 {
                            Text(ByteFormat.string(for: app.byteCount))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(app.id)
                    .contentShape(Rectangle())
                    .onTapGesture { model.select(app) }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.weight(.semibold))
                        Text(app.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            if let version = app.version {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let bid = app.bundleIdentifier {
                                Text(bid)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    SizeText(bytes: app.byteCount)
                }
                .padding(16)

                Divider()

                Toggle("Include app bundle", isOn: $model.includeAppBundle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if model.isLoadingLeftovers {
                    ProgressView("Finding leftovers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.leftovers.isEmpty {
                    Text("No leftovers found with current heuristics.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Leftovers") {
                            ForEach(model.leftovers) { item in
                                HStack {
                                    Button {
                                        model.toggleLeftover(item)
                                    } label: {
                                        Image(systemName: model.selectedLeftoverIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                        Text(item.path)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        HStack {
                                            Text(item.kind)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            SafetyBadge(label: item.safety)
                                        }
                                    }
                                    Spacer()
                                    SizeText(bytes: item.byteCount)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }

                if let status = model.statusMessage {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }

                Divider()
                HStack {
                    Text("Reclaimable")
                        .foregroundStyle(.secondary)
                    SizeText(bytes: model.reclaimableBytes)
                    Spacer()
                    Button {
                        confirmUninstall = true
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.85))
                    .disabled(model.isUninstalling || (model.selectedLeftovers.isEmpty && !model.includeAppBundle) || app.isFromSystem)
                }
                .padding(16)
            }
        } else {
            EmptyStateView(
                systemImage: "square.stack.3d.up",
                title: "Select an app",
                message: "Husk finds leftover files by bundle ID and related folders, then moves them to Trash with your approval."
            )
        }
    }
}
