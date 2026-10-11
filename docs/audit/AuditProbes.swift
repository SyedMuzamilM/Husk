import Foundation
import Darwin

@main
struct AuditProbes {
    @MainActor
    static func main() async throws {
        if CommandLine.arguments.contains("--metrics") {
            print("METRICS production sample starting")
            fflush(stdout)
            let sampled = await SystemMetricsService().sample()
            print("METRICS production sample returned:", sampled.1.count)
            return
        }
        let fm = FileManager.default
        let fixture = fm.temporaryDirectory.appendingPathComponent("husk-audit-" + UUID().uuidString)
        try fm.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: fixture) }

        print("PATH protected keychains:", PathSafety.isProtected(NSHomeDirectory() + "/Library/Keychains"))
        print("PATH parent Library accepted:", !PathSafety.isProtected(NSHomeDirectory() + "/Library"))
        print("PATH ancestor /Users accepted:", !PathSafety.isProtected("/Users"))
        let alias = fixture.appendingPathComponent("alias")
        try fm.createSymbolicLink(at: alias, withDestinationURL: URL(fileURLWithPath: "/System"))
        print("PATH symlink ancestor bypass:", !PathSafety.isProtected(alias.appendingPathComponent("Library").path))

        let mapRoot = fixture.appendingPathComponent("map")
        try fm.createDirectory(at: mapRoot, withIntermediateDirectories: true)
        for n in 0..<10 {
            let folder = mapRoot.appendingPathComponent("folder-\(n)")
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 4096).write(to: folder.appendingPathComponent("small"))
        }
        let listing = try fm.contentsOfDirectory(at: mapRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let largest = listing.last!
        try Data(repeating: 1, count: 2 * 1024 * 1024).write(to: largest.appendingPathComponent("large"))
        let sampled = try await DirectorySizer.childSizes(of: mapRoot, maxChildren: 2)
        print("MAP largest omitted:", !sampled.contains(where: { $0.path == largest.path }), "retained:", sampled.count)
        let hidden = mapRoot.appendingPathComponent(".hidden")
        try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 3 * 1024 * 1024).write(to: hidden.appendingPathComponent("data"))
        let allVisible = try await DirectorySizer.childSizes(of: mapRoot, maxChildren: 40)
        print("MAP hidden omitted:", !allVisible.contains(where: { $0.path == hidden.path }))

        let node = DiskNode(name: "same", path: "/tmp/same", isDirectory: false, byteCount: 10)
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        print("MAP unstable rectangle identity:", TreemapLayout.squarify(nodes: [node], rect: rect).first!.id != TreemapLayout.squarify(nodes: [node], rect: rect).first!.id)

        let targets = CleanScanner.buildTargets()
        let grouped = Dictionary(grouping: targets, by: \.path)
        print("CLEAN exact duplicate target groups:", grouped.values.filter { $0.count > 1 }.count)
        let overlaps = targets.enumerated().reduce(0) { sum, entry in
            sum + targets.dropFirst(entry.offset + 1).filter { other in
                entry.element.path.hasPrefix(other.path + "/") || other.path.hasPrefix(entry.element.path + "/")
            }.count
        }
        print("CLEAN nested target pairs:", overlaps)

        let neverExists = fixture.appendingPathComponent("never-exists").path
        let model = CleanViewModel()
        let item = CleanItem(name: "fixture", path: neverExists, categoryID: "test", categoryName: "Test", byteCount: 10, safety: .safe, reason: "Fixture")
        model.categories = [CleanCategory(id: "test", name: "Test", systemImage: "folder", items: [item])]
        model.selectedIDs = [item.id]
        await model.moveSelectionToTrash()
        print("CLEAN nonexistent-path result:", model.phase)

        let analyze = AnalyzeViewModel()
        analyze.selectedRootPath = mapRoot.path
        print("ANALYZE nonexistent-path reports success:", await analyze.trash(neverExists))
        analyze.cancel()

        let matcher = TestableAppUninstallService()
        let tokens = await matcher.matchTokens(bundleID: "com.vendor.notes", appName: "Notes")
        print("APPS unrelated app data matches:", await matcher.matches(name: "com.unrelated.notes", path: "/fixture", tokens: tokens, bundleID: "com.vendor.notes"))

        let host = mach_host_self()
        func refs() -> mach_port_urefs_t {
            var count: mach_port_urefs_t = 0
            let result = mach_port_get_refs(mach_task_self_, host, MACH_PORT_RIGHT_SEND, &count)
            precondition(result == KERN_SUCCESS)
            return count
        }
        let before = refs()
        for _ in 0..<100 { _ = mach_host_self() }
        print("MACH host send-right refs before/after 100 unreleased calls:", before, refs())
        print("PROBES completed without trashing any files")
    }
}
