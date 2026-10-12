//
//  ContentView.swift
//  Husk
//

import SwiftUI

struct ContentView: View {
    @AppStorage("husk.appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("husk.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var section: AppSection = .clean
    @State private var cleanModel = CleanViewModel()
    @State private var aiModel = AIStorageViewModel()
    @State private var analyzeModel = AnalyzeViewModel()
    @State private var appsModel = AppsViewModel()
    @State private var statusModel = StatusViewModel()
    @State private var permissions = PermissionService()
    @State private var freeSpaceText = "—"

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainShell
                    .frame(minWidth: HuskTheme.minWindowWidth, minHeight: HuskTheme.minWindowHeight)
            } else {
                OnboardingView {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        hasCompletedOnboarding = true
                    }
                }
                .environment(permissions)
                .frame(width: HuskTheme.onboardingWidth, height: HuskTheme.onboardingHeight)
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .ignoresSafeArea(edges: .top)
        .environment(permissions)
        .focusedSceneValue(\.huskCleanModel, section == .clean && hasCompletedOnboarding ? cleanModel : nil)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                permissions.refresh()
                if section == .status { statusModel.start() }
            } else { statusModel.stop() }
        }
        .task {
            refreshFreeSpace()
            permissions.refresh()
        }
    }

    private var mainShell: some View {
        HStack(spacing: 0) {
            IconRail(selection: $section, freeSpace: freeSpaceText)
            ZStack {
                HuskBackground(glow: section == .analyze || section == .status ? Color.huskTeal.opacity(0.10) : Color.huskPrimary.opacity(0.15))
                Group {
                    switch section {
                    case .clean: CleanView(model: cleanModel)
                    case .aiStorage: AIStorageView(model: aiModel)
                    case .analyze: AnalyzeView(model: analyzeModel)
                    case .apps: AppsView(model: appsModel)
                    case .status: StatusView(model: statusModel)
                    case .optimize: OptimizeView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 12)
            }
        }
        .tint(Color.huskPrimary)
        .onChange(of: section) { _, newSection in
            refreshFreeSpace()
            if newSection == .settings { permissions.refresh() }
            if newSection != .status { statusModel.stop() }
        }
        .onChange(of: cleanModel.totalBytes) { refreshFreeSpace() }
        .onChange(of: aiModel.items.count) { refreshFreeSpace() }
    }

    private func refreshFreeSpace() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) {
            let free = Int64(values.volumeAvailableCapacity ?? 0)
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
