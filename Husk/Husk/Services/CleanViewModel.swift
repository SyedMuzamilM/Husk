//
//  CleanViewModel.swift
//  Husk
//

import Foundation

@Observable
@MainActor
final class CleanViewModel {
    var phase: ScanPhase = .idle
    var categories: [CleanCategory] = [] { didSet { rebuildIndex() } }
    var selectedIDs: Set<UUID> = [] { didSet { refreshSelection() } }
    var lastResult: CleanScanResult?
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var removalError: String?
    private var detailGeneration = UUID()
    private var generation = UUID()
    var searchText: String = "" { didSet { refreshFilteredItems() } }

    /// Current filter group applied to the scanned items list.
    var selectedFilter: CleanFilter = .all { didSet { refreshFilteredItems() } }
    /// Current sort order applied to the scanned items list.
    var sortOption: CleanSortOption = .size { didSet { refreshFilteredItems() } }

    /// Focused item for the detail inspector.
    var inspectedItem: CleanItem?
    var cacheDetail: CacheDetailReport?
    var isLoadingDetail = false

    private var scanTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    typealias ProgressHandler = @Sendable (CleanScanProgress) -> Void
    typealias ScanOperation = @Sendable (@escaping ProgressHandler) async throws -> CleanScanResult
    private let scanOperation: ScanOperation
    private let detailOperation: @Sendable (String) async -> CacheDetailReport

    init(scan: @escaping ScanOperation = { try await CleanScanner().scan(progress: $0) },
         detail: @escaping @Sendable (String) async -> CacheDetailReport = { await CacheDetailService().detail(for: $0) }) {
        scanOperation = scan
        detailOperation = detail
    }

    @ObservationIgnored private var allItems: [CleanItem] = []
    @ObservationIgnored private var itemsByID: [UUID: CleanItem] = [:]
    private(set) var filteredItems: [CleanItem] = []
    private(set) var selectedItems: [CleanItem] = []
    private(set) var selectedBytes: Int64 = 0
    private(set) var totalBytes: Int64 = 0
    private(set) var itemCount = 0
    private(set) var isPreparingRemoval = false

    private func rebuildIndex() {
        allItems = categories.flatMap(\.items)
        itemsByID = DictUtil.uniquingFirst(allItems.map { ($0.id, $0) })
        totalBytes = allItems.reduce(0) { $0 + $1.byteCount }
        itemCount = allItems.count
        refreshFilteredItems()
        refreshSelection()
    }

    private func refreshFilteredItems() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var items = allItems.filter { item in
            let matchesGroup: Bool
            switch selectedFilter {
            case .all: matchesGroup = true
            case .dev: matchesGroup = ["developer", "package-managers", "project-artifacts", "ide"].contains(item.categoryID)
            case .ai: matchesGroup = ["ai-agents", "local-ai"].contains(item.categoryID)
            case .system: matchesGroup = ["user-caches", "browsers", "logs"].contains(item.categoryID)
            }
            return matchesGroup && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                || item.path.localizedCaseInsensitiveContains(query) || item.categoryName.localizedCaseInsensitiveContains(query))
        }
        items.sort { first, second in
            if sortOption == .safety, first.safety != second.safety { return first.safety < second.safety }
            if sortOption == .category, first.categoryName != second.categoryName { return first.categoryName < second.categoryName }
            if first.byteCount != second.byteCount { return first.byteCount > second.byteCount }
            if first.path != second.path { return first.path < second.path }
            return first.id.uuidString < second.id.uuidString
        }
        filteredItems = items
    }

    private func refreshSelection() {
        selectedItems = selectedIDs.compactMap { itemsByID[$0] }.filter(\.safety.isSelectable).sorted { $0.path < $1.path }
        selectedBytes = selectedItems.reduce(0) { $0 + $1.byteCount }
    }

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var isBusy: Bool {
        if isPreparingRemoval { return true }
        return switch phase {
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
        removalError = nil
        selectedIDs = []
        selectedFilter = .all
        sortOption = .size
        phase = .scanning(CleanScanProgress(fraction: 0, currentPath: "Starting…", itemsFound: 0, bytesFound: 0))
        let scan = scanOperation
        let throttle = ProgressThrottle(interval: 0.12)
        scanTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await scan { [weak self] progress in
                    // Throttle before scheduling MainActor work, not after filling its queue.
                    guard throttle.shouldEmit(force: progress.fraction >= 1) else { return }
                    Task { @MainActor [weak self] in
                        guard let self, generation == run, isScanning else { return }
                        phase = .scanning(progress)
                    }
                }
                guard let self, generation == run, !Task.isCancelled else { return }
                lastResult = result
                categories = result.categories
                phase = .ready
                scanTask = nil
            } catch {
                guard let self, generation == run else { return }
                phase = error is CancellationError ? (categories.isEmpty ? .idle : .ready) : .failed(error.localizedDescription)
                scanTask = nil
            }
        }
    }

    func cancelScan() {
        guard isScanning else { return }
        generation = UUID()

        scanTask?.cancel()
        scanTask = nil
        phase = categories.isEmpty ? .idle : .ready
    }

    func toggle(_ item: CleanItem) {
        guard !isBusy, item.safety.isSelectable else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAll(in category: CleanCategory, onlySafe: Bool = false) {
        guard !isBusy else { return }
        selectedIDs.formUnion(category.items.filter {
            $0.safety.isSelectable && (!onlySafe || $0.safety == .safe)
        }.map(\.id))
    }

    func deselectAll(in category: CleanCategory) {
        guard !isBusy else { return }
        selectedIDs.subtract(category.items.map(\.id))
    }

    /// Selects all safe items within the currently filtered and searched list.
    func selectAllSafe() {
        guard !isBusy else { return }
        selectedIDs.formUnion(filteredItems.filter { $0.safety == .safe }.map(\.id))
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
        isLoadingDetail = true
        let detail = detailOperation
        detailTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            let report = await detail(item.path)
            guard let self, !Task.isCancelled, detailGeneration == run, inspectedItem?.id == item.id else { return }
            cacheDetail = report
            isLoadingDetail = false
            detailTask = nil
        }
    }

    func clearInspection() {
        detailGeneration = UUID()
        detailTask?.cancel()
        detailTask = nil
        inspectedItem = nil
        cacheDetail = nil
        isLoadingDetail = false
    }

    func prepareRemoval() async {
        removalError = nil
        guard !isBusy, !selectedItems.isEmpty else { return }
        isPreparingRemoval = true
        defer { isPreparingRemoval = false }
        let run = generation
        let plan = await RemovalService.shared.prepare(selectedItems.map {
            RemovalCandidate(path: $0.path, bytes: $0.byteCount, safety: $0.safety, reason: $0.reason, ownerBundleID: $0.ownerBundleID)
        }, title: "Review cleanup")
        guard generation == run, !Task.isCancelled else { return }
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

    isolated deinit {
        scanTask?.cancel()
        detailTask?.cancel()
    }
}

/// Thread-safe throttle applied before scheduling progress on the main actor.
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
