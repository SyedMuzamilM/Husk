//
//  StatusViewModel.swift
//  Husk
//

import Foundation

@Observable
@MainActor
final class StatusViewModel {
    var snapshot = SystemSnapshot()
    var processes: [ProcessInfoRow] = []
    var isSampling = false
    var sort: ProcessSort = .cpu
    var searchText = ""
    var lastError: String?
    var statusLine = "Idle"

    private let service = SystemMetricsService()
    private var loopTask: Task<Void, Never>?

    enum ProcessSort: String, CaseIterable, Identifiable {
        case cpu, memory, name
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cpu: "CPU"
            case .memory: "Memory"
            case .name: "Name"
            }
        }
    }

    var filteredProcesses: [ProcessInfoRow] {
        var list = processes
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(q) || "\($0.pid)".contains(q)
            }
        }
        switch sort {
        case .cpu: list.sort { $0.cpuPercent > $1.cpuPercent }
        case .memory: list.sort { $0.memoryBytes > $1.memoryBytes }
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }

    func start() {
        guard loopTask == nil else { return }
        isSampling = true
        statusLine = "Sampling…"
        loopTask = Task { [weak self] in
            await self?.tick()
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1500))
                if Task.isCancelled { break }
                await self.tick()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isSampling = false
        statusLine = "Paused"
    }

    private func tick() async {
        let (snap, procs) = await service.sample(topProcessLimit: 40)
        guard !Task.isCancelled else { return }
        snapshot = snap
        processes = procs
        statusLine = "Updated \(snap.timestamp.formatted(date: .omitted, time: .standard))"
    }

    func terminate(pid: Int32, force: Bool) {
        let ok = SystemMetricsService.terminate(pid: pid, force: force)
        lastError = ok ? nil : (force ? "Could not force quit PID \(pid)" : "Could not quit PID \(pid)")
        if ok {
            Task { await tick() }
        }
    }
}
