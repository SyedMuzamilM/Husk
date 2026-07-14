//
//  HuskApp.swift
//  Husk
//

import SwiftUI

@main
struct HuskApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Keep window title empty so the system title bar doesn't show "Husk"
                .navigationTitle("")
        }
        .defaultSize(width: 1120, height: 740)
        // Compact chrome: traffic lights only, no centered app name title.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Husk") {
                Button("Scan Clean Targets") {
                    NotificationCenter.default.post(name: .huskStartCleanScan, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsPane()
        }
    }
}

private struct SettingsPane: View {
    @State private var permissions = PermissionService()

    var body: some View {
        SettingsView()
            .environment(permissions)
            .frame(width: 480, height: 440)
            .preferredColorScheme(.dark)
            .task { permissions.refresh() }
    }
}

extension Notification.Name {
    static let huskStartCleanScan = Notification.Name("huskStartCleanScan")
}
