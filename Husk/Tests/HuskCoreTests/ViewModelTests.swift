import Foundation
import Testing
@testable import HuskCore

@MainActor
struct ViewModelTests {
    @Test func closingMapDuringRemovalDoesNotStartAnotherScan() async throws {
        let gate = DeferredValue<TrashResult>()
        let model = AnalyzeViewModel(load: { path, _ in
            Issue.record("Closed map started a new scan")
            return DiskNode(name: "fixture", path: path, isDirectory: true)
        }, executeRemoval: { _ in await gate.value() })
        let plan = RemovalPlan(id: UUID(), createdAt: Date(), title: "Fixture", entries: [], skipped: [])
        let removal = Task { await model.trash(plan) }
        try await waitUntil { await gate.count == 1 }
        model.cancel()
        await gate.resolve(TrashResult(destinations: [TrashDestination(originalPath: "/fixture", trashPath: "/fixture-trash")]))
        await removal.value
        try await Task.sleep(for: .milliseconds(20))
        #expect(!model.isLoading)
        #expect(model.removalResult?.successCount == 1)
    }

    @Test func cancelledMapDoesNotReturnToLoading() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let model = AnalyzeViewModel()
        model.scan(path: fixture.root.path)
        model.cancel()
        try await Task.sleep(for: .milliseconds(150))
        #expect(!model.isLoading)
    }

    @Test func cleanScanReleasesItsOwnerWhileWorkIsSuspended() async throws {
        let gate = DeferredValue<CleanScanResult>()
        var model: CleanViewModel? = CleanViewModel(scan: { _ in await gate.value() })
        weak var reference = model
        model?.startScan()
        try await waitUntil { await gate.count == 1 }
        model = nil
        #expect(reference == nil)
        await gate.resolve(CleanScanResult(categories: [], scannedAt: Date(), duration: 0))
    }

    @Test func mapReleasesItsOwnerWhileWorkIsSuspended() async throws {
        let gate = DeferredValue<DiskNode>()
        var model: AnalyzeViewModel? = AnalyzeViewModel(load: { _, _ in await gate.value() })
        weak var reference = model
        model?.scan(path: "/fixture")
        try await waitUntil { await gate.count == 1 }
        model = nil
        #expect(reference == nil)
        await gate.resolve(DiskNode(name: "fixture", path: "/fixture", isDirectory: true))
    }

    @Test func appDiscoveryReleasesItsOwnerWhileWorkIsSuspended() async throws {
        let gate = DeferredValue<[AppEntry]>()
        var model: AppsViewModel? = AppsViewModel(load: { await gate.value() })
        weak var reference = model
        model?.loadApps()
        try await waitUntil { await gate.count == 1 }
        model = nil
        #expect(reference == nil)
        await gate.resolve([])
    }

    @Test func aiScanReleasesItsOwnerWhileWorkIsSuspended() async throws {
        let gate = DeferredValue<AIStorageReport>()
        var model: AIStorageViewModel? = AIStorageViewModel(scan: { await gate.value() })
        weak var reference = model
        model?.scan()
        try await waitUntil { await gate.count == 1 }
        model = nil
        #expect(reference == nil)
        await gate.resolve(AIStorageReport(items: [], issues: [], scannedAt: Date()))
    }

    @Test func oldMapCannotReplaceTheNewLocation() async throws {
        let gate = DeferredValue<DiskNode>()
        let model = AnalyzeViewModel(load: { _, _ in await gate.value() })
        model.scan(path: "/first")
        try await waitUntil { await gate.count == 1 }
        model.scan(path: "/second")
        try await waitUntil { await gate.count == 2 }
        await gate.resolveNext(DiskNode(name: "first", path: "/first", isDirectory: true))
        await gate.resolveNext(DiskNode(name: "second", path: "/second", isDirectory: true))
        try await waitUntil { await !model.isLoading }
        #expect(model.current?.path == "/second")
    }

    @Test func cancelledAIFailureCannotOverwriteTheNextScan() async throws {
        enum Failure: Error { case oldScan }
        let gate = DeferredValue<Result<AIStorageReport, Failure>>()
        let model = AIStorageViewModel(scan: { try await gate.value().get() })
        model.scan()
        try await waitUntil { await gate.count == 1 }
        model.cancel()
        model.scan()
        try await waitUntil { await gate.count == 2 }
        await gate.resolveNext(.failure(.oldScan))
        await gate.resolveNext(.success(AIStorageReport(items: [], issues: [], scannedAt: .distantPast)))
        try await waitUntil { await !model.isScanning }
        #expect(model.errorMessage == nil)
        #expect(model.report?.scannedAt == .distantPast)
    }

    @Test func refreshingAppsClearsRemovedSelectionAndRelatedFiles() async throws {
        let model = AppsViewModel(load: { [] })
        let app = AppEntry(id: "/fixture/app", name: "App", path: "/fixture/app", bundleIdentifier: "dev.fixture.app",
                           version: nil, byteCount: 100, isFromSystem: false)
        model.apps = [app]
        model.selectedApp = app
        model.leftovers = [LeftoverItem(path: "/fixture/cache", byteCount: 100, kind: "Cache")]
        model.loadApps()
        try await waitUntil { await !model.isLoadingApps }
        #expect(model.selectedApp == nil)
        #expect(model.leftovers.isEmpty)
        #expect(model.apps.isEmpty)
    }

    @Test func cachedCleanupRowsAndTotalsFollowFiltersAndNewMeasurements() {
        let model = CleanViewModel()
        let id = UUID()
        func item(_ bytes: Int64) -> CleanItem {
            CleanItem(id: id, name: "Compiler", path: "/fixture/compiler", categoryID: "developer",
                      categoryName: "Developer", byteCount: bytes, safety: .review, reason: "Fixture")
        }
        func category(_ bytes: Int64) -> CleanCategory {
            CleanCategory(id: "developer", name: "Developer", systemImage: "hammer", items: [item(bytes)])
        }
        model.categories = [category(10)]
        model.selectedIDs = [id]
        #expect(model.filteredItems.count == 1)
        #expect(model.selectedBytes == 10)
        model.searchText = "missing"
        #expect(model.filteredItems.isEmpty)
        #expect(model.selectedBytes == 10)
        model.searchText = " compiler "
        #expect(model.filteredItems.count == 1)
        model.categories = [category(20)]
        #expect(model.filteredItems.first?.byteCount == 20)
        #expect(model.selectedBytes == 20)
        #expect(model.totalBytes == 20)
        model.selectedFilter = .ai
        #expect(model.filteredItems.isEmpty)
        model.categories = []
        #expect(model.selectedItems.isEmpty)
        #expect(model.selectedBytes == 0)
    }

    @Test func bulkSelectionRespectsFiltersRiskAndBusyState() {
        let model = CleanViewModel()
        let items = [SafetyLabel.safe, .review, .protected].map { safety in
            CleanItem(name: "Cache", path: "/fixture/\(safety)", categoryID: "developer",
                      categoryName: "Developer", byteCount: 10, safety: safety, reason: "Fixture")
        }
        let category = CleanCategory(id: "developer", name: "Developer", systemImage: "hammer", items: items)
        model.categories = [category]
        model.selectedFilter = .ai
        model.selectAllSafe()
        #expect(model.selectedIDs.isEmpty)
        model.selectedFilter = .all
        model.selectAllSafe()
        #expect(model.selectedIDs == [items[0].id])
        model.selectAll(in: category)
        #expect(model.selectedItems.count == 2)
        #expect(model.selectedBytes == 20)
        model.phase = .trashing
        model.deselectAll(in: category)
        #expect(model.selectedItems.count == 2)
        model.phase = .ready
        model.deselectAll(in: category)
        #expect(model.selectedItems.isEmpty)
        #expect(model.selectedBytes == 0)
    }
}

