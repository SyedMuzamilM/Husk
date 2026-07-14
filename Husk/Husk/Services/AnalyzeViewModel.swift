//
//  AnalyzeViewModel.swift
//  Husk
//

import AppKit
import Foundation

@Observable
@MainActor
final class AnalyzeViewModel {
    var root: DiskNode?
    var pathStack: [DiskNode] = []
    var isLoading = false
    var statusText = ""
    var errorMessage: String?
    var selectedRootPath: String = NSHomeDirectory()

    private let analyzer = DiskAnalyzer()
    private var task: Task<Void, Never>?

    var current: DiskNode? {
        pathStack.last ?? root
    }

    var breadcrumbs: [DiskNode] {
        if let root {
            return [root] + pathStack
        }
        return pathStack
    }

    func scan(path: String? = nil) {
        let target = path ?? selectedRootPath
        selectedRootPath = target
        task?.cancel()
        task = Task {
            isLoading = true
            errorMessage = nil
            statusText = "Scanning…"
            pathStack = []
            await analyzer.reset()

            do {
                let node = try await analyzer.analyze(rootPath: target) { [weak self] p in
                    Task { @MainActor in
                        self?.statusText = p
                    }
                }
                guard !Task.isCancelled else { return }
                root = node
                statusText = "Ready"
                isLoading = false
            } catch is CancellationError {
                isLoading = false
                statusText = "Cancelled"
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                statusText = "Failed"
            }
        }
    }

    func cancel() {
        Task { await analyzer.cancel() }
        task?.cancel()
        isLoading = false
    }

    func drill(into node: DiskNode) {
        guard node.isDirectory else { return }
        task?.cancel()
        task = Task {
            isLoading = true
            statusText = "Opening \(node.name)…"
            do {
                let expanded = try await analyzer.expand(path: node.path)
                guard !Task.isCancelled else { return }
                pathStack.append(expanded)
                isLoading = false
                statusText = expanded.path
            } catch {
                // Fall back to existing children if any
                if !node.children.isEmpty {
                    pathStack.append(node)
                } else {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    func goToBreadcrumb(index: Int) {
        // index 0 = root
        if index <= 0 {
            pathStack = []
            return
        }
        // breadcrumbs = [root] + pathStack, so pathStack index = index - 1
        let stackIndex = index - 1
        if stackIndex < pathStack.count {
            pathStack = Array(pathStack.prefix(stackIndex + 1))
        }
    }

    func reveal(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func trash(_ path: String) async -> Bool {
        if PathSafety.isProtected(path) { return false }
        do {
            _ = try TrashService.moveToTrash(paths: [path])
            // Refresh current level
            if let current {
                scan(path: current.path)
            } else {
                scan()
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
