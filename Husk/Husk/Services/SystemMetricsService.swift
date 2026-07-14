//
//  SystemMetricsService.swift
//  Husk
//

import AppKit
import Darwin
import Foundation

/// Low-overhead host metrics + process table.
/// Process CPU/RSS comes from `/bin/ps` (stable across macOS versions).
/// Host CPU/memory use Mach `host_statistics` APIs.
actor SystemMetricsService {
    private var previousCPU = host_cpu_load_info()
    private var hasPreviousCPU = false

    func sample(topProcessLimit: Int = 30) async -> (SystemSnapshot, [ProcessInfoRow]) {
        var snapshot = SystemSnapshot()
        snapshot.timestamp = Date()

        sampleCPU(&snapshot)
        sampleMemory(&snapshot)
        sampleDisk(&snapshot)
        sampleLoad(&snapshot)
        sampleThermal(&snapshot)

        let processes = await sampleProcesses(limit: topProcessLimit)
        snapshot.processCount = processes.count
        return (snapshot, processes)
    }

    // MARK: - CPU

    private func sampleCPU(_ snapshot: inout SystemSnapshot) {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        if hasPreviousCPU {
            let dUser = Double(info.cpu_ticks.0 &- previousCPU.cpu_ticks.0)
            let dSys = Double(info.cpu_ticks.1 &- previousCPU.cpu_ticks.1)
            let dIdle = Double(info.cpu_ticks.2 &- previousCPU.cpu_ticks.2)
            let dNice = Double(info.cpu_ticks.3 &- previousCPU.cpu_ticks.3)
            let total = dUser + dSys + dIdle + dNice
            if total > 0 {
                snapshot.cpuPercent = max(0, min(100, ((dUser + dSys + dNice) / total) * 100))
            }
        }

        previousCPU = info
        hasPreviousCPU = true
    }

    // MARK: - Memory

    private func sampleMemory(_ snapshot: inout SystemSnapshot) {
        var size = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        var vmstat = vm_statistics64()
        let kr = withUnsafeMutablePointer(to: &vmstat) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let page = UInt64(vm_kernel_page_size)
        let active = UInt64(vmstat.active_count) * page
        let wired = UInt64(vmstat.wire_count) * page
        let compressed = UInt64(vmstat.compressor_page_count) * page
        let speculative = UInt64(vmstat.speculative_count) * page

        snapshot.memoryAppBytes = active + speculative
        snapshot.memoryWiredBytes = wired
        snapshot.memoryCompressedBytes = compressed
        snapshot.memoryUsedBytes = active + wired + compressed + speculative

        var memSize: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &len, nil, 0)
        snapshot.memoryTotalBytes = memSize
    }

    // MARK: - Disk / load / thermal

    private func sampleDisk(_ snapshot: inout SystemSnapshot) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]) else { return }

        snapshot.diskFreeBytes = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        snapshot.diskTotalBytes = Int64(values.volumeTotalCapacity ?? 0)
    }

    private func sampleLoad(_ snapshot: inout SystemSnapshot) {
        var load = [Double](repeating: 0, count: 3)
        if getloadavg(&load, 3) == 3 {
            snapshot.loadAverage1 = load[0]
        }
    }

    private func sampleThermal(_ snapshot: inout SystemSnapshot) {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: snapshot.thermalStateDescription = "Nominal"
        case .fair: snapshot.thermalStateDescription = "Fair"
        case .serious: snapshot.thermalStateDescription = "Serious"
        case .critical: snapshot.thermalStateDescription = "Critical"
        @unknown default: snapshot.thermalStateDescription = "Unknown"
        }
    }

    // MARK: - Processes via ps (fast, portable)

    private func sampleProcesses(limit: Int) async -> [ProcessInfoRow] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: Self.runPS(limit: limit))
            }
        }
    }

    nonisolated private static func runPS(limit: Int) -> [ProcessInfoRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // pid, %cpu, rss(KB), user, command
        process.arguments = ["-axo", "pid=,pcpu=,rss=,user=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        let myUser = NSUserName()
        var rows: [ProcessInfoRow] = []
        rows.reserveCapacity(256)

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: PID  CPU  RSS  USER  COMM(may contain spaces — rare for comm=)
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            guard parts.count >= 5,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2])
            else { continue }

            let user = parts[3]
            let name = parts[4...].joined(separator: " ")
            // Skip kernel_task noise optionally keep it
            let mem = rssKB * 1024

            rows.append(
                ProcessInfoRow(
                    pid: pid,
                    name: name,
                    path: nil,
                    cpuPercent: cpu,
                    memoryBytes: mem,
                    threadCount: 0,
                    isOwnedByUser: user == myUser || user == "\(getuid())"
                )
            )
        }

        rows.sort {
            let s0 = $0.cpuPercent * 8 + Double($0.memoryBytes) / 80_000_000
            let s1 = $1.cpuPercent * 8 + Double($1.memoryBytes) / 80_000_000
            return s0 > s1
        }
        return Array(rows.prefix(limit))
    }

    // MARK: - Process control

    nonisolated static func terminate(pid: Int32, force: Bool) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return force ? app.forceTerminate() : app.terminate()
        }
        // Fallback signal
        let sig = force ? SIGKILL : SIGTERM
        return kill(pid, sig) == 0
    }
}
