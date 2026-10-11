//
//  AppsViewModel.swift
//  Husk
//

import Foundation

@Observable
@MainActor
final class AppsViewModel {
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var apps: [AppEntry] = []
    var selectedApp: AppEntry?
    var leftovers: [LeftoverItem] = []
    var selectedLeftoverIDs: Set<UUID> = []
    var includeAppBundle = true
    var isLoadingApps = false
    var isLoadingLeftovers = false
    var isUninstalling = false
    var searchText = ""
    var statusMessage: String?
    var errorMessage: String?

    private let service = AppUninstallService()
    private var selectionGeneration = UUID()
    private var selectTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()

    var filteredApps: [AppEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var selectedLeftovers: [LeftoverItem] {
        leftovers.filter { selectedLeftoverIDs.contains($0.id) }
    }

    var reclaimableBytes: Int64 {
        var total = selectedLeftovers.reduce(Int64(0)) { $0 + $1.byteCount }
        if includeAppBundle, let app = selectedApp {
            total += app.byteCount
        }
        return total
    }

    func loadApps() {
        guard !isUninstalling else { return }
        loadTask?.cancel()
        let run = UUID()
        loadGeneration = run
        isLoadingApps = true
        errorMessage = nil
        loadTask = Task {
            let result = await service.listApplications()
            guard !Task.isCancelled, loadGeneration == run else { return }
            apps = result
            isLoadingApps = false
        }
    }

    func select(_ app: AppEntry) {
        guard !isUninstalling else { return }
        removalPlan = nil
        selectTask?.cancel()
        selectedApp = app
        leftovers = []
        selectedLeftoverIDs = []
        statusMessage = nil
        errorMessage = nil

        let run = UUID()
        selectionGeneration = run
        selectTask = Task {
            isLoadingLeftovers = true
            defer { if selectionGeneration == run { isLoadingLeftovers = false } }

            // Size app + find leftovers concurrently; cancel if user picks another app.
            async let sized: SizeMeasurement = service.sizeOfApp(at: app.path)
            async let found: [LeftoverItem] = service.findLeftovers(for: app)

            do {
                let measurement = await sized
                let leftoverItems = await found
                guard !Task.isCancelled, selectionGeneration == run, selectedApp?.id == app.id else { return }

                if let idx = apps.firstIndex(where: { $0.id == app.id }) {
                    let updated = AppEntry(
                        id: app.id,
                        name: app.name,
                        path: app.path,
                        bundleIdentifier: app.bundleIdentifier,
                        version: app.version,
                        byteCount: measurement.bytes,
                        isFromSystem: app.isFromSystem, completeness: measurement.status
                    )
                    apps[idx] = updated
                    selectedApp = updated
                }

                leftovers = leftoverItems
                // Default: select regenerable leftovers only (not caution prefs)
                selectedLeftoverIDs = Set(
                    leftoverItems.filter { $0.safety == .safe }.map(\.id)
                )
            }
        }
    }

    func toggleLeftover(_ item: LeftoverItem) {
        if selectedLeftoverIDs.contains(item.id) {
            selectedLeftoverIDs.remove(item.id)
        } else {
            selectedLeftoverIDs.insert(item.id)
        }
    }

    func prepareRemoval() async {
        guard let app = selectedApp, !isUninstalling, !isLoadingLeftovers, !app.isFromSystem else { return }
        var candidates = selectedLeftovers.map {
            RemovalCandidate(path: $0.path, bytes: $0.byteCount, safety: $0.safety, reason: $0.kind, ownerBundleID: app.bundleIdentifier)
        }
        if includeAppBundle {
            candidates.append(RemovalCandidate(path: app.path, bytes: app.byteCount, safety: .caution,
                reason: "Remove application bundle. Other copies may share its data.", ownerBundleID: app.bundleIdentifier))
        }
        let run = selectionGeneration
        let plan = await RemovalService.shared.prepare(candidates, title: "Review app removal")
        guard selectionGeneration == run, selectedApp?.id == app.id, !isUninstalling else { return }
        removalPlan = plan
    }

    func uninstallSelected(_ plan: RemovalPlan) async {
        guard !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }
        do {
            let result = try await RemovalService.shared.execute(plan)
            removalResult = result
            statusMessage = "Moved \(result.successCount) items to Trash."
            let success = Set(result.successPaths)
            leftovers.removeAll { success.contains($0.path) }
            selectedLeftoverIDs.formIntersection(Set(leftovers.map(\.id)))
            apps.removeAll { success.contains($0.path) }
            if let app = selectedApp, success.contains(app.path) { selectedApp = nil }
        } catch { errorMessage = error.localizedDescription }
    }
}
