//
//  OptimizeView.swift
//  Husk
//

import SwiftUI

struct OptimizeView: View {
    @State private var runningID: String?
    @State private var lastMessage: String?
    @State private var lastSuccess: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Optimize")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.huskText)
                Text("Safe maintenance only — no placebo RAM liberators.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.huskTextMuted)
            }
            .padding(.horizontal, HuskTheme.contentPadding)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(OptimizeService.tasks) { task in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: task.systemImage)
                                .font(.title2)
                                .foregroundStyle(Color.huskPrimary)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.huskText)
                                Text(task.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.huskTextMuted)
                                if task.needsAdmin {
                                    Text("May require administrator permission")
                                        .font(.caption)
                                        .foregroundStyle(Color.cautionLabel)
                                }
                            }
                            Spacer()
                            Button {
                                Task {
                                    runningID = task.id
                                    let result = await OptimizeService.run(task)
                                    lastSuccess = result.success
                                    lastMessage = result.message
                                    runningID = nil
                                }
                            } label: {
                                if runningID == task.id {
                                    ProgressView().controlSize(.small).tint(Color.huskPrimary)
                                } else {
                                    Text("Run")
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(Color.huskPrimary))
                                        .foregroundStyle(Color.huskOnPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(runningID != nil)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.huskSurface.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.huskBorder)
                                )
                        )
                    }

                    if let lastMessage {
                        HStack(alignment: .top) {
                            Image(systemName: lastSuccess == true ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundStyle(lastSuccess == true ? Color.safeLabel : Color.reviewLabel)
                            Text(lastMessage)
                                .font(.callout)
                                .foregroundStyle(Color.huskTextSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.huskSurfaceHigh.opacity(0.5))
                        )
                    }
                }
                .padding(.horizontal, HuskTheme.contentPadding)
                .padding(.bottom, 24)
            }
        }
    }
}
