//
//  HuskApp.swift
//  Husk
//

import SwiftUI

@main
struct HuskApp: App {
    @AppStorage("husk.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @FocusedValue(\.huskCleanModel) private var cleanModel
    var body: some Scene {
        WindowGroup {
            ContentView()

        }
        .defaultSize(width: hasCompletedOnboarding ? 1120 : HuskTheme.onboardingWidth,
                     height: hasCompletedOnboarding ? 740 : HuskTheme.onboardingHeight)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Husk") {
                Button("Scan Clean Targets") {
                    cleanModel?.startScan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(cleanModel == nil || cleanModel?.isBusy == true)
            }
        }

        Settings {
            SettingsPane()
        }
    }
}

private struct SettingsPane: View {
    @State private var permissions = PermissionService()
    @AppStorage("husk.appearance") private var appearance = "system"

    var body: some View {
        SettingsView()
            .environment(permissions)
            .frame(width: 600, height: 580)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .task { permissions.refresh() }
    }
}
