import Foundation

actor DiskAnalyzer {
    func analyze(rootPath: String, includeHidden: Bool = true,
                 progress: @Sendable @escaping (String) -> Void) async throws -> DiskNode {
        progress("Measuring folder contents…")
        return try await expand(path: rootPath, includeHidden: includeHidden)
    }

    func expand(path: String, includeHidden: Bool = true) async throws -> DiskNode {
        let listing = try await DirectorySizer.listing(of: URL(fileURLWithPath: path), maxChildren: 100, includeHidden: includeHidden)
        try Task.checkCancellation()
        let children = listing.children.map {
            DiskNode(name: $0.name, path: $0.path, isDirectory: $0.isDirectory, byteCount: $0.bytes,
                     completeness: $0.measurement.status, issues: $0.measurement.issues)
        }
        return DiskNode(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isDirectory: true,
                        byteCount: listing.total.bytes, children: children, completeness: listing.total.status,
                        omittedCount: listing.omittedCount, omittedBytes: listing.omittedBytes, issues: listing.total.issues)
    }
}
