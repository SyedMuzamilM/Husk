import Foundation
import Testing
@testable import HuskCore

struct MeasurementTests {
    @Test func largestHiddenAndPackageContentsAreMeasuredBeforeLimit() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for index in 0..<50 { _ = try fixture.file("small-\(index)") }
        let hidden = try fixture.file(".largest", bytes: 1_048_576)
        let listing = try await DirectorySizer.listing(of: fixture.root, maxChildren: 1)
        #expect(listing.children.first?.path == PathSafety.canonicalPath(hidden.path))
        #expect(listing.omittedCount == 50)
        #expect(listing.total.bytes > (listing.children.first?.bytes ?? 0))
        let package = fixture.root.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data(repeating: 17, count: 8192).write(to: package.appendingPathComponent("data"))
        #expect(try await DirectorySizer.measure(package).bytes >= 8192)
    }

    @Test func hardlinksAreCountedOnceAndSymlinksNotFollowed() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let original = try fixture.file("original", bytes: 16384)
        let size = try DirectorySizer.measurement(of: original).bytes
        try FileManager.default.linkItem(at: original, to: fixture.root.appendingPathComponent("hardlink"))
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("symbolic"), withDestinationURL: URL(fileURLWithPath: "/System"))
        #expect(try DirectorySizer.measurement(of: fixture.root).bytes == size)
    }

    @Test func budgetsAndCancellationAreExplicit() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        _ = try fixture.file("one")
        #expect(try DirectorySizer.measurement(of: fixture.root, maxEntries: 0).status == .partial)
        #expect(throws: CancellationError.self) { try DirectorySizer.measurement(of: fixture.root, shouldCancel: { true }) }
    }

    @Test func listingStopsAtItsEntryBudgetAndReportsPartialCoverage() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for index in 0..<20 { _ = try fixture.file("file-\(index)") }
        let listing = try await DirectorySizer.listing(of: fixture.root, maxChildren: 2, maxEntries: 5)
        #expect(listing.total.status == .partial)
        #expect(listing.total.visitedEntries == 5)
        #expect(listing.children.count == 2)
        #expect(!listing.total.issues.isEmpty)
        let expired = try await DirectorySizer.listing(of: fixture.root, deadline: 0)
        #expect(expired.total.status == .partial)
        #expect(expired.total.visitedEntries == 0)
        #expect(expired.children.isEmpty)
    }

    @Test func streamingListingRetainsLargestRowsAndCountsHiddenBytes() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for index in 0..<30 { _ = try fixture.file("small-\(index)") }
        _ = try fixture.file("large-b", bytes: 32768)
        _ = try fixture.file("large-a", bytes: 32768)
        _ = try fixture.file(".hidden-largest", bytes: 65536)
        let listing = try await DirectorySizer.listing(of: fixture.root, maxChildren: 2, includeHidden: false)
        #expect(listing.children.map(\.name) == ["large-a", "large-b"])
        #expect(listing.total.status == .complete)
        #expect(listing.total.visitedEntries == 33)
        #expect(listing.omittedCount == 31)
        #expect(listing.omittedBytes >= 65536)
        let totalsOnly = try await DirectorySizer.listing(of: fixture.root, maxChildren: 0)
        #expect(totalsOnly.children.isEmpty)
        #expect(totalsOnly.total.bytes == listing.total.bytes)
    }

    @Test func listingParentCountsHardlinksAcrossSubtreesOnce() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let original = try fixture.file("original", bytes: 16384)
        let package = fixture.root.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try FileManager.default.linkItem(at: original, to: package.appendingPathComponent("shared"))
        let allocated = try DirectorySizer.measurement(of: original).bytes
        let listing = try await DirectorySizer.listing(of: fixture.root)
        #expect(listing.total.status == .complete)
        #expect(listing.total.bytes == allocated)
        #expect(listing.children.first(where: { $0.name == "Fake.app" })?.bytes == allocated)
        #expect(listing.children.reduce(0) { $0 + $1.bytes } == allocated * 2)
    }

    @Test func listingPropagatesSkippedDataAndBudgetsThroughNestedFolders() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let directory = fixture.root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<10 { try Data(repeating: 1, count: 4096).write(to: directory.appendingPathComponent("file-\(index)")) }
        let limited = try await DirectorySizer.listing(of: fixture.root, maxEntries: 3)
        #expect(limited.total.status == .partial)
        #expect(limited.total.visitedEntries == 3)
        #expect(limited.children.first?.measurement.status == .partial)
        let protected = fixture.root.appendingPathComponent(".Trash")
        try FileManager.default.createDirectory(at: protected, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 65536).write(to: protected.appendingPathComponent("private"))
        let listing = try await DirectorySizer.listing(of: fixture.root)
        #expect(listing.total.status == .partial)
        #expect(listing.children.first(where: { $0.name == ".Trash" })?.measurement.status == .unavailable)
        #expect(listing.total.bytes < 65536)
    }

    @Test func exactBundleIDPathsCannotMatchAnotherApplication() {
        let paths = AppUninstallService.associatedPaths(bundleID: "com.example.tool", home: "/tmp/home")
        #expect(paths.allSatisfy { URL(fileURLWithPath: $0.path).lastPathComponent == "com.example.tool" || $0.path.hasSuffix("/com.example.tool.plist") || $0.path.hasSuffix("/com.example.tool.savedState") })
        #expect(!paths.contains { $0.path.contains("Group Containers") })
        #expect(AppUninstallService.associatedPaths(bundleID: "../tool", home: "/tmp/home").isEmpty)
    }

    @Test func projectDiscoveryRequiresManifestAndLeavesAmbiguousDataAlone() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        for name in [".next", "build", ".venv", "node_modules", ".git"] {
            try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        #expect(ProjectArtifactService.discover(roots: [fixture.root.path]).isEmpty)
        _ = try fixture.file("package.json")
        let artifacts = ProjectArtifactService.discover(roots: [fixture.root.path, fixture.root.path])
        #expect(artifacts.count == 1)
        #expect(artifacts.first?.kind == ".next")
        #expect(artifacts.first?.safety == .protected)
    }
}

struct ListingPolicyTests {
    @Test func cancelledListingDoesNotPublishAResult() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        _ = try fixture.file("one")
        let task = Task { try await DirectorySizer.listing(of: fixture.root) }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled listing returned a result") }
        catch is CancellationError { }
    }

    @Test func protectedRootAndSymlinkRootAreNotListed() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let alias = fixture.root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: URL(fileURLWithPath: "/System"))
        #expect(try await DirectorySizer.measure(alias).status == .unavailable)
        do { _ = try await DirectorySizer.listing(of: alias); Issue.record("Protected symlink was listed") }
        catch RemovalError.changed { }
        do { _ = try await DirectorySizer.listing(of: URL(fileURLWithPath: NSHomeDirectory() + "/.ssh")); Issue.record("Credential folder was listed") }
        catch RemovalError.changed { }
    }
}
