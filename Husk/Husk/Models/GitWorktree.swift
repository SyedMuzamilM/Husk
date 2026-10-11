import Foundation

struct GitWorktree: Identifiable, Sendable {
    var id: String { path }
    let path: String
    let branch: String?
    let locked: Bool
    let prunable: Bool
    let bare: Bool
    var status: String = "Not checked"
}
