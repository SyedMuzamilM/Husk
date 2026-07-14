//
//  AppSidebar.swift
//  Husk
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
        case .clean: "leaf.fill"
        case .analyze: "square.grid.3x3.topleft.filled"
        case .apps: "square.stack.3d.up.fill"
        case .status: "waveform.path.ecg"
        case .optimize: "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection
    var freeSpaceText: String

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            } header: {
                Text("Husk")
            }

            Section {
                Label(AppSection.settings.title, systemImage: AppSection.settings.systemImage)
                    .tag(AppSection.settings)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free space")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(freeSpaceText)
                        .font(.callout.monospacedDigit().weight(.semibold))
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: HuskTheme.sidebarWidth, max: 260)
    }
}
