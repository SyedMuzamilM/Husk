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
        }
        .defaultSize(width: 1100, height: 720)
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

/// Isolated settings scene so we don't construct services during App `body` evaluation.
private struct SettingsPane: View {
    @State private var permissions = PermissionService()

    var body: some View {
        SettingsView()
            .environment(permissions)
            .frame(width: 480, height: 440)
            .task { permissions.refresh() }
    }
}

extension Notification.Name {
    static let huskStartCleanScan = Notification.Name("huskStartCleanScan")
}
