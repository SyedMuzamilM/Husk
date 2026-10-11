//
//  AppsView.swift
//  Husk
//

import SwiftUI

struct AppsView: View {
    @Bindable var model: AppsViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apps")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.huskText)
                    Text("Uninstall apps and peel leftover files.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.huskTextMuted)
                }
                Spacer()
                Button {
                    model.loadApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.huskTextSecondary)
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingApps)
            }
            .padding(.horizontal, HuskTheme.contentPadding)
            .padding(.top, 18)
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                appList
                    .frame(minWidth: 280, idealWidth: 320)
                detail
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, HuskTheme.contentPadding)
            .padding(.bottom, 16)
        }
        .onAppear {
            if model.apps.isEmpty { model.loadApps() }
        }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.uninstallSelected(frozen) } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }

    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.huskTextMuted)
                TextField("Search apps", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.huskText)
            }
            .padding(10)
            Divider().overlay(Color.huskBorder)

            if model.isLoadingApps {
                ProgressView().tint(Color.huskPrimary).frame(maxHeight: .infinity)
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
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .foregroundStyle(Color.huskText)
                                .lineLimit(1)
                            Text(app.bundleIdentifier ?? "—")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.huskTextMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        if app.byteCount > 0 {
                            Text(ByteFormat.string(for: app.byteCount))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.huskPrimary)
                        }
                    }
                    .tag(app.id)
                    .listRowBackground(Color.clear)
                    .onTapGesture { model.select(app) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
        .clipShape(RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(nsImage: app.icon).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.huskText)
                        Text(app.path + " · Size " + app.completeness.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.huskTextMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    if app.byteCount > 0 {
                        Text(ByteFormat.string(for: app.byteCount))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.huskPrimary)
                    }
                }
                .padding(16)

                Toggle("Include app bundle", isOn: $model.includeAppBundle)
                    .toggleStyle(.switch)
                    .tint(Color.huskPrimary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .foregroundStyle(Color.huskTextSecondary)

                if model.isLoadingLeftovers {
                    ProgressView("Finding leftovers…")
                        .tint(Color.huskPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.leftovers.isEmpty {
                    Text("No leftovers found.")
                        .foregroundStyle(Color.huskTextMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(model.leftovers) { item in
                            HStack {
                                Button {
                                    model.toggleLeftover(item)
                                } label: {
                                    Image(systemName: model.selectedLeftoverIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(model.selectedLeftoverIDs.contains(item.id) ? Color.huskPrimary : Color.huskTextMuted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Select " + item.name)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).foregroundStyle(Color.huskText)
                                    Text(item.path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color.huskTextMuted)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    HStack {
                                        Text(item.kind).font(.caption2).foregroundStyle(Color.huskTextMuted)
                                        SafetyBadge(label: item.safety)
                                    }
                                }
                                Spacer()
                                Text(ByteFormat.string(for: item.byteCount))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.huskPrimary)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                if let status = model.statusMessage {
                    Text(status).font(.caption).foregroundStyle(Color.huskTextSecondary).padding(.horizontal, 16)
                }
                if let error = model.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Color.cautionLabel).padding(.horizontal, 16)
                }

                Divider().overlay(Color.huskBorder)
                HStack {
                    Text("Selected estimate \(ByteFormat.string(for: model.reclaimableBytes))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.huskTextMuted)
                    Spacer()
                    HuskPillButton(title: "Move to Trash", systemImage: "trash") {
                        Task { await model.prepareRemoval() }
                    }
                    .disabled(model.isUninstalling || model.isLoadingLeftovers || (model.selectedLeftovers.isEmpty && !model.includeAppBundle) || app.isFromSystem)
                    .opacity(app.isFromSystem ? 0.4 : 1)
                }
                .padding(14)
            }
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
            EmptyStateView(
                systemImage: "shippingbox",
                title: "Select an app",
                message: "Husk finds leftovers by bundle ID, then moves them to Trash with your approval."
            )
        }
    }
}
