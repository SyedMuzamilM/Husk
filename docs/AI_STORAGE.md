# AI storage and maintenance

Implemented 2026-10-11. Husk discovers documented default locations without reading conversation contents. The native AI Storage screen separates caches, sessions, worktrees, model downloads and installed tools. It shares cache rules with Cleanup, uses immutable removal plans, moves reviewed caches to Trash, and records results through the existing operation journal. No AI service or model is called to classify or delete files.

## Cleanup policy

Only explicit cache leaves are selectable, and only with complete size coverage. Every AI cache is Review, never preselected by Select Safe. Quit the owning tool first. Process activity is checked at scan, review and immediately before each move. A failed, timed-out or truncated process probe blocks cleanup. Generic Node, Bun or Deno activity also blocks CLI caches when attribution is unknown. Desktop ownership is additionally checked against running bundle IDs.

The process probe reads executable names with `ps -axo comm=`, never command arguments, prompts, tokens or environment variables. These are best-effort activity checks, not an atomic lock against a process starting after the probe. Existing identity, owner, exclusion and symlink checks still apply; Foundation Trash retains a small path-based race window.

Sessions, installed runtimes, models, updater staging and worktrees are protected at the shared path-policy boundary, including removal through Storage Map and Applications. Credential roots remain unreadable to the sizing service. Claude's entire `.claude` state, OpenCode's data directory and Codex's Application Support directory are not traversed. Other listed storage is measured using metadata only; an unavailable size is displayed as **Not measured**, never as a measured zero.

## Recognized locations

All paths below are relative to the current user's home. Paths are included only when they exist, belong to the user and have no unsafe symlink components. Exclusions apply. Custom `CODEX_HOME`, XDG overrides, custom model paths, arbitrary plugins and unknown tools are not guessed. Missing paths are normal, not scan errors.

| Tool | Reviewed cache cleanup | Inspection only |
|---|---|---|
| Codex | `Library/Caches/Codex/{Default,Default/Partitions/codex-browser-app,codex-browser-app}/{Cache,Code Cache}` | `.codex/sessions`, `.codex/archived_sessions`, `.codex/worktrees`, `.cache/codex-runtimes`, app support, updater staging |
| Claude | `Library/Application Support/Claude/{Cache,Code Cache,GPUCache,DawnGraphiteCache,DawnWebGPUCache}` | `.claude/projects`, `.claude/worktrees`, native installed versions, bundled agent/VM versions |
| Cursor | Same Chromium leaves under Cursor; `CachedData` | `User/workspaceStorage`, Cursor Agent versions |
| Gemini / Antigravity | Same Chromium leaves under Antigravity; `.gemini/antigravity-browser-profile/Default` cache leaves | `.gemini/tmp`, which contains chats and checkpoints |
| OpenCode | `.cache/opencode` | `.local/share/opencode`, which includes authentication, session database and snapshots |
| Ollama / LM Studio / Hugging Face | Existing desktop-client cache rules remain in Cleanup | Installed model stores |
| Copilot | None added without a verified cache rule | Installed CLI versions |
| Grok | No verified standalone macOS cache path added | Use browser storage controls for the web app |

Caches may download or regenerate after removal. Workspaces, model weights, version stores, restore snapshots, SQLite databases and their WAL/SHM files are never treated as disposable because of their age or directory name.

## Worktree inspection

Choose a repository from AI Storage → Worktrees → Inspect repository. Husk reads NUL-delimited `git worktree list --porcelain -z`, preserving names containing spaces and newlines. It reports registration paths, branch/detached state, locks, stale registrations and bounded Git status. It checks ownership and avoids excluded, cloud and redirected locations. Git's optional index writes, filesystem monitors and hooks are disabled for these probes; inherited `GIT_*` environment overrides are removed.

A clean status does **not** establish inactivity. Ignored files, submodule state, active build processes and owner-specific references are not verified. Husk never invokes `git worktree remove`, prunes registrations or moves linked working copies to Trash. Inspection is limited to 30 worktrees, a 20-second status budget and a 3-second timeout per status command. An incomplete status remains unknown.

## Mole and primary-source research

Mole was inspected read-only at revision [`49475f1d5cf82243530ef64c0d64da2cbfcebecd`](https://github.com/tw93/Mole/tree/49475f1d5cf82243530ef64c0d64da2cbfcebecd). Its code and documentation distinguish regenerable caches from durable state, preserve the active executable and rollback versions, and guard updates against active installers. Husk independently implements the storage catalog and native review UI. No Mole implementation was copied. Mole's GPL licensing still needs an owner decision before any code reuse.

Relevant source files:

- [Mole developer cleanup](https://github.com/tw93/Mole/blob/49475f1d5cf82243530ef64c0d64da2cbfcebecd/lib/clean/dev.sh): fixed Codex profile leaves, Gemini browser caches, OpenCode cache, active-version and installer protections. Gemini `tmp`, Claude state and OpenCode snapshots are preserved.
- [Mole app protection](https://github.com/tw93/Mole/blob/49475f1d5cf82243530ef64c0d64da2cbfcebecd/lib/core/app_protection.sh): Codex session/database exclusions and separation of desktop uninstall from CLI state.
- [Mole project cleanup](https://github.com/tw93/Mole/blob/49475f1d5cf82243530ef64c0d64da2cbfcebecd/lib/clean/project.sh): recognized worktree containers; working copies themselves are not purge targets.
- [Gemini session management](https://geminicli.com/docs/cli/session-management/) and [repository documentation](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/session-management.md): project chats under `.gemini/tmp/<project_hash>/chats`, resume, checkpoints and retention.
- [OpenCode troubleshooting](https://opencode.ai/docs/troubleshooting/): cache reset under `.cache/opencode`; data and authentication under `.local/share/opencode`.

## Remaining work

Session deletion requires owner-specific database/index consistency, exports and active-session checks. Worktree removal requires nested-repository, ignored-file, dirty-state and activity checks plus Git-managed removal. Version pruning requires active executable resolution, rollback retention, updater locks and fresh reference checks. See [AI_STORAGE_DISCUSSION.html](AI_STORAGE_DISCUSSION.html) for the proposed policy choices. None of these operations are presented as already implemented.

Quick Look maintenance now accurately runs `qlmanage -r cache` after a native confirmation. RAM purges, privileged DNS resets and automatic process termination are not added.
