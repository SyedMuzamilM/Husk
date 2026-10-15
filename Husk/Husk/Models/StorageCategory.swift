import SwiftUI

/// Display categories describe storage, never whether it is safe to remove.
enum StorageCategory: String, CaseIterable, Identifiable, Sendable {
    case documents, applications, projects, developer, models, caches
    var id: Self { self }
    var title: String {
        switch self {
        case .documents: "Documents & media"
        case .applications: "Apps & other"
        case .projects: "Code projects"
        case .developer: "SDKs & tools"
        case .models: "AI models"
        case .caches: "Package caches"
        }
    }
    var color: Color {
        switch self {
        case .documents: .orange
        case .applications: .gray
        case .projects: .purple
        case .developer: .cyan
        case .models: .pink
        case .caches: .blue
        }
    }

    static func classify(_ path: String) -> Self {
        let parts = path.lowercased().split(separator: "/").map(String.init)
        if parts.contains(where: { [".ollama", ".lmstudio", "huggingface"].contains($0) }) { return .models }
        if parts.contains(where: { ["caches", "cache", ".cache", "node_modules", ".npm", ".pnpm", "pnpm", ".yarn", ".next", ".turbo", "deriveddata"].contains($0) }) { return .caches }
        if parts.contains(where: { ["developer", "coresimulator", "android", ".android", ".gradle", ".rustup", ".cargo", ".nvm"].contains($0) }) { return .developer }
        if parts.contains(where: { ["projects", "work", "github", ".git", ".t3", ".vscode", "androidstudioprojects"].contains($0) }) { return .projects }
        if parts.contains(where: { ["desktop", "documents", "downloads", "pictures", "movies", "music"].contains($0) }) { return .documents }
        return .applications
    }
}
