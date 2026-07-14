//
//  DiskAnalyzer.swift
//  Husk
//

import Foundation

actor DiskAnalyzer {
    private var cancelled = false

    func cancel() { cancelled = true }
    func reset() { cancelled = false }

    /// Builds a shallow tree for the given root (home or custom folder).
    func analyze(
        rootPath: String,
        progress: @Sendable @escaping (String) -> Void
    ) async throws -> DiskNode {
        cancelled = false
        let rootURL = URL(fileURLWithPath: rootPath)
        progress(rootPath)

        let root = DiskNode(
            name: rootURL.lastPathComponent.isEmpty ? rootPath : rootURL.lastPathComponent,
            path: rootPath,
            isDirectory: true
        )

        let children = try DirectorySizer.childSizes(of: rootURL, maxChildren: 60) { [cancelled] in
            cancelled
        }

        for child in children {
            try checkCancel()
            progress(child.path)
            let node = DiskNode(
                name: child.name,
                path: child.path,
                isDirectory: child.isDirectory,
                byteCount: child.bytes
            )

            // One extra level for large directories (better treemap)
            if child.isDirectory, child.bytes > 50_000_000 {
                if let grand = try? DirectorySizer.childSizes(
                    of: URL(fileURLWithPath: child.path),
                    maxChildren: 24,
                    shouldCancel: { [cancelled] in cancelled }
                ) {
                    for g in grand {
                        node.addChild(
                            DiskNode(
                                name: g.name,
                                path: g.path,
                                isDirectory: g.isDirectory,
                                byteCount: g.bytes
                            )
                        )
                    }
                    // Keep parent size from top-level measurement (more accurate than partial grandchildren)
                    // Re-assign: DiskNode byteCount was summed by addChild; reset to measured
                    // We need a way to set — use measured size as authoritative
                    _ = grand
                }
                // Force authoritative size
                // recreate approach: set via re-init pattern
            }

            // Use measured size as authority (addChild inflated if we added grand)
            let authoritative = DiskNode(
                name: child.name,
                path: child.path,
                isDirectory: child.isDirectory,
                byteCount: child.bytes,
                children: node.children
            )
            root.addChild(authoritative)
        }

        // Root total = sum of children (not full home walk)
        return root
    }

    /// Drill into a folder for more detail.
    func expand(path: String) async throws -> DiskNode {
        cancelled = false
        let url = URL(fileURLWithPath: path)
        let node = DiskNode(name: url.lastPathComponent, path: path, isDirectory: true)
        let children = try DirectorySizer.childSizes(of: url, maxChildren: 80) { [cancelled] in
            cancelled
        }
        for child in children {
            try checkCancel()
            node.addChild(
                DiskNode(
                    name: child.name,
                    path: child.path,
                    isDirectory: child.isDirectory,
                    byteCount: child.bytes
                )
            )
        }
        return node
    }

    private func checkCancel() throws {
        if cancelled { throw CancellationError() }
    }
}
