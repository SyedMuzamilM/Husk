//
//  SafetyBadge.swift
//  Husk
//

import SwiftUI

struct SafetyBadge: View {
    let label: SafetyLabel

    var body: some View {
        Text(label.title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(label.color)
            .background(label.color.opacity(0.14), in: Capsule())
            .accessibilityLabel("Safety: \(label.title)")
    }
}

struct SizeText: View {
    let bytes: Int64
    var monospaced = true

    var body: some View {
        Text(ByteFormat.string(for: bytes))
            .font(monospaced ? .body.monospacedDigit().weight(.medium) : .body.weight(.medium))
            .foregroundStyle(Color.huskPrimary)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.huskPrimary.opacity(0.85))
            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.huskText)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.huskTextMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            if let actionTitle, let action {
                HuskPillButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
