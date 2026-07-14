//
//  HuskTheme.swift
//  Husk
//
//  Design tokens from stitch_husk_macos_interface_design (quiet confidence).
//

import SwiftUI

enum HuskTheme {
    static let railWidth: CGFloat = 64
    static let minWindowWidth: CGFloat = 1000
    static let minWindowHeight: CGFloat = 680
    static let cardRadius: CGFloat = 20
    static let pillRadius: CGFloat = 999
    static let contentPadding: CGFloat = 24
}

// MARK: - Palette (stitch DESIGN.md)

extension Color {
    static let huskBg = Color(red: 0.075, green: 0.075, blue: 0.078)          // #131314
    static let huskSurface = Color(red: 0.122, green: 0.122, blue: 0.125)     // #1f1f20
    static let huskSurfaceHigh = Color(red: 0.165, green: 0.165, blue: 0.169) // #2a2a2b
    static let huskSurfaceLow = Color(red: 0.106, green: 0.106, blue: 0.110)  // #1b1b1c
    static let huskPrimary = Color(red: 0.910, green: 0.643, blue: 0.361)     // #e8a45c
    static let huskPrimaryBright = Color(red: 1.0, green: 0.722, blue: 0.431) // #ffb86e
    static let huskOnPrimary = Color(red: 0.173, green: 0.102, blue: 0)       // dark brown text on amber
    static let huskText = Color(red: 0.898, green: 0.886, blue: 0.890)        // #e5e2e3
    static let huskTextSecondary = Color(red: 0.839, green: 0.765, blue: 0.702) // #d6c3b3
    static let huskTextMuted = Color(red: 0.620, green: 0.557, blue: 0.498)   // #9e8e7f
    static let huskTeal = Color(red: 0.467, green: 0.839, blue: 0.824)        // #77d6d2
    static let huskBorder = Color.white.opacity(0.08)

    static let safeLabel = Color(red: 0.35, green: 0.72, blue: 0.48)
    static let reviewLabel = Color(red: 0.91, green: 0.64, blue: 0.36)
    static let cautionLabel = Color(red: 0.95, green: 0.55, blue: 0.28)
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
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func string(for bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Shared chrome

struct HuskBackground: View {
    var glow: Color = .huskPrimary.opacity(0.18)

    var body: some View {
        ZStack {
            Color.huskBg
            RadialGradient(
                colors: [glow, .clear],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .blur(radius: 8)
        }
        .ignoresSafeArea()
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
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? Color.huskPrimary : Color.huskSurfaceHigh)
            )
            .foregroundStyle(prominent ? Color.huskOnPrimary : Color.huskText)
        }
        .buttonStyle(.plain)
    }
}

struct HuskSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.huskText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.huskTextMuted)
            }
        }
    }
}
