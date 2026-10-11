import Foundation

/// Explicit storage leaves. Never infer a cache from a tool's entire home folder.
/// Sources and intentional omissions are documented in docs/AI_STORAGE.md.
enum AIStorageCatalog {
    static let rules: [AIStorageRule] = {
        var rules: [AIStorageRule] = []
        func add(_ tool: String, _ path: String, _ kind: AIStorageKind, _ detail: String, _ owner: String? = nil) {
            rules.append(AIStorageRule(tool: tool, relativePath: path, kind: kind, detail: detail, ownerBundleID: owner))
        }
        let desktops = [("Claude", "Claude", "com.anthropic.claudefordesktop"),
                        ("Cursor", "Cursor", "com.todesktop.230313mzl4w4u92"),
                        ("Antigravity", "Antigravity", "com.google.antigravity")]
        for (tool, folder, owner) in desktops {
            for leaf in ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache"] {
                add(tool, "Library/Application Support/\(folder)/\(leaf)", .cache,
                    "Rebuilt by the app. Close the app first; the next launch may be slower.", owner)
            }
        }
        for leaf in ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache"] {
            add("Gemini", ".gemini/antigravity-browser-profile/Default/\(leaf)", .cache,
                "Antigravity browser cache. Cookies, history and saved logins are preserved.", "com.google.antigravity")
        }
        for profile in ["Default", "Default/Partitions/codex-browser-app", "codex-browser-app"] {
            for leaf in ["Cache", "Code Cache"] {
                add("Codex", "Library/Caches/Codex/\(profile)/\(leaf)", .cache,
                    "Codex Chromium runtime cache. Close Codex first. Browser state stays protected.", "com.openai.codex")
            }
        }
        add("Cursor", "Library/Application Support/Cursor/CachedData", .cache, "Generated editor bytecode. Close Cursor first.", "com.todesktop.230313mzl4w4u92")
        add("OpenCode", ".cache/opencode", .cache, "Downloaded dependencies and generated cache. Close OpenCode first; packages may download again.")
        add("Codex", ".codex/sessions", .sessions, "Conversations used by resume and indexed state. Manage them in Codex; Husk never reads prompts or removes indexed history.")
        add("Codex", ".codex/archived_sessions", .sessions, "Archived conversations remain user data and may be referenced by Codex's database.")
        add("Claude", ".claude/projects", .sessions, "Transcripts, persistent memory and project context. This sensitive location is not traversed by Husk.")
        add("Gemini", ".gemini/tmp", .sessions, "Despite its name, tmp stores project chats and checkpoints. Use Gemini's session browser to manage history.")
        add("OpenCode", ".local/share/opencode", .sessions, "Session database, snapshots, authentication and restore state. This sensitive location is not traversed by Husk.")
        add("Cursor", "Library/Application Support/Cursor/User/workspaceStorage", .sessions, "Workspace state can include conversations. Removing it can lose editor state.")
        add("Codex", ".codex/worktrees", .worktrees, "Git-linked working copies can contain uncommitted work. Inspect with Git before removing a registered worktree.")
        add("Claude", ".claude/worktrees", .worktrees, "Working copies can contain uncommitted changes. This sensitive location is not traversed by Husk.")
        add("Ollama", ".ollama/models", .models, "Installed model weights. Use Ollama's model manager to remove an individual model.")
        add("LM Studio", ".lmstudio/models", .models, "Downloaded model weights. Manage individual models in LM Studio.")
        add("Hugging Face", ".cache/huggingface/hub", .models, "Model snapshots may be shared or required offline. Use the owner's cache manager.")
        add("Claude", ".local/share/claude/versions", .tools, "Installed versions. File age cannot prove a version is unused; the active executable and rollback references must be verified.")
        add("Cursor", ".local/share/cursor-agent/versions", .tools, "Installed agent versions. Keep active and rollback versions; do not infer usage from modified dates.")
        add("Copilot", ".copilot/pkg/universal", .tools, "Installed CLI versions. Manage updates with the tool's installer.")
        add("Codex", ".cache/codex-runtimes", .tools, "Installed Node/Python runtimes may back active sessions. Version and installer ownership are not yet verified.")
        add("Codex", "Library/Caches/com.openai.codex", .tools, "Updater staging can be needed by Sparkle. Keep it until installer locks and active versions can be verified.")
        add("Claude", "Library/Application Support/Claude/claude-code", .tools, "Bundled agent versions. Claude's active SDK version must be verified before removing a version.")
        add("Claude", "Library/Application Support/Claude/claude-code-vm", .tools, "Bundled VM and rollback versions. Removing these can disrupt running sessions.")
        add("Codex", "Library/Application Support/Codex", .tools, "App state and installed runtimes. This sensitive location is not traversed by Husk.")
        return rules
    }()

    static func cacheRule(for path: String, home: String = NSHomeDirectory()) -> AIStorageRule? {
        let canonical = PathSafety.canonicalPath(path)
        return rules.first {
            let root = PathSafety.canonicalPath($0.path(home: home))
            return $0.removable && (canonical.lowercased() == root.lowercased() || PathSafety.isDescendant(canonical, of: root))
        }
    }
}
