//
//  OnboardingView.swift
//  Husk
//

import SwiftUI

struct OnboardingView: View {
    @Environment(PermissionService.self) private var permissions
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            HuskBackground(glow: Color.huskPrimary.opacity(0.22))

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                HuskBrandMark(size: 128, showGlow: true, glowRadius: 40)
                    .padding(.bottom, 28)

                Text("Welcome to Husk")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.huskText)

                Text("Peel regenerable clutter. Preview every path. Trash only.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.huskTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(
                        icon: "eye",
                        title: "Transparent cleaning",
                        detail: "Every cache path is listed with a safety label before anything moves."
                    )
                    featureRow(
                        icon: "cpu",
                        title: "AI & developer clutter",
                        detail: "Claude, Cursor, Codex, Ollama, node_modules, DerivedData, and more."
                    )
                    featureRow(
                        icon: "trash",
                        title: "Trash only, never shred",
                        detail: "Safe by default. Empty Trash yourself when you’re ready."
                    )
                    featureRow(
                        icon: "lock.shield",
                        title: "Local and private",
                        detail: "Zero telemetry. All processing stays on your Mac."
                    )
                }
                .padding(20)
                .frame(maxWidth: 440)
                .background(
                    RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                        .fill(Color.huskSurface.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                                .strokeBorder(Color.huskBorder)
                        )
                )
                .padding(.top, 28)

                // Full Disk Access step
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: permissions.hasFullDiskAccess ? "checkmark.circle.fill" : "lock.open")
                            .foregroundStyle(permissions.hasFullDiskAccess ? Color.safeLabel : Color.huskPrimary)
                        Text(
                            permissions.hasFullDiskAccess
                                ? "Full Disk Access granted"
                                : "Full Disk Access helps Husk see Safari and deep Library caches"
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Color.huskTextSecondary)
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }

                    if !permissions.hasFullDiskAccess {
                        Button {
                            permissions.openFullDiskAccessSettings()
                        } label: {
                            Text("Open System Settings")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.huskBorder)
                                )
                                .foregroundStyle(Color.huskText)
                        }
                        .buttonStyle(.plain)

                        Button("I’ve granted access — re-check") {
                            permissions.refresh()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.huskPrimary)
                    }
                }
                .padding(16)
                .frame(maxWidth: 440)
                .padding(.top, 14)

                Spacer(minLength: 16)

                HuskPillButton(
                    title: permissions.hasFullDiskAccess ? "Get started" : "Continue without it",
                    systemImage: "arrow.right"
                ) {
                    onFinished()
                }
                .padding(.bottom, 12)

                Text("ZERO TELEMETRY · LOCAL ONLY · $0 FREE / $9.99 LIFETIME")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(Color.huskTextMuted.opacity(0.75))
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .task {
            permissions.refresh()
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.huskPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.huskPrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .environment(PermissionService())
        .frame(width: 900, height: 700)
        .preferredColorScheme(.dark)
}
