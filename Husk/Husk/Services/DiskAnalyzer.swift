import Foundation

actor DiskAnalyzer {
    private let home: String
    private let startupPaths: [String]
    private let capacity: @Sendable (String) async throws -> DiskCapacity

    init(home: String = NSHomeDirectory(), startupPaths: [String]? = nil,
         capacity: @escaping @Sendable (String) async throws -> DiskCapacity = { try await DiskCapacity.read(at: $0) }) {
        self.home = home
        self.startupPaths = startupPaths ?? [home, "/Applications", "/Library", "/opt"]
        self.capacity = capacity
    }
    func analyze(rootPath: String, includeHidden: Bool = true,
                 progress: @Sendable @escaping (String) -> Void) async throws -> DiskNode {
        progress("Measuring folder contents…")
        return try await expand(path: rootPath, includeHidden: includeHidden)
    }

    func expand(path: String, includeHidden: Bool = true) async throws -> DiskNode {
        if path == "/" { return try await startupDisk(includeHidden: includeHidden) }
        let listing = try await DirectorySizer.listing(of: URL(fileURLWithPath: path), maxChildren: 100, includeHidden: includeHidden)
        try Task.checkCancellation()
        var children = listing.children.map {
            DiskNode(name: $0.name, path: $0.path, isDirectory: $0.isDirectory, byteCount: $0.bytes,
                     completeness: $0.measurement.status, issues: $0.measurement.issues)
        }
        // Bounded second-level previews. Opening a folder still makes a fresh listing.
        for index in children.indices.prefix(6) where children[index].isDirectory && children[index].byteCount > 0 {
            try Task.checkCancellation()
            let child = children[index]
            guard let preview = try? await DirectorySizer.listing(of: child.url, maxChildren: 12,
                includeHidden: includeHidden, deadline: 0.4, maxEntries: 12_000) else { continue }
            try Task.checkCancellation()
            let nested = preview.children.map {
                DiskNode(name: $0.name, path: $0.path, isDirectory: $0.isDirectory, byteCount: $0.bytes,
                         completeness: $0.measurement.status, issues: $0.measurement.issues)
            }
            children[index] = DiskNode(id: child.id, name: child.name, path: child.path, isDirectory: true,
                byteCount: child.byteCount, children: nested, completeness: child.completeness,
                omittedCount: preview.omittedCount, omittedBytes: max(0, child.byteCount - nested.reduce(0) { $0 + $1.byteCount }),
                issues: child.issues + preview.total.issues)
        }
        return DiskNode(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isDirectory: true,
                        byteCount: listing.total.bytes, children: children, completeness: listing.total.status,
                        omittedCount: listing.omittedCount, omittedBytes: listing.omittedBytes, issues: listing.total.issues)
    }

    /// Use normal filesystem paths so privacy exclusions cannot be bypassed by
    /// the Data volume's alternate /System/Volumes/Data/Users namespace.
    private func startupDisk(includeHidden: Bool) async throws -> DiskNode {
        let capacity = try await capacity(home)
        var children: [DiskNode] = []
        var issues: [OperationIssue] = []
        for path in startupPaths {
            try Task.checkCancellation()
            do {
                let listing = try await DirectorySizer.listing(of: URL(fileURLWithPath: path), maxChildren: 16,
                    includeHidden: includeHidden, deadline: 12, maxEntries: 250_000)
                let nested = listing.children.map {
                    DiskNode(name: $0.name, path: $0.path, isDirectory: $0.isDirectory, byteCount: $0.bytes,
                             completeness: $0.measurement.status, issues: $0.measurement.issues)
                }
                children.append(DiskNode(name: path == home ? "Home" : URL(fileURLWithPath: path).lastPathComponent,
                    path: path, isDirectory: true, byteCount: listing.total.bytes, children: nested,
                    completeness: listing.total.status, omittedCount: listing.omittedCount,
                    omittedBytes: listing.omittedBytes, issues: listing.total.issues))
                issues.append(contentsOf: listing.total.issues.prefix(max(0, 50 - issues.count)))
            } catch is CancellationError { throw CancellationError() }
            catch { issues.append(OperationIssue(path: path, message: error.localizedDescription)) }
        }
        let remainder = max(0, capacity.usedBytes - children.reduce(0) { $0 + $1.byteCount })
        children.append(DiskNode(name: "System & unmeasured", path: "/", isDirectory: false,
            byteCount: remainder, completeness: .partial, isAggregate: true))
        issues.insert(OperationIssue(path: "/", message: "Home, Applications, Library and /opt are measured with bounded scans. Remaining allocation includes macOS, snapshots, other users, protected paths and unfinished measurements. Mounted volumes are excluded."), at: 0)
        return DiskNode(name: "Startup disk", path: "/", isDirectory: true, byteCount: capacity.usedBytes,
                        children: children, completeness: .partial, issues: Array(issues.prefix(50)))
    }
}
