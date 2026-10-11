//
//  HuskApp.swift
//  Husk
//

import SwiftUI

@main
struct HuskApp: App {
    @FocusedValue(\.huskScanAction) private var scanAction
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
                    scanAction?()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(scanAction == nil)
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

private struct HuskScanActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var huskScanAction: (() -> Void)? {
        get { self[HuskScanActionKey.self] }
        set { self[HuskScanActionKey.self] = newValue }
    }
}
