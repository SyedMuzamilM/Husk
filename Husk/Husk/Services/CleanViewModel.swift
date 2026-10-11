//
//  CleanViewModel.swift
//  Husk
//

import Foundation

@Observable
@MainActor
final class CleanViewModel {
    var phase: ScanPhase = .idle
    var categories: [CleanCategory] = []
    var selectedIDs: Set<UUID> = []
    var lastResult: CleanScanResult?
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var removalError: String?
    private var detailGeneration = UUID()
    private var generation = UUID()
    var searchText: String = ""
    var expandedCategories: Set<String> = []

    /// Current filter group applied to the scanned items list.
    var selectedFilter: CleanFilter = .all
    /// Current sort order applied to the scanned items list.
    var sortOption: CleanSortOption = .size

    /// Focused item for the detail inspector.
    var inspectedItem: CleanItem?
    var cacheDetail: CacheDetailReport?
    var isLoadingDetail = false

    private var scanTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private let scanner = CleanScanner()
    private let detailService = CacheDetailService()

    /// Flat list of items matching the search query and group filter, sorted by the selected sort option.
    var filteredItems: [CleanItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var items = categories.flatMap(\.items)

        // 1. Apply search text query matching name, path, or category.
        if !q.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                    || $0.path.localizedCaseInsensitiveContains(q)
                    || $0.categoryName.localizedCaseInsensitiveContains(q)
            }
        }

        // 2. Apply high-level category group filters.
        switch selectedFilter {
        case .all:
            break
        case .dev:
            // Match developer-centric caches and artifacts.
            items = items.filter { ["developer", "package-managers", "project-artifacts", "ide"].contains($0.categoryID) }
        case .ai:
            // Match local AI models and coding agents.
            items = items.filter { ["ai-agents", "local-ai"].contains($0.categoryID) }
        case .system:
            // Match system-level caches, logs, browser files, and Trash.
            items = items.filter { ["user-caches", "browsers", "logs", "trash"].contains($0.categoryID) }
        }

        // 3. Apply sorting options.
        switch sortOption {
        case .size:
            // Default and primary sort: show the largest items on top.
            items.sort { $0.byteCount > $1.byteCount }
        case .safety:
            // Sort by risk profile (safe first), then by size.
            items.sort {
                if $0.safety != $1.safety { return $0.safety < $1.safety }
                return $0.byteCount > $1.byteCount
            }
        case .category:
            // Sort alphabetically by category name, then by size.
            items.sort {
                if $0.categoryName != $1.categoryName { return $0.categoryName < $1.categoryName }
                return $0.byteCount > $1.byteCount
            }
        }

        return items
    }

    var selectedItems: [CleanItem] {
        let all = categories.flatMap(\.items)
        let byID = DictUtil.uniquingFirst(all.map { ($0.id, $0) })
        return selectedIDs.compactMap { byID[$0] }.filter(\.safety.isSelectable)
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.byteCount }
    }

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var isBusy: Bool {
        switch phase {
        case .scanning, .trashing: true
        default: false
        }
    }

    func startScan() {
        guard !isBusy || isScanning else { return }
        scanTask?.cancel()
        let run = UUID()
        generation = run
        clearInspection()
        removalPlan = nil
        phase = .scanning(CleanScanProgress(fraction: 0, currentPath: "Starting…", itemsFound: 0, bytesFound: 0))
        scanTask = Task {
            selectedIDs = []
            selectedFilter = .all
            sortOption = .size

            // Throttle UI progress updates to avoid rapid main thread redraws.
            let lastEmit = ProgressThrottle(interval: 0.12)

            do {
                let scannerService = scanner
                let model = self
                let result = try await scannerService.scan { [weak model] progress in
                    Task { @MainActor [weak model] in
                        guard let self = model else { return }
                        if lastEmit.shouldEmit(force: progress.fraction >= 1) {
                            if self.generation == run, self.isScanning { self.phase = .scanning(progress) }
                        }
                    }
                }
                guard generation == run else { return }
                guard !Task.isCancelled else {
                    phase = categories.isEmpty ? .idle : .ready
                    return
                }
                lastResult = result
                categories = result.categories
                expandedCategories = Set(result.categories.map(\.id))
                selectedIDs = []
                phase = .ready
            } catch is CancellationError {
                guard generation == run else { return }
                phase = categories.isEmpty ? .idle : .ready
            } catch {
                guard generation == run else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        generation = UUID()

        scanTask?.cancel()
        scanTask = nil
        phase = categories.isEmpty ? .idle : .ready
    }

    func toggle(_ item: CleanItem) {
        guard item.safety.isSelectable else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAll(in category: CleanCategory, onlySafe: Bool = false) {
        for item in category.items {
            guard item.safety.isSelectable else { continue }
            if onlySafe && item.safety != .safe { continue }
            selectedIDs.insert(item.id)
        }
    }

    func deselectAll(in category: CleanCategory) {
        for item in category.items {
            selectedIDs.remove(item.id)
        }
    }

    /// Selects all safe items within the currently filtered and searched list.
    func selectAllSafe() {
        for item in filteredItems where item.safety == .safe {
            selectedIDs.insert(item.id)
        }
    }

    func clearSelection() {
        selectedIDs = []
    }

    func inspect(_ item: CleanItem) {
        inspectedItem = item
        cacheDetail = nil
        detailTask?.cancel()
        let run = UUID()
        detailGeneration = run
        detailTask = Task {
            isLoadingDetail = true
            defer { if detailGeneration == run { isLoadingDetail = false } }
            let report = await detailService.detail(for: item.path)
            guard !Task.isCancelled else { return }
            // Only apply if still inspecting the same item
            if detailGeneration == run, inspectedItem?.id == item.id {
                cacheDetail = report
            }
        }
    }

    func clearInspection() {
        detailGeneration = UUID()
        detailTask?.cancel()
        inspectedItem = nil
        cacheDetail = nil
        isLoadingDetail = false
    }

    func prepareRemoval() async {
        removalError = nil
        guard !isBusy else { return }
        let run = generation
        let plan = await RemovalService.shared.prepare(selectedItems.map {
            RemovalCandidate(path: $0.path, bytes: $0.byteCount, safety: $0.safety, reason: $0.reason, ownerBundleID: $0.ownerBundleID)
        }, title: "Review cleanup")
        guard generation == run, !isBusy else { return }
        removalPlan = plan
    }

    func moveSelectionToTrash(_ plan: RemovalPlan) async {
        guard !isBusy else { return }
        phase = .trashing
        do {
            let result = try await RemovalService.shared.execute(plan)
            removalResult = result
            let success = Set(result.successPaths)
            categories = categories.compactMap { cat in
                let remaining = cat.items.filter { !success.contains($0.path) }
                return remaining.isEmpty ? nil : CleanCategory(id: cat.id, name: cat.name, systemImage: cat.systemImage, items: remaining)
            }
            selectedIDs.formIntersection(Set(categories.flatMap(\.items).map(\.id)))
            clearInspection()
            lastResult = nil
            phase = .finished(trashedBytes: result.totalBytes, itemCount: result.successCount)
        } catch {
            removalError = error.localizedDescription
            phase = categories.isEmpty ? .idle : .ready
        }
    }

}

/// Simple main-actor-friendly throttle for progress UI.
final class ProgressThrottle: @unchecked Sendable {
    private let interval: TimeInterval
    private var last: CFAbsoluteTime = 0
    private let lock = NSLock()

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func shouldEmit(force: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        if force || now - last >= interval {
            last = now
            return true
        }
        return false
    }
}

/// High-level filter groups for the cache list.
enum CleanFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case dev = "Dev Tools"
    case ai = "AI Tools"
    case system = "System & OS"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .dev: return "hammer"
        case .ai: return "cpu"
        case .system: return "desktopcomputer"
        }
    }
}

/// Sort options for the cache list.
enum CleanSortOption: String, CaseIterable, Identifiable, Sendable {
    case size = "Size"
    case safety = "Safety"
    case category = "Category"

    var id: String { rawValue }
}
