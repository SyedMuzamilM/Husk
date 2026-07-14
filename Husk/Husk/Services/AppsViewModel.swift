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
        selectedApp = app
        leftovers = []
        selectedLeftoverIDs = []
        statusMessage = nil
        Task {
            isLoadingLeftovers = true
            leftovers = await service.findLeftovers(for: app)
            // Default-select safe + review leftovers, not caution preferences necessarily
            selectedLeftoverIDs = Set(
                leftovers.filter { $0.safety == .safe || $0.safety == .review }.map(\.id)
            )
            isLoadingLeftovers = false
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

        var paths: [String] = selectedLeftovers.map(\.path)
        var lookup: [String: Int64] = Dictionary(
            uniqueKeysWithValues: selectedLeftovers.map { ($0.path, $0.byteCount) }
        )
        if includeAppBundle {
            paths.insert(app.path, at: 0)
            lookup[app.path] = app.byteCount
        }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try TrashService.moveToTrash(paths: paths, byteLookup: lookup)
            }.value

            statusMessage =
                "Moved \(result.successCount) item(s) (\(ByteFormat.string(for: result.totalBytes))) to Trash."
            if !result.failures.isEmpty {
                errorMessage = result.failures.map { "\($0.path): \($0.error)" }.joined(separator: "\n")
            }

            // Refresh
            if includeAppBundle {
                apps.removeAll { $0.id == app.id }
                selectedApp = nil
                leftovers = []
            } else {
                select(app)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isUninstalling = false
    }
}
