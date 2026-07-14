//
//  HuskBrandMark.swift
//  Husk
//

import SwiftUI

/// Transparent husk seed logo used in the rail, onboarding, and heroes.
struct HuskBrandMark: View {
    var size: CGFloat = 40
    var showGlow: Bool = false
    var glowRadius: CGFloat = 24

    var body: some View {
        ZStack {
            if showGlow {
                Circle()
                    .fill(Color.huskPrimary.opacity(0.18))
                    .frame(width: size * 1.55, height: size * 1.55)
                    .blur(radius: glowRadius * 0.45)
            }
            Image("HuskLogo")
                .resizable()
                .interpolation(.high)
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .shadow(
                    color: showGlow ? Color.huskPrimary.opacity(0.28) : .clear,
                    radius: glowRadius * 0.5,
                    y: 6
                )
                .accessibilityLabel("Husk")
        }
        .frame(width: size, height: size)
    }
}
