import SwiftUI

struct OptimizeView: View {
    @State private var runningID: String?
    @State private var lastMessage: String?
    @State private var lastSuccess: Bool?
    @State private var pendingTask: OptimizeTask?
    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Maintenance", subtitle: "Targeted troubleshooting for your Mac.") { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HuskNotice(message: "macOS manages memory automatically. A cache reset may slow the next launch. Run maintenance when you have a specific problem.", systemImage: "wrench.and.screwdriver")
                    ForEach(OptimizeService.tasks) { task in
                        HuskCard(padding: 22) {
                            VStack(alignment: .leading, spacing: 16) {
                                Label(task.title, systemImage: task.systemImage).font(.title3.weight(.semibold))
                                Text(task.detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Text("No administrator access required").font(.callout).foregroundStyle(.secondary)
                                    Spacer()
                                    if runningID == task.id { ProgressView().controlSize(.small) }
                                    HuskPillButton(title: "Review reset", systemImage: "arrow.clockwise") { pendingTask = task }.disabled(runningID != nil)
                                }
                            }
                        }
                    }
                    if let lastMessage { HuskNotice(message: lastMessage, systemImage: lastSuccess == true ? "checkmark.circle" : "exclamationmark.triangle") }
                    HuskCard(padding: 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI tool maintenance").font(.title3.weight(.semibold))
                            Text("Review regenerable caches in AI Storage. Manage chat retention, models and installed versions with each tool’s own manager. A recently modified folder is not reliable evidence of use.").foregroundStyle(.secondary)
                            Text("Automatic RAM purges and privileged system resets are not offered.").font(.callout).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(HuskTheme.contentPadding)
            }
        }
        .confirmationDialog("Reset Quick Look cache?", isPresented: Binding(get: { pendingTask != nil }, set: { if !$0 { pendingTask = nil } }), titleVisibility: .visible) {
            Button("Reset cache") {
                guard let task = pendingTask else { return }
                pendingTask = nil
                Task {
                    runningID = task.id
                    let result = await OptimizeService.run(task)
                    lastMessage = result.message; lastSuccess = result.success; runningID = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingTask = nil }
        } message: { Text("Generated file previews will be rebuilt as you browse. This runs qlmanage -r cache.") }
    }
}
