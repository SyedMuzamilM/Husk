import Foundation
import Testing
@testable import HuskCore

struct SafetyTests {
    @Test func sensitiveParentsAreProtected() {
        #expect(PathSafety.isProtected(NSHomeDirectory() + "/Library"))
        #expect(PathSafety.isProtected("/Users"))
        #expect(PathSafety.isProtected(NSHomeDirectory() + "/.Trash"))
    }

    @Test func symlinkedAncestorCannotBypassProtection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: URL(fileURLWithPath: "/System"))
        #expect(PathSafety.isProtected(alias.appendingPathComponent("Library").path))
    }

    @Test func unknownCachesRequireReview() {
        let classification = PathSafety.classifyCachePath(NSHomeDirectory() + "/Library/Caches/unknown-app")
        #expect(classification.0 != .safe)
    }

    @Test func historiesAndInstalledToolsAreNotBulkSafeTargets() {
        let targets = CleanScanner.buildTargets()
        for target in targets where target.path.hasSuffix("/dev_data") || target.path.hasSuffix("/.gemini/tmp") {
            #expect(target.safetyOverride != .safe)
        }
    }

    @Test func treemapIdentityIsStable() {
        let node = DiskNode(name: "same", path: "/tmp/same", isDirectory: false, byteCount: 10)
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(TreemapLayout.squarify(nodes: [node], rect: bounds).first?.id ==
                TreemapLayout.squarify(nodes: [node], rect: bounds).first?.id)
    }
}

struct CanonicalPathTests {
    @Test func macOSAliasesResolveToStableRealPaths() throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let file = try fixture.file("alias")
        let canonical = PathSafety.canonicalPath(file.path)
        #expect(canonical.hasPrefix("/private/tmp/"))
        #expect(PathSafety.canonicalPath(canonical) == canonical)
        #expect(PathSafety.canonicalPath(canonical.replacingOccurrences(of: "/private/tmp/", with: "/tmp/")) == canonical)
        #expect(PathSafety.isSensitiveForReading("/private/var/db/something"))
    }
}
