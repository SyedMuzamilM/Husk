//
//  DiskAnalyzer.swift
//  Husk
//

import Foundation

actor DiskAnalyzer {
    private var cancelled = false

    func cancel() { cancelled = true }
    func reset() { cancelled = false }

    /// Shallow concurrent size map for a root path (does not deep-walk twice).
    func analyze(
        rootPath: String,
        progress: @Sendable @escaping (String) -> Void
    ) async throws -> DiskNode {
        cancelled = false
        let rootURL = URL(fileURLWithPath: rootPath)
        progress("Listing \(rootURL.lastPathComponent)…")

        let root = DiskNode(
            name: rootURL.lastPathComponent.isEmpty ? rootPath : rootURL.lastPathComponent,
            path: rootPath,
            isDirectory: true
        )

        let children = try await DirectorySizer.childSizes(
            of: rootURL,
            maxChildren: 36
        ) { [cancelled] in
            cancelled || Task.isCancelled
        }

        progress("Building map…")

        for child in children {
            try checkCancel()
            root.addChild(
                DiskNode(
                    name: child.name,
                    path: child.path,
                    isDirectory: child.isDirectory,
                    byteCount: child.bytes
                )
            )
        }

        return root
    }

    /// Drill into a folder for more detail (one level, concurrent).
    func expand(path: String) async throws -> DiskNode {
        cancelled = false
        let url = URL(fileURLWithPath: path)
        let node = DiskNode(name: url.lastPathComponent, path: path, isDirectory: true)

        let children = try await DirectorySizer.childSizes(
            of: url,
            maxChildren: 48
        ) { [cancelled] in
            cancelled || Task.isCancelled
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
        if cancelled || Task.isCancelled { throw CancellationError() }
    }
}
