import SwiftUI

struct StatusView: View {
    @Bindable var model: StatusViewModel
    @State private var processPendingQuit: ProcessInfoRow?
    @State private var forceQuit = false

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "System Status", subtitle: model.statusLine) {
                Label(model.isSampling ? "Live" : "Paused", systemImage: model.isSampling ? "waveform.path" : "pause.circle").foregroundStyle(.secondary)
            }
            if let error = model.lastError { HuskNotice(message: error, systemImage: "exclamationmark.triangle").padding(.horizontal, HuskTheme.contentPadding) }
            VStack(spacing: 14) {
                metricsGrid
                HStack(spacing: 16) {
                    HuskSearchField(prompt: "Search process name or PID", text: $model.searchText)
                    Picker("Sort processes", selection: $model.sort) {
                        ForEach(StatusViewModel.ProcessSort.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
                }
                Table(model.filteredProcesses) {
                    TableColumn("Process") { process in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(process.name).font(.body.weight(.medium)).lineLimit(1)
                            Text(process.plainReason).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        }.padding(.vertical, 3)
                    }
                    TableColumn("CPU") { Text($0.cpuPercent.formatted(.number.precision(.fractionLength(1))) + "%").monospacedDigit() }.width(65)
                    TableColumn("Memory") { Text(ByteFormat.string(for: Int64($0.memoryBytes))).monospacedDigit() }.width(95)
                    TableColumn("PID") { Text(String($0.pid)).monospacedDigit().foregroundStyle(.secondary) }.width(60)
                    TableColumn("Action") { process in
                        Menu("Quit") {
                            Button("Quit…") { processPendingQuit = process; forceQuit = false }
                            Button("Force Quit…", role: .destructive) { processPendingQuit = process; forceQuit = true }
                        }.disabled(!process.canTerminate).help("Quit " + process.name)
                    }.width(75)
                }
                .frame(maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background(Color.huskSurface.opacity(0.92), in: .rect(cornerRadius: HuskTheme.cardRadius))
                .clipShape(.rect(cornerRadius: HuskTheme.cardRadius))
                .overlay { if model.filteredProcesses.isEmpty { ContentUnavailableView("No matching processes", systemImage: "waveform.path.ecg", description: Text("Wait for a sample or change your search.")) } }
                Text("Process CPU is a lifetime average. Host CPU uses interval samples. Memory and disk figures are estimates.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, HuskTheme.contentPadding).padding(.bottom, HuskTheme.contentPadding)
        }
        .onAppear { if !AppRuntime.isXcodePreview && !AppRuntime.isUIFixture { model.start() } }
        .onDisappear { model.stop() }
        .confirmationDialog(forceQuit ? "Force quit \(processPendingQuit?.name ?? "process")?" : "Quit \(processPendingQuit?.name ?? "process")?",
            isPresented: Binding(get: { processPendingQuit != nil }, set: { if !$0 { processPendingQuit = nil } }), titleVisibility: .visible) {
                Button(forceQuit ? "Force Quit" : "Quit", role: .destructive) {
                    if let processPendingQuit { model.terminate(processPendingQuit, force: forceQuit) }
                    processPendingQuit = nil
                }
                Button("Cancel", role: .cancel) { processPendingQuit = nil }
            } message: { Text("Unsaved work may be lost. The process identity and ownership are checked again before sending the request.") }
    }

    private var metricsGrid: some View {
        let s = model.snapshot
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricCard(title: "CPU utilization", value: s.cpuAvailable ? s.cpuPercent.formatted(.number.precision(.fractionLength(0))) + "%" : "Waiting",
                subtitle: "Load \(s.loadAverage1.formatted(.number.precision(.fractionLength(2))))", progress: s.cpuAvailable ? s.cpuPercent / 100 : nil, tint: .huskPrimary)
            MetricCard(title: "Memory", value: s.memoryAvailable ? ByteFormat.string(for: Int64(s.memoryUsedBytes)) : "Unknown",
                subtitle: "Pressure \(s.memoryPressure) · Swap \(s.swapUsedBytes.map { ByteFormat.string(for: Int64($0)) } ?? "Unknown")",
                progress: s.memoryAvailable ? s.memoryUsedPercent / 100 : nil, tint: .huskTeal)
            MetricCard(title: "Disk free", value: s.diskAvailable ? ByteFormat.string(for: s.diskFreeBytes) : "Unknown",
                subtitle: "Bar shows used space · \(ByteFormat.string(for: s.diskTotalBytes)) total",
                progress: s.diskAvailable && s.diskTotalBytes > 0 ? s.diskUsedPercent / 100 : nil, tint: .safeLabel)
            MetricCard(title: "Thermal", value: s.thermalStateDescription, subtitle: "\(s.processCount) processes", progress: nil, tint: .safeLabel)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double?
    let tint: Color
    var body: some View {
        HuskCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.callout).foregroundStyle(.secondary)
                Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                if let progress { ProgressView(value: min(max(progress, 0), 1)).tint(tint).accessibilityHidden(true) }
                Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        }.accessibilityElement(children: .combine)
    }
}
