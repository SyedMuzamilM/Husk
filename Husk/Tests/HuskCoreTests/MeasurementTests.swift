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
