import AppKit
import Foundation

actor RemovalService {
    static let shared = RemovalService()
    private var executing = false
    private var completedPlans: [UUID: Date] = [:]
    private let move: (@Sendable (URL) throws -> URL)?
    private let recordHistory: Bool

    init(recordHistory: Bool = true, move: (@Sendable (URL) throws -> URL)? = nil) {
        self.recordHistory = recordHistory
        self.move = move
    }

    func prepare(_ candidates: [RemovalCandidate], title: String) async -> RemovalPlan {
        let running = await Self.runningBundleIDs()
        return (try? await BlockingIO.run { _ in
            RemovalPlan.prepare(candidates, title: title, runningBundleIDs: running)
        }) ?? RemovalPlan(id: UUID(), createdAt: Date(), title: title, entries: [], skipped: [OperationIssue(path: "", message: "Review cancelled.")])
    }

    func execute(_ plan: RemovalPlan) async throws -> TrashResult {
        guard !executing, completedPlans[plan.id] == nil else { throw RemovalError.busy }
        executing = true
        completedPlans = completedPlans.filter { Date().timeIntervalSince($0.value) < 300 }
        completedPlans[plan.id] = Date()
        defer { executing = false }
        let flag = CancelFlag()
        var result = await withTaskCancellationHandler {
            var aggregate = TrashResult()
            aggregate.skipped = plan.skipped
            for entry in plan.entries {
                if Task.isCancelled || flag.isCancelled { aggregate.cancelled = true; break }
                let running = await Self.runningBundleIDs()
                let single = RemovalPlan(id: plan.id, createdAt: plan.createdAt, title: plan.title, entries: [entry], skipped: [])
                let mover = move
                let result = await Task.detached(priority: .userInitiated) {
                    if let mover {
                        return TrashService.execute(single, runningBundleIDs: running, shouldCancel: { flag.isCancelled }, move: mover)
                    }
                    return TrashService.execute(single, runningBundleIDs: running, shouldCancel: { flag.isCancelled })
                }.value
                aggregate.destinations += result.destinations
                aggregate.failures += result.failures
                aggregate.totalBytes += result.totalBytes
                aggregate.cancelled = result.cancelled
            }
            return aggregate
        } onCancel: { flag.cancel() }
        if recordHistory {
            do { try await OperationJournal.shared.record(plan: plan, result: result) }
            catch { result.journalError = "Items already moved remain in Trash. Could not save history: " + error.localizedDescription }
        }
        await SizeCache.shared.clear()
        return result
    }

    @MainActor
    private static func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}
