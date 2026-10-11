import Foundation

actor CacheDetailService {
    func detail(for path: String, topN: Int = 40) async -> CacheDetailReport {
        do {
            let isDirectory = try await BlockingIO.run { _ in
                try URL(fileURLWithPath: path).resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            }
            if !isDirectory {
                let measured = try await DirectorySizer.measure(URL(fileURLWithPath: path))
                return CacheDetailReport(path: path, totalBytes: measured.bytes, immediateChildren: 0,
                    fileCountApprox: 1, folderCountApprox: 0, modified: measured.modified, topEntries: [],
                    scannedAt: Date(), completeness: measured.status, omittedBytes: 0, issues: measured.issues)
            }
            let listing = try await DirectorySizer.listing(of: URL(fileURLWithPath: path), maxChildren: topN)
            return CacheDetailReport(path: path, totalBytes: listing.total.bytes,
                immediateChildren: listing.children.count + listing.omittedCount,
                fileCountApprox: listing.children.filter { !$0.isDirectory }.count,
                folderCountApprox: listing.children.filter(\.isDirectory).count,
                modified: listing.total.modified, topEntries: listing.children.map {
                    CacheBreakdownEntry(name: $0.name, path: $0.path, byteCount: $0.bytes, isDirectory: $0.isDirectory)
                }, scannedAt: Date(), completeness: listing.total.status, omittedBytes: listing.omittedBytes,
                issues: listing.total.issues)
        } catch {
            return CacheDetailReport(path: path, totalBytes: 0, immediateChildren: 0,
                fileCountApprox: 0, folderCountApprox: 0, modified: nil, topEntries: [], scannedAt: Date(),
                completeness: .unavailable, omittedBytes: 0, issues: [OperationIssue(path: path, message: error.localizedDescription)])
        }
    }
}
