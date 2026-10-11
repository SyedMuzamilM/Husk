import SwiftUI

struct AppsView: View {
    @Bindable var model: AppsViewModel
    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Applications", subtitle: "Review an app and its exact bundle ID matches before removal.") {
                Button("Refresh", systemImage: "arrow.clockwise") { model.loadApps() }.disabled(model.isLoadingApps || model.isUninstalling)
            }
            HSplitView {
                appList.frame(minWidth: 240, idealWidth: 270)
                detail.frame(minWidth: 380, maxWidth: .infinity)
            }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
        }
        .onAppear { if model.apps.isEmpty && !AppRuntime.isXcodePreview && !AppRuntime.isUIFixture { model.loadApps() } }
        .sheet(item: $model.removalPlan) { plan in
            RemovalReviewSheet(plan: plan) { frozen in Task { await model.uninstallSelected(frozen) } }
        }
        .sheet(item: $model.removalResult) { RemovalResultSheet(result: $0) }
    }
    private var appList: some View {
        VStack(spacing: 12) {
            HuskSearchField(prompt: "Search apps or bundle IDs", text: $model.searchText).padding(.horizontal, 10)
            if model.isLoadingApps { ProgressView("Finding applications…").frame(maxHeight: .infinity) }
            else {
                List(model.filteredApps, selection: Binding(get: { model.selectedApp?.id }, set: { id in
                    if let app = model.apps.first(where: { $0.id == id }), model.selectedApp?.id != id { model.select(app) }
                })) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon).resizable().frame(width: 32, height: 32).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.body.weight(.medium)).lineLimit(1)
                            Text(app.version ?? "Unknown version").font(.callout).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4).tag(app.id)
                }.listStyle(.inset).scrollContentBackground(.hidden).overlay {
                    if model.filteredApps.isEmpty { ContentUnavailableView("No matching apps", systemImage: "square.stack.3d.up", description: Text("Change the search or refresh the app list.")) }
                }
            }
        }.padding(.top, 10).background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
    }
    @ViewBuilder private var detail: some View {
        if let app = model.selectedApp {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon).resizable().frame(width: 44, height: 44).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.title3.weight(.semibold))
                            Text(app.bundleIdentifier ?? "Bundle ID unavailable").font(.callout.monospaced()).textSelection(.enabled)
                        }
                        Spacer()
                        Text(ByteFormat.string(for: app.byteCount)).monospacedDigit()
                    }
                    Text(app.path).font(.body.monospaced()).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                    Toggle("Include application bundle", isOn: $model.includeAppBundle).disabled(app.isFromSystem || model.isUninstalling)
                    if app.isFromSystem { HuskNotice(message: "macOS system applications are protected.", systemImage: "lock.shield") }
                }.padding(18)
                Divider()
                if model.isLoadingLeftovers { ProgressView("Finding related files…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else {
                    List(model.leftovers) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("Select " + item.name, isOn: Binding(get: { model.selectedLeftoverIDs.contains(item.id) }, set: { _ in model.toggleLeftover(item) }))
                                .labelsHidden().disabled(!item.safety.isSelectable || model.isUninstalling)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(item.name).font(.headline); Spacer(); Text(ByteFormat.string(for: item.byteCount)).monospacedDigit() }
                                Text(item.path).font(.callout.monospaced()).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                                HStack { SafetyBadge(label: item.safety); Text(item.kind).font(.callout).foregroundStyle(.secondary) }
                            }
                        }.padding(.vertical, 6)
                    }.listStyle(.inset).scrollContentBackground(.hidden).overlay {
                        if model.leftovers.isEmpty { ContentUnavailableView("No related files found", systemImage: "checkmark.shield", description: Text("Only exact bundle ID matches are included. Other copies may share app data.")) }
                    }
                }
                if let status = model.statusMessage { HuskNotice(message: status).padding(.horizontal, 14) }
                if let error = model.errorMessage { HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, 14) }
                Divider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ByteFormat.string(for: model.reclaimableBytes) + " selected").font(.headline)
                        Text("Size \(app.completeness.rawValue)").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HuskPillButton(title: "Review removal", systemImage: "trash") { Task { await model.prepareRemoval() } }
                        .disabled(model.isUninstalling || model.isLoadingLeftovers || (model.selectedLeftovers.isEmpty && !model.includeAppBundle) || app.isFromSystem)
                }.padding(16)
            }.background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
        } else {
            ContentUnavailableView("Select an application", systemImage: "square.stack.3d.up", description: Text("Inspect its size and related files. Preferences and personal data require a separate review."))
                .background(Color.huskSurface, in: .rect(cornerRadius: HuskTheme.cardRadius))
        }
    }
}
