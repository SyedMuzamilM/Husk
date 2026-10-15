import Foundation
import Testing
@testable import HuskCore

struct StorageMapTests {
    private func item(_ path: String, bytes: Int64 = 100, safety: SafetyLabel = .safe,
                      coverage: ScanCompleteness = .complete) -> CleanItem {
        CleanItem(name: "Fixture", path: path, categoryID: "fixture", categoryName: "Fixture",
                  byteCount: bytes, safety: safety, reason: "Fixture only", completeness: coverage)
    }

    @Test func summaryDeduplicatesOverlappingPathsAndKeepsConservativeExactPolicy() {
        let summary = StorageMapSummary(items: [
            item("/fixture/cache", bytes: 500), item("/fixture/cache/leaf"),
            item("/fixture/cache/leaf", safety: .protected),
            item("/fixture/cache-two", bytes: 200, safety: .review),
            item("/fixture/partial", bytes: 300, coverage: .partial)
        ])
        #expect(summary.safeBytes == 0)
        #expect(summary.reviewBytes == 500)
        #expect(summary.inspectionItems.count == 1)
        #expect(summary.safety(for: "/fixture/cache/leaf/file") == .protected)
        #expect(summary.safety(for: "/fixture/partial") == .review)
        #expect(summary.safety(for: "/fixture/cache-two-other") == nil)
    }

    @Test func folderCategoriesCannotGrantCleanupSafety() {
        let summary = StorageMapSummary(items: [])
        #expect(StorageCategory.classify("/fixture/work/app/node_modules") == .caches)
        #expect(StorageCategory.classify("/fixture/.ollama/models") == .models)
        #expect(StorageCategory.classify("/fixture/not-cache/cache-not-real") == .applications)
        #expect(summary.safety(for: "/fixture/work/app/node_modules") == nil)
    }

    @Test func omittedMapStorageHasStableIdentityAndNoRemovalTarget() {
        let child = DiskNode(name: "visible", path: "/fixture/visible", isDirectory: true, byteCount: 40)
        let root = DiskNode(name: "fixture", path: "/fixture", isDirectory: true, byteCount: 100, children: [child])
        #expect(root.mapChildren.last?.byteCount == 60)
        #expect(root.mapChildren.last?.isAggregate == true)
        #expect(root.mapChildren.last?.id == root.mapChildren.last?.id)
        let sharedBlocks = DiskNode(name: "fixture", path: "/fixture", isDirectory: true, byteCount: 20, children: [child])
        #expect(sharedBlocks.mapChildren.count == 1)
        let hiddenOnly = DiskNode(name: "hidden", path: "/fixture", isDirectory: true, byteCount: 20, omittedBytes: 20)
        #expect(hiddenOnly.mapChildren.count == 1)
        #expect(hiddenOnly.mapChildren.first?.isAggregate == true)
    }

