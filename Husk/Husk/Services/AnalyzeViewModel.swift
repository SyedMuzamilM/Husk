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
    var statusText = "Pick a location to map"
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

    var totalBytes: Int64 {
        current?.byteCount ?? root?.byteCount ?? 0
    }

    func scan(path: String? = nil) {
        let target = path ?? selectedRootPath
        selectedRootPath = target
        task?.cancel()
        Task { await analyzer.cancel() }

        task = Task {
            isLoading = true
            errorMessage = nil
            statusText = "Scanning \(URL(fileURLWithPath: target).lastPathComponent)…"
            pathStack = []
            root = nil
            await analyzer.reset()

            do {
                let node = try await analyzer.analyze(rootPath: target) { [weak self] p in
                    Task { @MainActor in
                        self?.statusText = p
                    }
                }
                guard !Task.isCancelled else {
                    isLoading = false
                    statusText = "Cancelled"
                    return
                }
                root = node
                statusText = "\(node.children.count) items · \(ByteFormat.string(for: node.byteCount))"
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
        if root == nil {
            statusText = "Cancelled"
        }
    }

    func drill(into node: DiskNode) {
        guard node.isDirectory else { return }
        task?.cancel()
        Task { await analyzer.cancel() }

        task = Task {
            isLoading = true
            statusText = "Opening \(node.name)…"
            errorMessage = nil
            await analyzer.reset()

            do {
                let expanded = try await analyzer.expand(path: node.path)
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                pathStack.append(expanded)
                isLoading = false
                statusText = "\(expanded.children.count) items · \(ByteFormat.string(for: expanded.byteCount))"
            } catch is CancellationError {
                isLoading = false
                statusText = "Cancelled"
            } catch {
                if !node.children.isEmpty {
                    pathStack.append(node)
                    statusText = node.path
                } else {
                    errorMessage = error.localizedDescription
                    statusText = "Failed"
                }
                isLoading = false
            }
        }
    }

    func goToBreadcrumb(index: Int) {
        if index <= 0 {
            pathStack = []
            if let root {
                statusText = "\(root.children.count) items · \(ByteFormat.string(for: root.byteCount))"
            }
            return
        }
        let stackIndex = index - 1
        if stackIndex < pathStack.count {
            pathStack = Array(pathStack.prefix(stackIndex + 1))
            if let current {
                statusText = "\(current.children.count) items · \(ByteFormat.string(for: current.byteCount))"
            }
        }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func trash(_ path: String) async -> Bool {
        if PathSafety.isProtected(path) { return false }
        do {
            _ = try TrashService.moveToTrash(paths: [path])
            if let current, current.path != path {
                scan(path: current.path)
            } else if let parent = pathStack.dropLast().last {
                pathStack.removeLast()
                scan(path: parent.path)
            } else {
                scan(path: selectedRootPath)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
