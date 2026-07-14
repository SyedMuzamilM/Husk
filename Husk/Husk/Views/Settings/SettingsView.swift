//
//  SettingsView.swift
//  Husk
//

import SwiftUI

struct SettingsView: View {
    @Environment(PermissionService.self) private var permissions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.huskText)
                    Text("Husk is local-first. No telemetry. Trash only.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.huskTextMuted)
                }

                HuskCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Permissions", systemImage: "lock.shield")
                            .font(.headline)
                            .foregroundStyle(Color.huskText)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Full Disk Access")
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.huskText)
                                Text(
                                    permissions.hasFullDiskAccess
                                        ? "Granted — deep scans can read protected user data."
                                        : "Not detected — some caches may be hidden."
                                )
                                .font(.caption)
                                .foregroundStyle(Color.huskTextMuted)
                            }
                            Spacer()
                            Image(systemName: permissions.hasFullDiskAccess ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(permissions.hasFullDiskAccess ? Color.safeLabel : Color.cautionLabel)
                                .font(.title2)
                        }
                        HStack {
                            Button("Open System Settings") { permissions.openFullDiskAccessSettings() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.huskPrimary)
                            Button("Re-check") { permissions.refresh() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.huskTextSecondary)
                        }
                    }
                }

                HuskCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image("HuskLogo")
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("About Husk")
                                    .font(.headline)
                                    .foregroundStyle(Color.huskText)
                                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color.huskTextSecondary)
                            }
                        }
                        Text("Peel the husk — transparent cleaning for developers. AI agents, node_modules, DerivedData, and more.")
                            .font(.caption)
                            .foregroundStyle(Color.huskTextMuted)
                    }
                }

                HuskCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Safety", systemImage: "checkmark.shield")
                            .font(.headline)
                            .foregroundStyle(Color.huskText)
                        bullet("Preview every path before cleaning")
                        bullet("Move to Trash only — never shred")
                        bullet("Never count APFS purgeable as junk")
                        bullet("SIP and sensitive paths protected")
                        bullet("Zero telemetry")
                    }
                }
            }
            .padding(HuskTheme.contentPadding)
        }
        .task { permissions.refresh() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundStyle(Color.safeLabel)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.huskTextSecondary)
        }
    }
}
