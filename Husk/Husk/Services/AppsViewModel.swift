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
    private(set) var isPreparing = false
    var searchText = ""
    var statusMessage: String?
    var errorMessage: String?

    private let loadApplications: @Sendable () async -> [AppEntry]
    private let measureApp: @Sendable (String) async -> SizeMeasurement
    private let findLeftovers: @Sendable (AppEntry) async -> [LeftoverItem]
    private var selectionGeneration = UUID()
    private var selectTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()

    init(load: @escaping @Sendable () async -> [AppEntry] = { await AppUninstallService().listApplications() },
         size: @escaping @Sendable (String) async -> SizeMeasurement = { await AppUninstallService().sizeOfApp(at: $0) },
         leftovers: @escaping @Sendable (AppEntry) async -> [LeftoverItem] = { await AppUninstallService().findLeftovers(for: $0) }) {
        loadApplications = load
        measureApp = size
        findLeftovers = leftovers
    }

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

    var isBusy: Bool { isLoadingApps || isLoadingLeftovers || isUninstalling || isPreparing }

    func loadApps() {
        guard !isUninstalling, !isPreparing else { return }
        let previousSelection = selectedApp?.id
        cancel()
        clearSelection()
        let run = UUID()
        loadGeneration = run
        isLoadingApps = true
        errorMessage = nil
        let load = loadApplications
        loadTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            let result = await load()
            guard let self, !Task.isCancelled, loadGeneration == run else { return }
            apps = result
            isLoadingApps = false
            loadTask = nil
            if let app = result.first(where: { $0.id == previousSelection }) { select(app) }
        }
    }

    func select(_ app: AppEntry) {
        guard !isUninstalling, !isPreparing, !isLoadingApps else { return }
        removalPlan = nil
        selectTask?.cancel()
        selectedApp = app
        leftovers = []
        selectedLeftoverIDs = []
        statusMessage = nil
        errorMessage = nil
        isLoadingLeftovers = true
        let run = UUID()
        selectionGeneration = run
        let size = measureApp
        let find = findLeftovers
        selectTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            async let sized = size(app.path)
            async let found = find(app)
            let (measurement, leftoverItems) = await (sized, found)
            guard let self, !Task.isCancelled, selectionGeneration == run, selectedApp?.id == app.id else { return }
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                let updated = AppEntry(id: app.id, name: app.name, path: app.path,
                    bundleIdentifier: app.bundleIdentifier, version: app.version, byteCount: measurement.bytes,
                    isFromSystem: app.isFromSystem, completeness: measurement.status)
                apps[index] = updated
                selectedApp = updated
            }
            leftovers = leftoverItems
            selectedLeftoverIDs = Set(leftoverItems.filter { $0.safety == .safe }.map(\.id))
            isLoadingLeftovers = false
            selectTask = nil
        }
    }

    func cancel() {
        loadGeneration = UUID()
        selectionGeneration = UUID()
        loadTask?.cancel()
        selectTask?.cancel()
        loadTask = nil
        selectTask = nil
        isLoadingApps = false
        isLoadingLeftovers = false
    }

    func clearSelection() {
        selectionGeneration = UUID()
        selectTask?.cancel()
        selectTask = nil
        selectedApp = nil
        leftovers = []
        selectedLeftoverIDs = []
        isLoadingLeftovers = false
        removalPlan = nil
    }

    func toggleLeftover(_ item: LeftoverItem) {
        guard !isBusy, item.safety.isSelectable else { return }
        if selectedLeftoverIDs.contains(item.id) {
            selectedLeftoverIDs.remove(item.id)
        } else {
            selectedLeftoverIDs.insert(item.id)
        }
    }

    func prepareRemoval() async {
        guard let app = selectedApp, !isBusy, !app.isFromSystem else { return }
        isPreparing = true
        defer { isPreparing = false }
        var candidates = selectedLeftovers.map {
            RemovalCandidate(path: $0.path, bytes: $0.byteCount, safety: $0.safety, reason: $0.kind, ownerBundleID: app.bundleIdentifier)
        }
        if includeAppBundle {
            candidates.append(RemovalCandidate(path: app.path, bytes: app.byteCount, safety: .caution,
                reason: "Remove application bundle. Other copies may share its data.", ownerBundleID: app.bundleIdentifier))
        }
        let run = selectionGeneration
        let plan = await RemovalService.shared.prepare(candidates, title: "Review app removal")
        guard selectionGeneration == run, selectedApp?.id == app.id, !Task.isCancelled else { return }
        removalPlan = plan
    }

    func uninstallSelected(_ plan: RemovalPlan) async {
        guard !isBusy else { return }
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
            if let app = selectedApp, success.contains(app.path) { clearSelection() }
        } catch { errorMessage = error.localizedDescription }
    }
    isolated deinit {
        loadTask?.cancel()
        selectTask?.cancel()
    }
}
