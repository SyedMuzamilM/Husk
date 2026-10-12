import SwiftUI
import TourKit

struct OnboardingView: View {
    @State private var showingPermissions = false
    var reduceMotionOverride: Bool? = nil
    var onFinished: () -> Void

    var body: some View {
        Group {
            if showingPermissions {
                OnboardingPermissionView(onBack: { showingPermissions = false }, onFinished: onFinished)
            } else {
                HuskWelcomeTour(reduceMotionOverride: reduceMotionOverride, onContinue: { showingPermissions = true })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HuskBackground() }
    }
}

struct HuskWelcomeTour: View {
    var initialPageIndex = 0
    var reduceMotionOverride: Bool? = nil
    var onContinue: () -> Void

    // Stable page identities survive SwiftUI body updates and permission changes.
    private static let pages = [
        TourPage(id: UUID(uuidString: "56DE5601-54DE-4B3D-9001-000000000001")!, imageName: "TourWelcome",
                 title: "Welcome to Husk",
                 description: "A little more room. A lot more control.\nUnderstand your Mac's storage and choose what to clean."),
        TourPage(id: UUID(uuidString: "56DE5601-54DE-4B3D-9001-000000000002")!, imageName: "TourReview",
                 title: "Review before cleanup.",
                 description: "See the path, size and risk of every item.\nReviewed files go to Trash. You decide when to empty it."),
        TourPage(id: UUID(uuidString: "56DE5601-54DE-4B3D-9001-000000000003")!, imageName: "TourAI",
                 title: "AI storage, protected.",
                 description: "Review regenerable AI caches. Conversations, models and working copies stay protected.\nAll scans stay on this Mac.")
    ]

    var body: some View {
        VStack(spacing: 16) {
            TourSlideshowView(pages: Self.pages, width: 560, initialPageIndex: initialPageIndex,
                              continueButtonTitle: "Continue", finishButtonTitle: "Continue to setup",
                              buttonTint: .huskPrimary, buttonForegroundColor: .huskOnPrimary,
                              reduceMotion: reduceMotionOverride,
                              onFinish: onContinue, onClose: onContinue)
                .frame(height: 560)
                // TourKit's artwork and text panel intentionally use a dark palette in either app appearance.
                .environment(\.colorScheme, .dark)
            Text("No telemetry. No account required.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20).padding(.bottom, 16)
    }
}

struct OnboardingPermissionView: View {
    @Environment(PermissionService.self) private var permissions
    var onBack: () -> Void
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield" : "folder.badge.questionmark")
                        .font(.system(size: 48, weight: .light)).foregroundStyle(Color.huskAccentText)
                        .frame(width: 100, height: 100)
                        .background(Color.huskPrimary.opacity(0.10), in: .rect(cornerRadius: 28))
                        .accessibilityHidden(true)
                    VStack(spacing: 10) {
                        Text("Your Mac. Your permission.").font(.system(size: 28, weight: .semibold)).accessibilityAddTraits(.isHeader)
                        Text("Full Disk Access is optional. You can start with limited scans.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    HuskCard(padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Label(permissions.hasFullDiskAccess ? "Disk access detected" : "Allow more complete scans",
                                  systemImage: permissions.hasFullDiskAccess ? "checkmark.circle" : "lock.open").font(.headline)
                            Text(permissions.hasFullDiskAccess
                                 ? "The readability probe detected access. Each scan still reports locations it cannot measure."
                                 : "Full Disk Access lets Husk measure more protected Library locations. Credentials and cloud storage remain excluded.")
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) {
                                Button("Open System Settings") { permissions.openFullDiskAccessSettings() }
                                Button("Check access") { permissions.refresh() }
                            }
                            Text("Husk reports incomplete sizes and inaccessible paths. Granting access never starts a scan or cleanup.")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Label("Local scans. Reviewed removals go to Trash.", systemImage: "lock.shield")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: 520).padding(32).frame(maxWidth: .infinity)
            }
            HStack(spacing: 20) {
                Button("Back to tour", systemImage: "chevron.left", action: onBack)
                Spacer()
                HuskPillButton(title: "Get started", systemImage: "arrow.right", action: onFinished)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint("Open Husk with the currently available disk access")
            }.frame(maxWidth: 520).padding(20).frame(maxWidth: .infinity)
                .background(Color.huskSurface.opacity(0.92))
        }
        .task { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permissions.refresh() }
    }
}

#Preview { OnboardingView(onFinished: {}).environment(PermissionService()).frame(width: 960, height: 640) }