    @Test func nestedPreviewsUseDisposableMetadataAndPreserveHiddenCoverage() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent("project"), withIntermediateDirectories: true)
        _ = try fixture.file("project/build.bin", bytes: 32768)
        _ = try fixture.file("project/.hidden.bin", bytes: 16384)
        let node = try await DiskAnalyzer().expand(path: fixture.root.path, includeHidden: false)
        let project = try #require(node.children.first { $0.name == "project" })
        #expect(project.children.contains { $0.name == "build.bin" })
        #expect(!project.children.contains { $0.name == ".hidden.bin" })
        #expect(project.mapChildren.contains { $0.isAggregate && $0.byteCount >= 16384 })
        #expect(node.byteCount >= 49152)
    }

    @Test func startupOverviewUsesInjectedRootsAndReportsRemainderAsInspectionOnly() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        _ = try fixture.file("data.bin", bytes: 32768)
        let root = fixture.root.path
        let analyzer = DiskAnalyzer(home: root, startupPaths: [root], capacity: { _ in
            DiskCapacity(totalBytes: 1_000_000, availableBytes: 100_000)
        })
        let disk = try await analyzer.expand(path: "/")
        #expect(disk.byteCount == 900_000)
        #expect(disk.completeness == .partial)
        #expect(disk.children.first?.path == PathSafety.canonicalPath(root) || disk.children.first?.path == root)
        #expect(disk.children.last?.isAggregate == true)
        #expect(disk.children.last?.isDirectory == false)
        #expect(disk.children.reduce(0) { $0 + $1.byteCount } == disk.byteCount)
    }

    @Test @MainActor func cancelledCapacityCannotReplaceANewerLocation() async throws {
        let capacities = DeferredValue<DiskCapacity>()
        let model = AnalyzeViewModel(load: { path, _ in DiskNode(name: path, path: path, isDirectory: true) },
                                     capacity: { _ in await capacities.value() })
        model.scan(path: "/first")
        try await waitUntil { await capacities.count == 1 }
        model.scan(path: "/second")
        try await waitUntil { await capacities.count == 2 }
        await capacities.resolveNext(DiskCapacity(totalBytes: 1000, availableBytes: 10))
        await capacities.resolveNext(DiskCapacity(totalBytes: 2000, availableBytes: 20))
        try await waitUntil { await !model.isLoading }
        #expect(model.current?.path == "/second")
        #expect(model.capacity?.totalBytes == 2000)
    }

    @Test @MainActor func capacityFailureDoesNotDiscardFolderResultsAndAggregatesCannotOpen() async throws {
        let model = AnalyzeViewModel(load: { path, _ in DiskNode(name: path, path: path, isDirectory: true) },
                                     capacity: { _ in throw CocoaError(.fileReadUnknown) })
        model.scan(path: "/fixture")
        try await waitUntil { await !model.isLoading }
        #expect(model.current?.path == "/fixture")
        #expect(model.capacity == nil)
        #expect(model.errorMessage == nil)
        model.drill(into: DiskNode(name: "aggregate", path: "/", isDirectory: true, isAggregate: true))
        #expect(!model.isLoading)
    }

    @Test @MainActor func mapSelectionUsesCompleteCachesRegardlessOfCleanupFilters() {
        let safe = item("/fixture/safe")
        let partial = item("/fixture/partial", coverage: .partial)
        let review = item("/fixture/review", safety: .review)
        let model = CleanViewModel()
        model.categories = [CleanCategory(id: "fixture", name: "Fixture", systemImage: "folder", items: [safe, partial, review])]
        model.selectedFilter = .ai
        #expect(model.filteredItems.isEmpty)
        model.selectMapCaches()
        #expect(model.selectedIDs == [safe.id])
        #expect(model.selectedBytes == safe.byteCount)
        model.clearSelection()
        model.phase = .trashing
        model.selectMapCaches()
        #expect(model.selectedIDs.isEmpty)
    }

    @Test @MainActor func breadcrumbsRestoreTheCapacityOfTheDisplayedVolume() async throws {
        let model = AnalyzeViewModel(load: { path, _ in DiskNode(name: path, path: path, isDirectory: true) },
            capacity: { path in DiskCapacity(totalBytes: path == "/root" ? 1000 : 2000, availableBytes: 100) })
        model.scan(path: "/root")
        try await waitUntil { await !model.isLoading }
        model.drill(into: DiskNode(name: "volume", path: "/root/volume", isDirectory: true))
        try await waitUntil { await !model.isLoading }
        #expect(model.capacity?.totalBytes == 2000)
        model.goToBreadcrumb(index: 0)
        #expect(model.capacity?.totalBytes == 1000)
        #expect(model.current?.path == "/root")
    }

    @Test @MainActor func openingNestedTilesPreservesIntermediateBreadcrumbs() async throws {
        let app = DiskNode(name: "App", path: "/fixture/Projects/App", isDirectory: true)
        let projects = DiskNode(name: "Projects", path: "/fixture/Projects", isDirectory: true, children: [app])
        let home = DiskNode(name: "Home", path: "/fixture", isDirectory: true, children: [projects])
        let model = AnalyzeViewModel(load: { path, _ in path == home.path ? home : app },
                                     capacity: { _ in DiskCapacity(totalBytes: 1000, availableBytes: 100) })
        model.scan(path: home.path)
        try await waitUntil { await !model.isLoading }
        model.drill(into: app)
        try await waitUntil { await !model.isLoading }
        #expect(model.breadcrumbs.map(\.name) == ["Home", "Projects", "App"])
        model.goToBreadcrumb(index: 1)
        #expect(model.current?.path == projects.path)
        #expect(model.capacity?.totalBytes == 1000)
    }
}
