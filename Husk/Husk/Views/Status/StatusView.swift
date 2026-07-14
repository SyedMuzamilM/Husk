//
//  StatusView.swift
//  Husk
//

import AppKit
import SwiftUI

struct StatusView: View {
    @Bindable var model: StatusViewModel
    @State private var processPendingQuit: ProcessInfoRow?
    @State private var forceQuit = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricsGrid
                    processSection
                }
                .padding(16)
            }
        }
        .navigationTitle("Status")
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .confirmationDialog(
            forceQuit ? "Force Quit \(processPendingQuit?.name ?? "")?" : "Quit \(processPendingQuit?.name ?? "")?",
            isPresented: Binding(
                get: { processPendingQuit != nil },
                set: { if !$0 { processPendingQuit = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(forceQuit ? "Force Quit" : "Quit", role: .destructive) {
                if let p = processPendingQuit {
                    model.terminate(pid: p.pid, force: forceQuit)
                }
                processPendingQuit = nil
            }
            Button("Cancel", role: .cancel) {
                processPendingQuit = nil
            }
        } message: {
            if let p = processPendingQuit {
                Text("PID \(p.pid) · \(String(format: "%.1f", p.cpuPercent))% CPU · \(ByteFormat.string(for: Int64(p.memoryBytes)))")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live status")
                    .font(.title2.weight(.semibold))
                Text(model.statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isSampling {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.safeLabel)
                        .frame(width: 8, height: 8)
                    Text("Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var metricsGrid: some View {
        let s = model.snapshot
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            spacing: 12
        ) {
            MetricCard(
                title: "CPU",
                value: String(format: "%.0f%%", s.cpuPercent),
                subtitle: "Load \(String(format: "%.2f", s.loadAverage1))",
                progress: s.cpuPercent / 100,
                tint: .accentColor
            )
            MetricCard(
                title: "Memory",
                value: ByteFormat.string(for: Int64(s.memoryUsedBytes)),
                subtitle: "of \(ByteFormat.string(for: Int64(s.memoryTotalBytes))) · \(String(format: "%.0f%%", s.memoryUsedPercent))",
                progress: s.memoryUsedPercent / 100,
                tint: Color(red: 0.55, green: 0.45, blue: 0.85)
            )
            MetricCard(
                title: "Disk free",
                value: ByteFormat.string(for: s.diskFreeBytes),
                subtitle: s.diskTotalBytes > 0
                    ? "\(String(format: "%.0f%%", 100 - s.diskUsedPercent)) free of \(ByteFormat.string(for: s.diskTotalBytes))"
                    : "Volume capacity unknown",
                progress: s.diskTotalBytes > 0 ? s.diskUsedPercent / 100 : 0,
                tint: Color.safeLabel
            )
            MetricCard(
                title: "Thermal",
                value: s.thermalStateDescription,
                subtitle: "\(s.processCount) processes listed",
                progress: thermalProgress(s.thermalStateDescription),
                tint: thermalColor(s.thermalStateDescription)
            )
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Processes")
                    .font(.headline)
                Spacer()
                Picker("Sort", selection: $model.sort) {
                    ForEach(StatusViewModel.ProcessSort.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter name or PID", text: $model.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            if let err = model.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(spacing: 0) {
                processHeader
                Divider()
                ForEach(model.filteredProcesses) { proc in
                    processRow(proc)
                    Divider()
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var processHeader: some View {
        HStack {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").frame(width: 64, alignment: .trailing)
            Text("Memory").frame(width: 80, alignment: .trailing)
            Text("PID").frame(width: 56, alignment: .trailing)
            Text("").frame(width: 120)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func processRow(_ proc: ProcessInfoRow) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(proc.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(proc.plainReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(.body.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
                .foregroundStyle(proc.cpuPercent > 50 ? Color.cautionLabel : .primary)

            Text(ByteFormat.string(for: Int64(proc.memoryBytes)))
                .font(.body.monospacedDigit())
                .frame(width: 80, alignment: .trailing)

            Text("\(proc.pid)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            HStack(spacing: 6) {
                Button("Quit") {
                    forceQuit = false
                    processPendingQuit = proc
                }
                .controlSize(.small)
                Button("Force") {
                    forceQuit = true
                    processPendingQuit = proc
                }
                .controlSize(.small)
                .tint(.red)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contextMenu {
            Button("Quit") {
                forceQuit = false
                processPendingQuit = proc
            }
            Button("Force Quit", role: .destructive) {
                forceQuit = true
                processPendingQuit = proc
            }
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(proc.pid)", forType: .string)
            }
        }
    }

    private func thermalProgress(_ state: String) -> Double {
        switch state {
        case "Nominal": return 0.15
        case "Fair": return 0.45
        case "Serious": return 0.75
        case "Critical": return 1
        default: return 0
        }
    }

    private func thermalColor(_ state: String) -> Color {
        switch state {
        case "Nominal": return Color.safeLabel
        case "Fair": return Color.reviewLabel
        case "Serious", "Critical": return Color.cautionLabel
        default: return .secondary
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProgressView(value: min(max(progress, 0), 1))
                .tint(tint)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
