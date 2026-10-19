import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(PermissionService.self) private var permissions
    @AppStorage("husk.appearance") private var appearance = "system"
    @AppStorage("husk.compactNavigation") private var compact = true
    @AppStorage("husk.keepOperationHistory") private var keepHistory = true
    @State private var exclusions: [String] = []
    @State private var roots: [String] = []
    @State private var records: [OperationRecord] = []
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HuskPageHeader(title: "Settings", subtitle: "Choose appearance, scan boundaries and local history.") { EmptyView() }
            settingsForm
        }
    }

    private var settingsForm: some View {
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
                        Text(path).font(.callout.monospaced()).textSelection(.enabled)
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
                        Text(path).font(.callout.monospaced()).textSelection(.enabled)
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
                            Text(item.originalPath + "\nTrash: " + item.trashPath).font(.callout.monospaced()).textSelection(.enabled)
                        }
                        ForEach(record.issues) { Text($0.path + "\n" + $0.message).font(.caption).textSelection(.enabled) }
                    }
                }
            }
            Section("About Husk") {
                Text("Native macOS storage review, app removal, and system monitoring. Experimental beta; allocated sizes are estimates, including shared APFS data.")
                Text("Source-available for private use and modification. Redistribution is restricted. Built with TourKit.").font(.callout)
                HStack {
                    Button("Husk license") { openLicense("Husk-LICENSE") }
                    Button("TourKit license") { openLicense("TourKit-LICENSE") }
                }
                Link("Source and contributions", destination: URL(string: "https://github.com/SyedMuzamilM/Husk")!)
                Link("Private security report", destination: URL(string: "mailto:muzamil@mzml.dev?subject=Husk%20security%20report")!)
                Button("Replay welcome") { UserDefaults.standard.set(false, forKey: "husk.hasCompletedOnboarding") }
            }
            if let error { HuskNotice(message: error, systemImage: "exclamationmark.triangle") }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permissions.refresh() }
        .task {
            guard !AppRuntime.isXcodePreview && !AppRuntime.isUIFixture else { return }
            permissions.refresh()
            exclusions = ScanPreferences.excludedPaths
            roots = ScanPreferences.projectRoots
            await loadHistory()
        }
    }

    private func loadHistory() async {
        do { records = try await OperationJournal.shared.records(); error = nil }
        catch { self.error = error.localizedDescription }
    }
    private func openLicense(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
            error = "The license file is missing from this build. See the source repository for license terms."
            return
        }
        if !NSWorkspace.shared.open(url) { error = "Could not open the license file." }
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
