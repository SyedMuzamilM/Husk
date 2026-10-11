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
        let sampler = service
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let (snap, procs) = try await sampler.sample()
                    guard !Task.isCancelled else { return }
                    self?.apply(snap, processes: procs)
                } catch is CancellationError { return }
                catch { self?.lastError = error.localizedDescription }
                // No strong reference to the model spans sleep or sampling.
                try? await Task.sleep(for: .milliseconds(1500))
                if self == nil { return }
            }
        }

    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isSampling = false
        statusLine = "Paused"
    }

    isolated deinit { loopTask?.cancel() }

    private func apply(_ snap: SystemSnapshot, processes: [ProcessInfoRow]) {
        snapshot = snap
        self.processes = processes
        lastError = nil
        statusLine = "Updated \(snap.timestamp.formatted(date: .omitted, time: .standard))"
    }

    func terminate(_ row: ProcessInfoRow, force: Bool) {
        do {
            guard let identity = row.identity else { throw RemovalError.changed("Identity unavailable. Refresh and try again.") }
            try ProcessControl.terminate(identity, force: force)
            lastError = nil
            statusLine = "Quit request sent to PID \(row.pid). Waiting for the next sample."
        } catch { lastError = error.localizedDescription }
    }
}
