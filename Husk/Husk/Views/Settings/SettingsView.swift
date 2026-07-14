//
//  SettingsView.swift
//  Husk
//

import SwiftUI

struct SettingsView: View {
    @Environment(PermissionService.self) private var permissions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))
                    Text("Husk is local-first. No telemetry. Trash only.")
                        .foregroundStyle(.secondary)
                }

                permissionsCard
                aboutCard
                safetyCard
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Settings")
        .onAppear { permissions.refresh() }
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Permissions", systemImage: "lock.shield")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Disk Access")
                        .font(.body.weight(.medium))
                    Text(
                        permissions.hasFullDiskAccess
                            ? "Granted — deep scans can read protected user data."
                            : "Not detected — some Safari/Mail caches may be hidden."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: permissions.hasFullDiskAccess ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(permissions.hasFullDiskAccess ? Color.safeLabel : Color.cautionLabel)
                    .font(.title2)
            }

            HStack {
                Button("Open System Settings") {
                    permissions.openFullDiskAccessSettings()
                }
                Button("Re-check") {
                    permissions.refresh()
                }
            }
        }
        .huskCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About Husk", systemImage: "leaf")
                .font(.headline)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                .font(.callout.monospacedDigit())
            Text("Peel the husk off your Mac — transparent cleaning for developers and power users.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Free core · Premium features planned ($9.99 lifetime)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .huskCard()
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Safety", systemImage: "checkmark.shield")
                .font(.headline)
            bullet("Preview every path before cleaning")
            bullet("Move to Trash only — never permanent shred")
            bullet("Never count APFS purgeable space as junk")
            bullet("SIP and sensitive paths are protected")
            bullet("Zero telemetry in this beta")
        }
        .huskCard()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundStyle(Color.safeLabel)
                .font(.caption.weight(.bold))
                .padding(.top, 3)
            Text(text)
                .font(.callout)
        }
    }
}
