//
//  IconRail.swift
//  Husk
//
//  Compact 64pt icon rail — brand logo + section icons.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case clean
    case analyze
    case apps
    case status
    case optimize
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: "Clean"
        case .analyze: "Analyze"
        case .apps: "Apps"
        case .status: "Status"
        case .optimize: "Maintenance"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .clean: "square.stack.3d.up"
        case .analyze: "square.grid.2x2"
        case .apps: "shippingbox"
        case .status: "waveform.path.ecg"
        case .optimize: "bolt"
        case .settings: "gearshape"
        }
    }
}

struct IconRail: View {
    @Binding var selection: AppSection
    @AppStorage("husk.compactNavigation") private var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let main: [AppSection] = [.clean, .analyze, .apps, .status, .optimize]

    var body: some View {
        VStack(spacing: 4) {
            // Transparent husk logo (sidebar brand).
            // Extra top inset keeps the mark clear of traffic lights
            // when the window uses a hidden title bar.
            HuskBrandMark(size: 36, showGlow: true, glowRadius: 16)
                .padding(.top, 36)
                .padding(.bottom, 14)
                .help("Husk")

            ForEach(main) { section in
                railButton(section)
            }

            Spacer()

            railButton(.settings)
                .padding(.bottom, 14)
        }
        .frame(width: compact ? HuskTheme.railWidth : 160)
        .background(
            Color.huskSurfaceLow.opacity(0.95)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.huskBorder)
                        .frame(width: 1)
                }
        )
    }

    private func railButton(_ section: AppSection) -> some View {
        let active = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                selection = section
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage).frame(width: 24)
                if !compact { Text(section.title).font(.callout.weight(active ? .semibold : .regular)) }
            }
            .foregroundStyle(active ? Color.huskOnPrimary : Color.huskTextSecondary)
            .frame(width: compact ? 40 : 140, height: 40, alignment: compact ? .center : .leading)
            .padding(.leading, compact ? 0 : 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(active ? Color.huskPrimary : Color.clear))

        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
