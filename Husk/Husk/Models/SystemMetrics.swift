//
//  SystemMetrics.swift
//  Husk
//

import Foundation

struct SystemSnapshot: Sendable, Equatable {
    var timestamp: Date = Date()
    var cpuPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var memoryAppBytes: UInt64 = 0
    var memoryWiredBytes: UInt64 = 0
    var memoryCompressedBytes: UInt64 = 0
    var diskFreeBytes: Int64 = 0
    var diskTotalBytes: Int64 = 0
    var processCount: Int = 0
    var loadAverage1: Double = 0
    var thermalStateDescription: String = "Nominal"

    var memoryUsedPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100
    }

    var diskUsedPercent: Double {
        guard diskTotalBytes > 0 else { return 0 }
        let used = diskTotalBytes - diskFreeBytes
        return Double(used) / Double(diskTotalBytes) * 100
    }
}

struct ProcessInfoRow: Identifiable, Sendable, Equatable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let path: String?
    let cpuPercent: Double
    let memoryBytes: UInt64
    let threadCount: Int32
    let isOwnedByUser: Bool

    var plainReason: String {
        if cpuPercent >= 50 {
            return "High CPU — actively using the processor"
        }
        if cpuPercent >= 15 {
            return "Elevated CPU"
        }
        if memoryBytes >= 1_000_000_000 {
            return "Large memory footprint"
        }
        if memoryBytes >= 400_000_000 {
            return "Notable memory use"
        }
        if threadCount > 40 {
            return "Many threads"
        }
        return "Running normally"
    }
}

struct CacheBreakdownEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let byteCount: Int64
    let isDirectory: Bool
    let childCount: Int?

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        byteCount: Int64,
        isDirectory: Bool,
        childCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.byteCount = byteCount
        self.isDirectory = isDirectory
        self.childCount = childCount
    }
}

struct CacheDetailReport: Sendable {
    let path: String
    let totalBytes: Int64
    let immediateChildren: Int
    let fileCountApprox: Int
    let folderCountApprox: Int
    let modified: Date?
    let topEntries: [CacheBreakdownEntry]
    let scannedAt: Date
}
