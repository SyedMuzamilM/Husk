import Foundation

@Observable @MainActor
final class AIStorageViewModel {
    var report: AIStorageReport?
    var isScanning = false
    var isRemoving = false
    var isPreparing = false
    var searchText = ""
    var kind: AIStorageKind = .cache
    var selectedIDs: Set<String> = []
    var inspectedID: String?
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var errorMessage: String?
    var worktrees: [GitWorktree] = []
    var isInspectingWorktrees = false
    private var task: Task<Void, Never>?
    private var worktreeTask: Task<Void, Never>?
    private var generation = UUID()
    private let scanOperation: @Sendable () async throws -> AIStorageReport

    init(scan: @escaping @Sendable () async throws -> AIStorageReport = { try await AIStorageService.scan() }) {
        scanOperation = scan
    }

    var items: [AIStorageItem] { report?.items ?? [] }
    var filteredItems: [AIStorageItem] {
        items.filter { $0.rule.kind == kind && (searchText.isEmpty || ($0.rule.tool + $0.path).localizedCaseInsensitiveContains(searchText)) }
    }
    var inspectedItem: AIStorageItem? { items.first { $0.id == inspectedID } }
    var selectedItems: [AIStorageItem] { items.filter { selectedIDs.contains($0.id) && $0.canRemove } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.measurement.bytes } }
    var isBusy: Bool { isScanning || isRemoving || isPreparing || isInspectingWorktrees }

    func scan() {
        guard !isBusy else { return }
        generation = UUID()
        let run = generation
        selectedIDs = []
        removalPlan = nil
        isScanning = true
        errorMessage = nil
        let scan = scanOperation
        task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await scan()
                guard let self, !Task.isCancelled, generation == run else { return }
                report = result
                if !items.contains(where: { $0.id == inspectedID }) { inspectedID = nil }
                isScanning = false
                task = nil
            } catch {
                guard let self, generation == run else { return }
                if !(error is CancellationError) { errorMessage = error.localizedDescription }
                isScanning = false
                task = nil
            }
        }
    }
    func cancel() {
        task?.cancel()
        worktreeTask?.cancel()
        task = nil
        worktreeTask = nil
        generation = UUID()
        isScanning = false
        isInspectingWorktrees = false
    }
    func toggle(_ item: AIStorageItem) {
        guard !isBusy, item.canRemove else { return }
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
    }
    func prepareRemoval() async {
        guard !isBusy, !selectedItems.isEmpty else { return }
        isPreparing = true
        defer { isPreparing = false }
        let candidates = selectedItems.map {
            RemovalCandidate(path: $0.path, bytes: $0.measurement.bytes, safety: .review,
                             reason: $0.rule.detail, ownerBundleID: $0.rule.ownerBundleID)
        }
        removalPlan = await RemovalService.shared.prepare(candidates, title: "Review AI cache cleanup")
    }
    func remove(_ plan: RemovalPlan) async {
        guard !isBusy else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            let result = try await RemovalService.shared.execute(plan)
            removalResult = result
            let success = Set(result.successPaths)
            selectedIDs.subtract(success)
            if let old = report {
                report = AIStorageReport(items: old.items.filter { !success.contains($0.path) }, issues: old.issues, scannedAt: old.scannedAt)
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func inspectWorktrees(repository: String) {
        guard !isBusy else { return }
        let run = UUID()
        generation = run
        isInspectingWorktrees = true
        errorMessage = nil
        worktrees = []
        worktreeTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let records = try await WorktreeInspectionService.inspect(repository: repository)
                guard let self, generation == run, !Task.isCancelled else { return }
                worktrees = records
                isInspectingWorktrees = false
                worktreeTask = nil
            } catch {
                guard let self, generation == run else { return }
                if !(error is CancellationError) { errorMessage = error.localizedDescription }
                isInspectingWorktrees = false
                worktreeTask = nil
            }
        }
    }
    isolated deinit {
        task?.cancel()
        worktreeTask?.cancel()
    }
}
