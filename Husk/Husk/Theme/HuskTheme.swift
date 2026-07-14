//
//  HuskTheme.swift
//  Husk
//

import SwiftUI

enum HuskTheme {
    static let sidebarWidth: CGFloat = 220
    static let minWindowWidth: CGFloat = 980
    static let minWindowHeight: CGFloat = 640
    static let cardCorner: CGFloat = 12
    static let chipCorner: CGFloat = 6
}

extension Color {
    static let huskAccent = Color.accentColor
    static let safeLabel = Color(red: 0.28, green: 0.68, blue: 0.42)
    static let reviewLabel = Color(red: 0.90, green: 0.68, blue: 0.20)
    static let cautionLabel = Color(red: 0.92, green: 0.48, blue: 0.20)
    static let protectedLabel = Color.secondary

    static let treemapPalette: [Color] = [
        Color(red: 0.85, green: 0.58, blue: 0.35),
        Color(red: 0.55, green: 0.70, blue: 0.45),
        Color(red: 0.45, green: 0.62, blue: 0.82),
        Color(red: 0.75, green: 0.55, blue: 0.72),
        Color(red: 0.40, green: 0.72, blue: 0.70),
        Color(red: 0.88, green: 0.70, blue: 0.40),
        Color(red: 0.60, green: 0.55, blue: 0.80),
        Color(red: 0.70, green: 0.65, blue: 0.45)
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
