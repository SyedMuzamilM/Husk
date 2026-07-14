//
//  IconRail.swift
//  Husk
//
//  Compact 64pt icon rail — replaces fat sidebar (stitch design).
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
        case .optimize: "Optimize"
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

    private let main: [AppSection] = [.clean, .analyze, .apps, .status, .optimize]

    var body: some View {
        VStack(spacing: 6) {
            // Brand mark
            Image(systemName: "leaf.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.huskPrimary)
                .frame(width: 40, height: 40)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .help("Husk")

            ForEach(main) { section in
                railButton(section)
            }

            Spacer()

            railButton(.settings)
                .padding(.bottom, 12)
        }
        .frame(width: HuskTheme.railWidth)
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
            withAnimation(.easeOut(duration: 0.15)) {
                selection = section
            }
        } label: {
            Image(systemName: section.systemImage)
                .font(.system(size: 16, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.huskOnPrimary : Color.huskTextMuted)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(active ? Color.huskPrimary : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
