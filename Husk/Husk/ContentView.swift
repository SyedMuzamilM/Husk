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
        HStack(spacing: 0) {
            IconRail(selection: $section)

            ZStack {
                HuskBackground(glow: glowColor)

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
            }
        }
        .frame(minWidth: HuskTheme.minWindowWidth, minHeight: HuskTheme.minWindowHeight)
        .preferredColorScheme(.dark)
        .environment(permissions)
        .task {
            refreshFreeSpace()
            permissions.refresh()
        }
        .onChange(of: section) { _, newSection in
            refreshFreeSpace()
            if newSection == .settings {
                permissions.refresh()
            }
            if newSection != .status {
                statusModel.stop()
            }
        }
    }

    private var glowColor: Color {
        switch section {
        case .clean: return Color.huskPrimary.opacity(0.20)
        case .analyze: return Color.huskTeal.opacity(0.14)
        case .apps: return Color(red: 0.45, green: 0.50, blue: 0.85).opacity(0.16)
        case .status: return Color.huskTeal.opacity(0.12)
        case .optimize: return Color.huskPrimary.opacity(0.14)
        case .settings: return Color.white.opacity(0.04)
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
        .frame(width: 1100, height: 720)
}
