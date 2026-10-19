import AppKit
import Foundation

@Observable @MainActor
final class AnalyzeViewModel {
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var includeHidden = true
    var root: DiskNode?
    var capacity: DiskCapacity?
    var pathStack: [DiskNode] = []
    var isLoading = false
    private(set) var isPreparing = false
    private(set) var isRemoving = false
    var statusText = "Pick a location to map"
    var errorMessage: String?
    var selectedRootPath: String = NSHomeDirectory()

    private var generation = UUID()
    @ObservationIgnored private var capacities: [UUID: DiskCapacity] = [:]
    private var task: Task<Void, Never>?
    private let load: @Sendable (String, Bool) async throws -> DiskNode
    private let executeRemoval: @Sendable (RemovalPlan) async throws -> TrashResult
    private let readCapacity: @Sendable (String) async throws -> DiskCapacity

    init(load: @escaping @Sendable (String, Bool) async throws -> DiskNode = {
        try await DiskAnalyzer().expand(path: $0, includeHidden: $1)
    }, capacity: @escaping @Sendable (String) async throws -> DiskCapacity = { try await DiskCapacity.read(at: $0 == "/" ? NSHomeDirectory() : $0) },
    executeRemoval: @escaping @Sendable (RemovalPlan) async throws -> TrashResult = {
        try await RemovalService.shared.execute($0)
    }) {
        self.load = load
        self.executeRemoval = executeRemoval
        self.readCapacity = capacity
    }

    var current: DiskNode? { pathStack.last ?? root }
    var breadcrumbs: [DiskNode] { root.map { [$0] + pathStack } ?? pathStack }
    var totalBytes: Int64 { current?.byteCount ?? 0 }
    var isBusy: Bool { isLoading || isPreparing || isRemoving }

    func scan(path: String? = nil) {
        guard !isPreparing, !isRemoving else { return }
        let target = path ?? selectedRootPath
        selectedRootPath = target
        beginLoad(path: target, append: false)
    }

    func drill(into node: DiskNode) {
        guard node.isDirectory, !node.isAggregate, !isPreparing, !isRemoving else { return }
        let trail = current.flatMap { Self.trail(to: node.id, in: $0) } ?? [node]
        beginLoad(path: node.path, append: true, intermediateNodes: Array(trail.dropLast()))
    }

    private static func trail(to id: UUID, in root: DiskNode) -> [DiskNode]? {
        for child in root.children {
            if child.id == id { return [child] }
            if let nested = trail(to: id, in: child) { return [child] + nested }
        }
        return nil
    }

    private func beginLoad(path: String, append: Bool, intermediateNodes: [DiskNode] = []) {
        task?.cancel()
        let run = UUID()
        generation = run
        removalPlan = nil
        errorMessage = nil
        isLoading = true
        statusText = "\(append ? "Opening" : "Scanning") \(URL(fileURLWithPath: path).lastPathComponent)…"
        let load = load
        let hidden = includeHidden
        let readCapacity = readCapacity
        task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                async let volume = try? await readCapacity(path)
                let node = try await load(path, hidden)
                let capacity = await volume
                guard let self, generation == run, !Task.isCancelled else { return }
                if append {
                    for parent in intermediateNodes { capacities[parent.id] = self.capacity }
                    pathStack.append(contentsOf: intermediateNodes)
                    pathStack.append(node)
                }
                else { root = node; pathStack = []; capacities = [:] }
                self.capacity = capacity
                capacities[node.id] = capacity
                statusText = summary(node)
                isLoading = false
                task = nil
            } catch {
                guard let self, generation == run else { return }
                isLoading = false
                statusText = error is CancellationError ? "Cancelled" : "Failed"
                if !(error is CancellationError) { errorMessage = error.localizedDescription }
                task = nil
            }
        }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        isLoading = false
        statusText = current.map(summary) ?? "Cancelled"
        if let root { selectedRootPath = root.path }
    }

    func goToBreadcrumb(index: Int) {
        guard !isPreparing, !isRemoving else { return }
        cancel()
        if index <= 0 { pathStack = [] }
        else if index <= pathStack.count { pathStack = Array(pathStack.prefix(index)) }
        if let current { statusText = summary(current); capacity = capacities[current.id] }
    }

    private func summary(_ node: DiskNode) -> String {
        "\(node.children.count) items · \(ByteFormat.string(for: node.byteCount))"
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func prepareRemoval(path: String, bytes: Int64) async {
        guard !isBusy else { return }
        isPreparing = true
        defer { isPreparing = false }
        let run = generation
        let plan = await RemovalService.shared.prepare([
            RemovalCandidate(path: path, bytes: bytes, safety: .caution,
                reason: "User-selected storage. May contain irreplaceable personal data.", ownerBundleID: CleanScanner.ownerBundleID(for: path))
        ], title: "Review storage removal")
        guard generation == run, !Task.isCancelled else { return }
        removalPlan = plan
    }

    func trash(_ plan: RemovalPlan) async {
        guard !isBusy else { return }
        isRemoving = true
        let run = generation
        defer { isRemoving = false }
        do {
            let result = try await executeRemoval(plan)
            removalResult = result
            isRemoving = false
            if generation == run, !Task.isCancelled, !result.successPaths.isEmpty {
                scan(path: current?.path ?? selectedRootPath)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    isolated deinit { task?.cancel() }
}
