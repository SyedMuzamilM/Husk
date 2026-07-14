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
            VStack(alignment: .leading, spacing: 6) {
                Text("Optimize")
                    .font(.title2.weight(.semibold))
                Text("Safe, explicit maintenance only — no placebo RAM liberators or fake scores.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            List {
                ForEach(OptimizeService.tasks) { task in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: task.systemImage)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.headline)
                            Text(task.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
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
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Run")
                            }
                        }
                        .disabled(runningID != nil)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.inset)

            if let lastMessage {
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: lastSuccess == true ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(lastSuccess == true ? Color.safeLabel : Color.reviewLabel)
                    Text(lastMessage)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .padding(16)
            }
        }
        .navigationTitle("Optimize")
    }
}
