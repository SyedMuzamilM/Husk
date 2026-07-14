//
//  SafetyBadge.swift
//  Husk
//

import SwiftUI

struct SafetyBadge: View {
    let label: SafetyLabel

    var body: some View {
        Label(label.title, systemImage: label.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
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
            .foregroundStyle(.primary)
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
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: HuskTheme.cardCorner, style: .continuous))
    }
}

extension View {
    func huskCard() -> some View {
        modifier(CardBackground())
    }
}
