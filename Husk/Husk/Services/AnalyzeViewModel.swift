//
//  AnalyzeViewModel.swift
//  Husk
//

import AppKit
import Foundation

@Observable
@MainActor
final class AnalyzeViewModel {
    var removalPlan: RemovalPlan?
    var removalResult: TrashResult?
    var includeHidden = true
    private var generation = UUID()
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
        generation = UUID()

        removalPlan = nil
        let run = generation
        task = Task {
            isLoading = true
            errorMessage = nil
            statusText = "Scanning \(URL(fileURLWithPath: target).lastPathComponent)…"
            pathStack = []

            do {
                let analyzerService = analyzer
                let model = self
                let node = try await analyzerService.analyze(rootPath: target, includeHidden: includeHidden) { [weak model] p in
                    Task { @MainActor [weak model] in
                        if model?.generation == run { model?.statusText = p }
                    }
                }
                guard generation == run else { return }
                guard !Task.isCancelled else {
                    isLoading = false
                    statusText = "Cancelled"
                    return
                }
                root = node
                statusText = "\(node.children.count) items · \(ByteFormat.string(for: node.byteCount))"
                isLoading = false
            } catch is CancellationError {
                guard generation == run else { return }
                isLoading = false
                statusText = "Cancelled"
            } catch {
                guard generation == run else { return }
                isLoading = false
                errorMessage = error.localizedDescription
                statusText = "Failed"
            }
        }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        isLoading = false
        if root == nil {
            statusText = "Cancelled"
        }
    }

    func drill(into node: DiskNode) {
        guard node.isDirectory else { return }
        task?.cancel()
        generation = UUID()

        removalPlan = nil
        let run = generation
        task = Task {
            isLoading = true
            statusText = "Opening \(node.name)…"
            errorMessage = nil

            do {
                let expanded = try await analyzer.expand(path: node.path, includeHidden: includeHidden)
                guard generation == run else { return }
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                pathStack.append(expanded)
                isLoading = false
                statusText = "\(expanded.children.count) items · \(ByteFormat.string(for: expanded.byteCount))"
            } catch is CancellationError {
                guard generation == run else { return }
                isLoading = false
                statusText = "Cancelled"
            } catch {
                guard generation == run else { return }
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
        cancel()
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

    func prepareRemoval(path: String, bytes: Int64) async {
        let run = generation
        let plan = await RemovalService.shared.prepare([
            RemovalCandidate(path: path, bytes: bytes, safety: .caution,
                reason: "User-selected storage. May contain irreplaceable personal data.", ownerBundleID: CleanScanner.ownerBundleID(for: path))
        ], title: "Review storage removal")
        guard generation == run else { return }
        removalPlan = plan
    }

    func trash(_ plan: RemovalPlan) async {
        do {
            let result = try await RemovalService.shared.execute(plan)
            removalResult = result
            if !result.successPaths.isEmpty { scan(path: current?.path ?? selectedRootPath) }
        } catch { errorMessage = error.localizedDescription }
    }
}
