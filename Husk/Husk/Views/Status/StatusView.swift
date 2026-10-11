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
            if let error = model.lastError { Text(error).foregroundStyle(.orange).textSelection(.enabled).padding() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricsGrid
                    Text("Memory pressure: " + model.snapshot.memoryPressure + " · Swap: " + (model.snapshot.swapUsedBytes.map { ByteFormat.string(for: Int64($0)) } ?? "Unknown"))
                        .font(.callout).foregroundStyle(.secondary)
                    processTable
                }
                .padding(HuskTheme.contentPadding)
            }
        }
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
                    model.terminate(p, force: forceQuit)
                }
                processPendingQuit = nil
            }
            Button("Cancel", role: .cancel) { processPendingQuit = nil }
        } message: {
            if let p = processPendingQuit {
                Text("Unsaved work may be lost. PID \(p.pid) · \(String(format: "%.1f%%", p.cpuPercent)) · \(ByteFormat.string(for: Int64(p.memoryBytes)))")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Status")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text(model.statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskTextMuted)
            }
            Spacer()
            if model.isSampling {
                HStack(spacing: 6) {
                    Circle().fill(Color.safeLabel).frame(width: 7, height: 7)
                    Text("Live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.huskTextMuted)
                }
            }
        }
        .padding(.horizontal, HuskTheme.contentPadding)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var metricsGrid: some View {
        let s = model.snapshot
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            MetricCard(title: "CPU", value: s.cpuAvailable ? String(format: "%.0f%%", s.cpuPercent) : "Waiting",
                       subtitle: "Load \(String(format: "%.2f", s.loadAverage1))",
                       progress: s.cpuPercent / 100, tint: .huskPrimary)
            MetricCard(title: "Memory estimate", value: s.memoryAvailable ? ByteFormat.string(for: Int64(s.memoryUsedBytes)) : "Unknown",
                       subtitle: "Active + wired + compressed; of \(ByteFormat.string(for: Int64(s.memoryTotalBytes)))",
                       progress: s.memoryUsedPercent / 100, tint: .huskTeal)
            MetricCard(title: "Disk free", value: s.diskAvailable ? ByteFormat.string(for: s.diskFreeBytes) : "Unknown",
                       subtitle: s.diskTotalBytes > 0 ? ByteFormat.string(for: s.diskTotalBytes) + " volume" : "—",
                       progress: s.diskTotalBytes > 0 ? s.diskUsedPercent / 100 : 0, tint: .safeLabel)
            MetricCard(title: "Thermal", value: s.thermalStateDescription,
                       subtitle: "\(s.processCount) processes",
                       progress: thermalProgress(s.thermalStateDescription),
                       tint: thermalColor(s.thermalStateDescription))
        }
    }

    private var processTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Processes · CPU is lifetime average; host CPU is interval usage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Spacer()
                Picker("", selection: $model.sort) {
                    ForEach(StatusViewModel.ProcessSort.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.huskTextMuted)
                TextField("Filter", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.huskText)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.huskSurfaceHigh.opacity(0.6)))

            LazyVStack(spacing: 0) {
                ForEach(model.filteredProcesses) { proc in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proc.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.huskText)
                                .lineLimit(1)
                            Text(proc.plainReason)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.huskTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f%%", proc.cpuPercent))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(proc.cpuPercent > 40 ? Color.cautionLabel : Color.huskTextSecondary)
                            .frame(width: 56, alignment: .trailing)
                        Text(ByteFormat.string(for: Int64(proc.memoryBytes)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.huskPrimary)
                            .frame(width: 72, alignment: .trailing)
                        Text("\(proc.pid)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.huskTextMuted)
                            .frame(width: 48, alignment: .trailing)
                        Button("Quit") {
                            forceQuit = false
                            processPendingQuit = proc
                        }
                        .buttonStyle(.plain)
                        .disabled(!proc.canTerminate)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.huskTextSecondary)
                        Button("Force") {
                            forceQuit = true
                            processPendingQuit = proc
                        }
                        .buttonStyle(.plain)
                        .disabled(!proc.canTerminate)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cautionLabel)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    Divider().overlay(Color.huskBorder)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                    .fill(Color.huskSurface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                            .strokeBorder(Color.huskBorder)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous))
        }
    }

    private func thermalProgress(_ s: String) -> Double {
        switch s {
        case "Nominal": return 0.15
        case "Fair": return 0.45
        case "Serious": return 0.75
        case "Critical": return 1
        default: return 0
        }
    }

    private func thermalColor(_ s: String) -> Color {
        switch s {
        case "Nominal": return .safeLabel
        case "Fair": return .reviewLabel
        default: return .cautionLabel
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
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.huskTextMuted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.huskText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProgressView(value: min(max(progress, 0), 1))
                .tint(tint)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.huskTextMuted)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.huskSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.huskBorder)
                )
        )
    }
}