/// Deliberately ignores cancellation, like a blocked OS call, until the test releases it.
actor DeferredValue<Value: Sendable> {
    private var pending: [CheckedContinuation<Value, Never>] = []
    var count: Int { pending.count }
    func value() async -> Value {
        await withCheckedContinuation { pending.append($0) }
    }
    func resolve(_ value: Value) {
        let continuations = pending
        pending = []
        for continuation in continuations { continuation.resume(returning: value) }
    }
    func resolveNext(_ value: Value) { pending.removeFirst().resume(returning: value) }
}

func waitUntil(_ condition: @escaping @Sendable () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw NSError(domain: "FixtureTimeout", code: 1)
}

@MainActor
struct InteractionBenchmarks {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["HUSK_RUN_INTERACTION_BENCHMARKS"] == "1"))
    func prepareLargeReview() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let candidates = try (0..<300).map { index in
            RemovalCandidate(path: try fixture.file("review-\(index)", bytes: 0).path,
                             bytes: 0, safety: .review, reason: "Fixture")
        }
        let start = ContinuousClock.now
        let plan = RemovalPlan.prepare(candidates, title: "Fixture", excludedPaths: [])
        #expect(plan.entries.count == candidates.count)
        print("BENCH prepare-review count=300 elapsed=\(start.duration(to: .now))")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["HUSK_RUN_INTERACTION_BENCHMARKS"] == "1"))
    func resultRedrawAndTargetDiscovery() throws {
        let model = CleanViewModel()
        let items = (0..<10_000).map { index in
            CleanItem(name: "Cache \(index)", path: "/fixture/cache-\(index)",
                      categoryID: "developer", categoryName: "Developer", byteCount: Int64(index),
                      safety: .safe, reason: "Benchmark fixture")
        }
        model.categories = [CleanCategory(id: "developer", name: "Developer", systemImage: "hammer", items: items)]
        let start = ContinuousClock.now
        var count = 0
        for index in 0..<50 {
            model.selectedIDs = [items[index].id]
            count += model.filteredItems.count
            #expect(model.selectedBytes == Int64(index))
        }
        #expect(count == 500_000)
        print("BENCH redraw rows=10000 passes=50 elapsed=\(start.duration(to: .now))")
        let selection = ContinuousClock.now
        model.selectAllSafe()
        #expect(model.selectedItems.count == items.count)
        model.deselectAll(in: model.categories[0])
        #expect(model.selectedItems.isEmpty)
        print("BENCH bulk-selection rows=10000 elapsed=\(selection.duration(to: .now))")

        let fixture = try Fixture(); defer { fixture.clean() }
        let targets = (0..<1_000).map { index in
            CleanTarget(categoryID: "fixture", categoryName: "Fixture", systemImage: "folder",
                        name: "Cache \(index)", path: fixture.root.appendingPathComponent("cache-\(index)").path,
                        safetyOverride: nil, reasonOverride: nil)
        }
        let discovery = ContinuousClock.now
        #expect(CleanScanner.uniqueTargets(targets).count == targets.count)
        print("BENCH target-dedup count=1000 elapsed=\(discovery.duration(to: .now))")
    }
}
