import Foundation

enum AIStorageKind: String, CaseIterable, Identifiable, Sendable {
    case cache = "Caches", sessions = "Sessions", worktrees = "Worktrees", models = "Models", tools = "Tools"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .cache: "internaldrive"
        case .sessions: "text.bubble"
        case .worktrees: "arrow.triangle.branch"
        case .models: "cpu"
        case .tools: "wrench.and.screwdriver"
        }
    }
}

struct AIStorageRule: Identifiable, Sendable {
    var id: String { relativePath }
    let tool: String
    let relativePath: String
    let kind: AIStorageKind
    let detail: String
    var ownerBundleID: String? = nil
    var removable: Bool { kind == .cache }
    func path(home: String) -> String { (home as NSString).appendingPathComponent(relativePath) }
}

struct AIStorageItem: Identifiable, Sendable {
    var id: String { path }
    let rule: AIStorageRule
    let path: String
    let measurement: SizeMeasurement
    let blockedReason: String?
    var canRemove: Bool { rule.removable && blockedReason == nil && measurement.status == .complete }
    var safety: SafetyLabel { canRemove ? .review : .protected }
}

struct AIStorageReport: Sendable {
    let items: [AIStorageItem]
    let issues: [OperationIssue]
    let scannedAt: Date
}
