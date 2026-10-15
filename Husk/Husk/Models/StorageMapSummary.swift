import Foundation

/// Summaries operate on the scanner's reviewed catalog, never on folder names.
struct StorageMapSummary: Sendable {
    let safeItems: [CleanItem]
    let reviewItems: [CleanItem]
    let inspectionItems: [CleanItem]
    private let safetyByPath: [String: SafetyLabel]
    var safeBytes: Int64 { safeItems.reduce(0) { $0 + $1.byteCount } }
    var reviewBytes: Int64 { reviewItems.reduce(0) { $0 + $1.byteCount } }

    init(items: [CleanItem]) {
        // Keep one leaf for overlapping paths, even when supplied by multiple catalogs.
        var retained: [CleanItem] = []
        var coveredAncestors: Set<String> = []
        for item in items.sorted(by: {
            if $0.path.count != $1.path.count { return $0.path.count > $1.path.count }
            if $0.safety != $1.safety { return $0.safety > $1.safety }
            return $0.completeness != .complete && $1.completeness == .complete
        }) {
            let path = URL(fileURLWithPath: item.path).standardizedFileURL.path.lowercased()
            guard !coveredAncestors.contains(path) else { continue }
            retained.append(item)
            var ancestor = path
            while ancestor != "/" && !ancestor.isEmpty {
                coveredAncestors.insert(ancestor)
                ancestor = (ancestor as NSString).deletingLastPathComponent
            }
        }
        retained.sort { $0.byteCount == $1.byteCount ? $0.path < $1.path : $0.byteCount > $1.byteCount }
        safeItems = retained.filter { $0.safety == .safe && $0.completeness == .complete }
        reviewItems = retained.filter { $0.safety != .protected && !($0.safety == .safe && $0.completeness == .complete) }
        inspectionItems = retained.filter { $0.safety == .protected }
        safetyByPath = Dictionary(uniqueKeysWithValues: retained.map {
            (URL(fileURLWithPath: $0.path).standardizedFileURL.path.lowercased(),
             $0.safety == .safe && $0.completeness != .complete ? .review : $0.safety)
        })
    }

    func safety(for path: String) -> SafetyLabel? {
        var path = URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
        while path != "/" && !path.isEmpty {
            if let safety = safetyByPath[path] { return safety }
            path = (path as NSString).deletingLastPathComponent
        }
        return nil
    }
}
