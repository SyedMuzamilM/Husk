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
            CommandMenu("Scan") {
                Button("Scan Clean Targets") {
                    NotificationCenter.default.post(name: .huskStartCleanScan, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(PermissionService())
                .frame(width: 480, height: 420)
        }
    }
}

extension Notification.Name {
    static let huskStartCleanScan = Notification.Name("huskStartCleanScan")
}
