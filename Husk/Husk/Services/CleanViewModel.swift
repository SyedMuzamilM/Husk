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
    var searchText: String = ""
    var expandedCategories: Set<String> = []

    private var scanTask: Task<Void, Never>?
    private let scanner = CleanScanner()

    var filteredCategories: [CleanCategory] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return categories }
        return categories.compactMap { cat in
            let items = cat.items.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                    || $0.path.localizedCaseInsensitiveContains(q)
            }
            guard !items.isEmpty else { return nil }
            return CleanCategory(id: cat.id, name: cat.name, systemImage: cat.systemImage, items: items)
        }
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
        scanTask?.cancel()
        Task { await scanner.cancel() }

        scanTask = Task {
            phase = .scanning(
                CleanScanProgress(fraction: 0, currentPath: "Starting…", itemsFound: 0, bytesFound: 0)
            )
            selectedIDs = []
            categories = []
            await scanner.reset()

            // Throttle UI progress updates
            let lastEmit = ProgressThrottle(interval: 0.12)

            do {
                let result = try await scanner.scan { [weak self] progress in
                    guard let self else { return }
                    Task { @MainActor in
                        if lastEmit.shouldEmit(force: progress.fraction >= 1) {
                            self.phase = .scanning(progress)
                        }
                    }
                }
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
                phase = categories.isEmpty ? .idle : .ready
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        Task { await scanner.cancel() }
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

    func selectAllSafe() {
        for item in categories.flatMap(\.items) where item.safety == .safe {
            selectedIDs.insert(item.id)
        }
    }

    func clearSelection() {
        selectedIDs = []
    }

    func moveSelectionToTrash() async {
        let items = selectedItems
        guard !items.isEmpty else { return }
        phase = .trashing

        let paths = items.map(\.path)
        // Paths can theoretically collide — never use uniqueKeysWithValues.
        let lookup = DictUtil.uniquingLast(items.map { ($0.path, $0.byteCount) })

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try TrashService.moveToTrash(paths: paths, byteLookup: lookup)
            }.value

            let success = Set(result.successPaths)
            categories = categories.compactMap { cat in
                let remaining = cat.items.filter { !success.contains($0.path) }
                guard !remaining.isEmpty else { return nil }
                return CleanCategory(
                    id: cat.id,
                    name: cat.name,
                    systemImage: cat.systemImage,
                    items: remaining
                )
            }
            selectedIDs = []
            phase = .finished(trashedBytes: result.totalBytes, itemCount: result.successCount)
        } catch {
            phase = .failed(error.localizedDescription)
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
