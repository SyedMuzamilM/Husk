import SwiftUI

enum StorageMapColorMode: String, CaseIterable, Identifiable {
    case category = "Category"
    case cleanup = "Cleanup"
    var id: Self { self }

    func color(for node: DiskNode, summary: StorageMapSummary) -> Color {
        if node.isAggregate { return .gray }
        if self == .category { return StorageCategory.classify(node.path).color }
        return summary.safety(for: node.path)?.color ?? .gray
    }
}
