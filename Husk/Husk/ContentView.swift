//
//  ContentView.swift
//  Husk
//

import SwiftUI

struct ContentView: View {
    @State private var section: AppSection = .clean
    @State private var cleanModel = CleanViewModel()
    @State private var analyzeModel = AnalyzeViewModel()
    @State private var appsModel = AppsViewModel()
    @State private var statusModel = StatusViewModel()
    @State private var permissions = PermissionService()
    @State private var freeSpaceText = "—"

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $section, freeSpaceText: freeSpaceText)
        } detail: {
            Group {
                switch section {
                case .clean:
                    CleanView(model: cleanModel)
                case .analyze:
                    AnalyzeView(model: analyzeModel)
                case .apps:
                    AppsView(model: appsModel)
                case .status:
                    StatusView(model: statusModel)
                case .optimize:
                    OptimizeView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .environment(permissions)
        .task {
            refreshFreeSpace()
            permissions.refresh()
        }
        .onChange(of: section) { _, newSection in
            refreshFreeSpace()
            // Status sampling is started/stopped by StatusView appear/disappear.
            if newSection == .settings {
                permissions.refresh()
            }
            if newSection != .status {
                statusModel.stop()
            }
        }
    }

    private func refreshFreeSpace() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) {
            let free = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
            freeSpaceText = ByteFormat.string(for: free)
        } else {
            freeSpaceText = "Unknown"
        }
    }
}

#Preview("Husk Shell") {
    ContentView()
        .frame(minWidth: 960, minHeight: 600)
}
