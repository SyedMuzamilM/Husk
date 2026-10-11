import AppKit
import SwiftUI

struct RemovalReviewSheet: View {
    let plan: RemovalPlan
    let confirm: (RemovalPlan) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(plan.title, systemImage: "trash").font(.title2.weight(.semibold))
            Text("\(plan.entries.count) unique items · \(ByteFormat.string(for: plan.estimatedBytes)) estimated allocated size")
            Text("Moves go to Trash. Disk space is usually released after you empty Trash. Restore with Finder's Put Back when available.")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach(plan.entries) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(URL(fileURLWithPath: entry.path).lastPathComponent).font(.headline)
                            Spacer()
                            SafetyBadge(label: entry.safety)
                            Text(ByteFormat.string(for: entry.bytes)).monospacedDigit()
                        }
                        Text(entry.path).font(.callout.monospaced()).textSelection(.enabled)
                        Text(entry.reason).font(.callout).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                ForEach(plan.skipped) { issue in
                    VStack(alignment: .leading) {
                        Text(issue.path).font(.callout.monospaced()).textSelection(.enabled)
                        Text(issue.message).foregroundStyle(Color.cautionLabel)
                    }
                }
            }
            if plan.hasCaution {
                Toggle("I reviewed the personal data and settings that may be removed.", isOn: $acknowledged)
            }
            HStack {
                Text("Review expires after five minutes.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Move to Trash", role: .destructive) {
                    dismiss()
                    confirm(plan)
                }.buttonStyle(.borderedProminent).disabled(plan.entries.isEmpty || (plan.hasCaution && !acknowledged))
            }
        }.padding(24).frame(width: 680, height: 540)
    }
}

struct RemovalResultSheet: View {
    let result: TrashResult
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(result.hasProblems ? "Removal completed with issues" : "Moved to Trash", systemImage: result.hasProblems ? "exclamationmark.triangle" : "checkmark.circle").font(.title2.weight(.semibold))
            Text("\(result.successCount) items · \(ByteFormat.string(for: result.totalBytes)) estimated size moved")
            if let error = result.journalError { Text(error).foregroundStyle(Color.cautionLabel) }
            if result.cancelled { Text("Cancelled. Items already moved remain in Trash.").foregroundStyle(Color.cautionLabel) }
            List {
                ForEach(result.destinations) { item in
                    VStack(alignment: .leading) {
                        Text(item.originalPath).textSelection(.enabled)
                        Text("Trash destination: " + item.trashPath).foregroundStyle(.secondary).textSelection(.enabled)
                    }.font(.callout.monospaced())
                }
                ForEach(result.failures, id: \.path) { issue in
                    Text(issue.path + "\n" + issue.error).foregroundStyle(Color.cautionLabel).textSelection(.enabled)
                }
                ForEach(result.skipped) { issue in
                    Text(issue.path + "\n" + issue.message).foregroundStyle(Color.cautionLabel).textSelection(.enabled)
                }
            }
            HStack {
                Button("Open Trash") { NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")) }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 680, height: 500)
    }
}
