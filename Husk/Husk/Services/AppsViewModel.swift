//
//  AppsViewModel.swift
//  Husk
//

import Foundation

@Observable
@MainActor
final class AppsViewModel {
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
    private var selectTask: Task<Void, Never>?

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
        Task {
            isLoadingApps = true
            errorMessage = nil
            apps = await service.listApplications()
            isLoadingApps = false
        }
    }

    func select(_ app: AppEntry) {
        selectTask?.cancel()
        selectedApp = app
        leftovers = []
        selectedLeftoverIDs = []
        statusMessage = nil
        errorMessage = nil

        selectTask = Task {
            isLoadingLeftovers = true
            defer { isLoadingLeftovers = false }

            // Size app + find leftovers concurrently; cancel if user picks another app.
            async let sized: Int64 = service.sizeOfApp(at: app.path)
            async let found: [LeftoverItem] = service.findLeftovers(for: app)

            do {
                let byteCount = await sized
                let leftoverItems = await found
                guard !Task.isCancelled else { return }

                if let idx = apps.firstIndex(where: { $0.id == app.id }) {
                    let updated = AppEntry(
                        id: app.id,
                        name: app.name,
                        path: app.path,
                        bundleIdentifier: app.bundleIdentifier,
                        version: app.version,
                        byteCount: byteCount,
                        isFromSystem: app.isFromSystem
                    )
                    apps[idx] = updated
                    selectedApp = updated
                }

                leftovers = leftoverItems
                // Default: select regenerable leftovers only (not caution prefs)
                selectedLeftoverIDs = Set(
                    leftoverItems.filter { $0.safety == .safe || $0.safety == .review }.map(\.id)
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

    func uninstallSelected() async {
        guard let app = selectedApp else { return }
        isUninstalling = true
        errorMessage = nil
        statusMessage = nil

        var paths: [String] = selectedLeftovers.map(\.path)
        // Never use Dictionary(uniqueKeysWithValues:) — duplicate leftover paths crash the app.
        var lookup = DictUtil.uniquingLast(selectedLeftovers.map { ($0.path, $0.byteCount) })
        if includeAppBundle {
            paths.insert(app.path, at: 0)
            lookup[app.path] = app.byteCount
        }

        // Deduplicate paths while preserving order
        var seen = Set<String>()
        paths = paths.filter { seen.insert($0).inserted }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try TrashService.moveToTrash(paths: paths, byteLookup: lookup)
            }.value

            statusMessage =
                "Moved \(result.successCount) item(s) (\(ByteFormat.string(for: result.totalBytes))) to Trash."
            if !result.failures.isEmpty {
                errorMessage = result.failures.prefix(5).map { "\(($0.path as NSString).lastPathComponent): \($0.error)" }
                    .joined(separator: "\n")
            }

            if includeAppBundle && result.successPaths.contains(app.path) {
                apps.removeAll { $0.id == app.id }
                selectedApp = nil
                leftovers = []
                selectedLeftoverIDs = []
            } else {
                select(app)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isUninstalling = false
    }
}
