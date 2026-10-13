import AppKit
import Foundation

@Observable @MainActor
final class AnalyzeViewModel {
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var includeHidden = true
    var root: DiskNode?
    var pathStack: [DiskNode] = []
    var isLoading = false
    private(set) var isPreparing = false
    private(set) var isRemoving = false
    var statusText = "Pick a location to map"
    var errorMessage: String?
    var selectedRootPath: String = NSHomeDirectory()

    private var generation = UUID()
    private var task: Task<Void, Never>?
    private let load: @Sendable (String, Bool) async throws -> DiskNode
    private let executeRemoval: @Sendable (RemovalPlan) async throws -> TrashResult

    init(load: @escaping @Sendable (String, Bool) async throws -> DiskNode = {
        try await DiskAnalyzer().expand(path: $0, includeHidden: $1)
    }, executeRemoval: @escaping @Sendable (RemovalPlan) async throws -> TrashResult = {
        try await RemovalService.shared.execute($0)
    }) {
        self.load = load
        self.executeRemoval = executeRemoval
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
        guard node.isDirectory, !isPreparing, !isRemoving else { return }
        beginLoad(path: node.path, append: true)
    }

    private func beginLoad(path: String, append: Bool) {
        task?.cancel()
        let run = UUID()
        generation = run
        removalPlan = nil
        errorMessage = nil
        isLoading = true
        statusText = "\(append ? "Opening" : "Scanning") \(URL(fileURLWithPath: path).lastPathComponent)…"
        let load = load
        let hidden = includeHidden
        task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let node = try await load(path, hidden)
                guard let self, generation == run, !Task.isCancelled else { return }
                if append { pathStack.append(node) }
                else { root = node; pathStack = [] }
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
        if let current { statusText = summary(current) }
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
