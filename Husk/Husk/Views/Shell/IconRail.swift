import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case clean, aiStorage, analyze, apps, status, optimize, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clean: "Cleanup"
        case .aiStorage: "AI Storage"
        case .analyze: "Storage Map"
        case .apps: "Applications"
        case .status: "System Status"
        case .optimize: "Maintenance"
        case .settings: "Settings"
        }
    }
    var systemImage: String {
        switch self {
        case .clean: "sparkle.magnifyingglass"
        case .aiStorage: "cpu"
        case .analyze: "chart.pie"
        case .apps: "square.stack.3d.up"
        case .status: "waveform.path.ecg"
        case .optimize: "wrench.and.screwdriver"
        case .settings: "gearshape"
        }
    }
}

struct IconRail: View {
    @Binding var selection: AppSection
    @AppStorage("husk.compactNavigation") private var compact = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let freeSpace: String

    private let main: [AppSection] = [.clean, .aiStorage, .analyze, .apps, .status, .optimize]

    var body: some View {
        VStack(spacing: 8) {
            HuskBrandMark(size: 36, showGlow: true, glowRadius: 16)
                .accessibilityLabel("Husk")
                .padding(.top, 38).padding(.bottom, 20)
            ForEach(main) { section in railButton(section) }
            Spacer(minLength: 16)
            Image(systemName: "internaldrive")
                .font(.callout).foregroundStyle(Color.huskTextMuted)
                .help("\(freeSpace) free")
                .accessibilityLabel("Disk space available: \(freeSpace)")
            if !compact {
                Text("\(freeSpace) free").font(.callout).foregroundStyle(.secondary)
            }
            railButton(.settings).padding(.top, 8).padding(.bottom, 18)
        }
        .frame(width: compact ? HuskTheme.railWidth : 184)
        .background(Color.huskSurfaceLow.opacity(0.95))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.huskBorder).frame(width: 1) }
    }

    private func railButton(_ section: AppSection) -> some View {
        let active = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { selection = section }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage).font(.system(size: 18, weight: .medium)).frame(width: 24)
                if !compact { Text(section.title).font(.callout.weight(active ? .semibold : .regular)) }
            }
            .foregroundStyle(active ? Color.huskAccentText : Color.huskTextSecondary)
            .frame(width: compact ? 44 : 160, height: 44, alignment: compact ? .center : .leading)
            .padding(.leading, compact ? 0 : 10)
            .background(Color.huskPrimary.opacity(active ? 0.16 : 0), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.huskPrimary.opacity(active ? 0.25 : 0)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain).help(section.title)
        .accessibilityLabel(section.title).accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("section.\(section.rawValue)")
    }
}
