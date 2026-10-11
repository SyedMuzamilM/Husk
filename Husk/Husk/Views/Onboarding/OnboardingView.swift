import SwiftUI

struct OnboardingView: View {
    @Environment(PermissionService.self) private var permissions
    var onFinished: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HuskBrandMark(size: 108, showGlow: true, glowRadius: 32).accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text("Welcome to Husk").font(.system(size: 30, weight: .semibold))
                    Text("A little more room. A lot more control.").font(.title3).foregroundStyle(.secondary)
                }
                HuskCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 20) {
                        feature("Review before cleanup", "Inspect full paths, size coverage and risk before anything moves.", "eye")
                        feature("AI and developer storage", "Find regenerable caches. Keep conversations, working copies and installed models protected.", "cpu")
                        feature("Local and recoverable", "Scans stay on this Mac. Reviewed items go to Trash, and you decide when to empty it.", "lock.shield")
                    }
                }
                HuskCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Optional disk access", systemImage: permissions.hasFullDiskAccess ? "checkmark.shield" : "folder.badge.questionmark").font(.headline)
                        Text(permissions.hasFullDiskAccess ? "The readability probe detected access. Each scan still reports folders it cannot measure." : "You can start with limited access. Full Disk Access lets Husk measure more protected Library locations; credentials and cloud storage remain excluded.")
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Open System Settings") { permissions.openFullDiskAccessSettings() }
                            Button("Check access") { permissions.refresh() }
                        }
                    }
                }

            }.frame(maxWidth: 500).padding(32).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 20) {
                Text("No telemetry. No account required.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                HuskPillButton(title: "Get started", systemImage: "arrow.right", action: onFinished).keyboardShortcut(.defaultAction)
            }.frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity).background(Color.huskSurface)
        }
        .background { HuskBackground() }.task { permissions.refresh() }
    }
    private func feature(_ title: String, _ description: String, _ image: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: image).font(.title2).foregroundStyle(Color.huskAccentText).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(description).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview { OnboardingView(onFinished: {}).environment(PermissionService()).frame(width: 960, height: 720) }
