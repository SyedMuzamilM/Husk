//
//  HuskTheme.swift
//  Husk
//
//  Original Husk palette, rounded panels and warm amber controls.
//

import SwiftUI

enum HuskTheme {
    static let railWidth: CGFloat = 64
    static let minWindowWidth: CGFloat = 960
    static let minWindowHeight: CGFloat = 640
    static let cardRadius: CGFloat = 20
    static let pillRadius: CGFloat = 999
    static let contentPadding: CGFloat = 24
}

// MARK: - Adaptive palette

extension Color {
    static let huskBg = adaptive(dark: 0.075, light: 0.97)
    static let huskSurface = adaptive(dark: 0.122, light: 1)
    static let huskSurfaceHigh = adaptive(dark: 0.165, light: 0.92)
    static let huskSurfaceLow = adaptive(dark: 0.106, light: 0.95)
    static let huskPrimary = Color(red: 0.910, green: 0.643, blue: 0.361)     // #e8a45c
    static let huskPrimaryBright = Color(red: 1.0, green: 0.722, blue: 0.431) // #ffb86e
    static let huskOnPrimary = Color(red: 0.173, green: 0.102, blue: 0)       // dark brown text on amber
    static let huskText = Color.primary
    static let huskTextSecondary = Color.secondary
    static let huskTextMuted = Color.secondary
    static let huskTeal = contrasting(dark: (0.467, 0.839, 0.824), light: (0.12, 0.44, 0.43))        // #77d6d2
    static let huskAccentText = contrasting(dark: (0.91, 0.64, 0.36), light: (0.50, 0.30, 0.10))
    static let huskBorder = Color.primary.opacity(0.12)

    private static func contrasting(dark: (CGFloat, CGFloat, CGFloat), light: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    private static func adaptive(dark: CGFloat, light: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(white: value, alpha: 1)
        })
    }

    static let safeLabel = contrasting(dark: (0.35, 0.72, 0.48), light: (0.16, 0.43, 0.25))
    static let reviewLabel = contrasting(dark: (0.91, 0.64, 0.36), light: (0.50, 0.30, 0.10))
    static let cautionLabel = contrasting(dark: (0.95, 0.55, 0.28), light: (0.66, 0.25, 0.08))
    static let protectedLabel = Color.secondary

    static let treemapPalette: [Color] = [
        Color(red: 0.35, green: 0.42, blue: 0.38),
        Color(red: 0.28, green: 0.34, blue: 0.32),
        Color(red: 0.40, green: 0.36, blue: 0.30),
        Color(red: 0.32, green: 0.38, blue: 0.42),
        Color(red: 0.38, green: 0.40, blue: 0.34),
        Color(red: 0.30, green: 0.30, blue: 0.32),
        Color(red: 0.42, green: 0.38, blue: 0.34),
        Color(red: 0.28, green: 0.36, blue: 0.36)
    ]
}

enum ByteFormat {
    static func string(for bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: false))
    }

}

// MARK: - Shared chrome

struct HuskBackground: View {
    var glow: Color = .huskPrimary.opacity(0.18)

    var body: some View {
        ZStack {
            Color.huskBg
            RadialGradient(colors: [glow, .clear], center: .center, startRadius: 30, endRadius: 440)
        }.ignoresSafeArea()
    }

}

struct HuskCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                    .fill(Color.huskSurface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: HuskTheme.cardRadius, style: .continuous)
                            .strokeBorder(Color.huskBorder, lineWidth: 1)
                    )
            )
    }
}

struct HuskPillButton: View {
    let title: String
    var systemImage: String? = nil
    var prominent: Bool = true
    var action: () -> Void

    var body: some View {
        button.buttonStyle(HuskPillStyle(prominent: prominent))
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }.font(.body.weight(.semibold))
        }
    }

}

private struct HuskPillStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24).padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.huskOnPrimary : Color.huskText)
            .background(prominent ? Color.huskPrimary : Color.huskSurfaceHigh, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.huskBorder.opacity(0.5)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

struct HuskSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.huskText)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color.huskTextMuted)
            }
        }
    }
}
