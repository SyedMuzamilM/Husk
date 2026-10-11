//
//  SafetyBadge.swift
//  Husk
//

import SwiftUI

struct SafetyBadge: View {
    let label: SafetyLabel

    var body: some View {
        Text(label.title)
            .font(.callout.weight(.medium))
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
            .foregroundStyle(Color.huskAccentText)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action { HuskPillButton(title: actionTitle, action: action) }
        }
    }
}
