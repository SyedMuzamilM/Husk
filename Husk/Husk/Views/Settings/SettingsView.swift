import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(PermissionService.self) private var permissions
    @AppStorage("husk.appearance") private var appearance = "system"
    @AppStorage("husk.compactNavigation") private var compact = false
    @AppStorage("husk.keepOperationHistory") private var keepHistory = true
    @State private var exclusions: [String] = []
    @State private var roots: [String] = []
    @State private var records: [OperationRecord] = []
    @State private var error: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Toggle("Compact navigation", isOn: $compact)
            }
            Section("Permissions") {
                Text(permissions.hasFullDiskAccess ? "Full Disk Access detected by a readability probe." : "Full Disk Access not detected. Limited scans still work.")
                Text("This probe cannot guarantee access to every folder. Scans report partial or unavailable sizes. Credentials and cloud storage remain excluded.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Open System Settings") { permissions.openFullDiskAccessSettings() }
                    Button("Re-check") { permissions.refresh() }
                }
            }
            Section("Excluded paths") {
                Text("Excluded folders and their contents are skipped. Removing a parent of an excluded path is also blocked.").font(.callout)
                ForEach(exclusions, id: \.self) { path in
                    HStack {
                        Text(path).font(.caption.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button("Remove") { exclusions.removeAll { $0 == path }; savePaths() }
                    }
                }
                Button("Add exclusion…") { choosePath { exclusions = Array(Set(exclusions + [$0])).sorted(); savePaths() } }
            }
            Section("Project inspection roots") {
                Text("Opt-in discovery of recognized project caches. Project removal remains disabled until Git tracking and running builds can be verified.").font(.callout)
                ForEach(roots, id: \.self) { path in
                    HStack {
                        Text(path).font(.caption.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button("Remove") { roots.removeAll { $0 == path }; savePaths() }
                    }
                }
                Button("Add project folder…") { choosePath { roots = Array(Set(roots + [$0])).sorted(); savePaths() } }
            }
            Section("Local operation history") {
                Toggle("Keep up to 100 operations for 30 days", isOn: $keepHistory)
                    .onChange(of: keepHistory) { _, enabled in if !enabled { clearHistory() } }
                Text("History stores original paths, Trash destinations, and errors on this Mac. Husk sends no telemetry. Clear history before sharing diagnostics.").font(.callout)
                HStack {
                    Button("Open Trash") { NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")) }
                    Button("Clear history") { clearHistory() }
                    Button("Refresh") { Task { await loadHistory() } }
                }
                ForEach(records) { record in
                    DisclosureGroup(record.title + " · " + record.date.formatted()) {
                        ForEach(record.destinations) { item in
                            Text(item.originalPath + "\nTrash: " + item.trashPath).font(.caption.monospaced()).textSelection(.enabled)
                        }
                        ForEach(record.issues) { Text($0.path + "\n" + $0.message).font(.caption).textSelection(.enabled) }
                    }
                }
            }
            Section("About Husk") {
                Text("Native macOS storage review, app removal, and system monitoring. Experimental beta; allocated sizes are estimates, including shared APFS data.")
                Button("Replay welcome") { UserDefaults.standard.set(false, forKey: "husk.hasCompletedOnboarding") }
            }
            if let error { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permissions.refresh() }
        .task {
            permissions.refresh()
            exclusions = ScanPreferences.excludedPaths
            roots = ScanPreferences.projectRoots
            await loadHistory()
        }
    }

    private func loadHistory() async {
        do { records = try await OperationJournal.shared.records() }
        catch { self.error = error.localizedDescription }
    }
    private func savePaths() {
        UserDefaults.standard.set(exclusions, forKey: "husk.excludedPaths")
        UserDefaults.standard.set(roots, forKey: "husk.projectRoots")
        Task { await SizeCache.shared.clear() }
    }
    private func choosePath(_ selected: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url { selected(PathSafety.canonicalPath(url.path)) }
    }
    private func clearHistory() {
        Task {
            do { try await OperationJournal.shared.clear(); records = [] }
            catch { self.error = error.localizedDescription }
        }
    }
}
