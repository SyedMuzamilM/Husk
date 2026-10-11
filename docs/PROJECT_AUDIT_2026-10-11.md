# Husk project audit

Date: 2026-10-11. Reviewed commit `ce39387` plus the existing working-tree changes. This is an audit of the current project, not just its latest diff.

## Assessment

Husk is a native macOS 14+ utility for cache cleanup, developer and AI storage review, disk visualization, app removal, and basic system monitoring. It is a functioning early beta. I would keep destructive operations in an internal beta until the safety and reliability findings below are fixed.

The strongest product direction is a transparent, local Mac storage tool for developers, with useful monitoring alongside it. The current code needs a stronger deletion policy and more accurate measurements before it needs more cleanup targets. Open-sourcing it can help reviewers inspect those policies, but publication alone does not make them safe.

There are 39 Swift files, about 5,332 lines. The implementation uses SwiftUI, Observation, Foundation, AppKit, Darwin/Mach APIs, and three system executables: `du`, `ps`, and `qlmanage`. There are no declared Swift package dependencies, Rust engine, SQLite store, MCP server, network client, privileged helper, or licensing implementation in the app target. Several product documents describe those planned components as though they already exist.

## Scope and evidence

- Read all 39 Swift files, the Xcode project and asset configuration, repository setup, safety policy, and product/architecture/roadmap documents.
- Reviewed existing uncommitted edits in `CleanModels`, `CleanScanner`, `CleanViewModel`, `PathSafety`, and `CleanView`. Preserved them.
- Built Debug and Release with signing disabled using Xcode 27.0 beta and Apple Swift 6.4 on Apple Silicon. Both succeeded. This does not verify signing, notarization, Intel compatibility, or execution on macOS 14.
- Tried a Swift 6 language-mode build with complete concurrency checking. It failed on the shared `ByteCountFormatter` and `vm_kernel_page_size` access. Release also emits concurrency/capture warnings in `AnalyzeViewModel` and `CleanViewModel`.
- Ran focused Swift fixture probes against the services. No files were moved to Trash. Temporary fixture files were created and removed under `/tmp`.
- Verified a production metrics sample times out on this host, and isolated its pipe deadlock using the same `ps` invocation.
- Verified Mach send-right reference growth and a status-loop object lifetime issue. The lifetime probe substitutes an immediate metrics service so it can examine the production loop independently of the `ps` hang.
- Reviewed competitor primary sources. These are website/source comparisons, not independent hands-on tests of those apps. See [the competitor report](COMPETITOR_AUDIT_2026-10-11.md).
- Saved the isolated [probe runner and observations](audit/README.md). A short Leaks-template launch recording was inconclusive: exported measurements were absent and its recorded build path did not match the intended Release executable. It cannot support a leak-free conclusion.

This is not a claim that every possible leak, race, malicious filesystem layout, or macOS compatibility problem has been ruled out. Long-running Instruments sessions, sanitizer checks, signed builds, supported-OS tests, and destructive-flow tests on disposable volumes remain release work.

## What works today

| Area | Implemented | Limits |
|---|---|---|
| Clean | Known cache/log/package-manager/IDE/AI targets, project artifact discovery, progress, cancellation controls, filtering, sorting, detail inspector | Risky classifications, duplicated/nested targets, silent errors, incomplete cancellation |
| Analyze | Shallow squarified treemap, breadcrumbs, folder drill-down, reveal/copy/trash | Arbitrary child sampling, hidden entries omitted, incomplete totals, no directory chooser, no list alternative |
| Apps | Top-level `/Applications` and user Applications listing, lazy bundle sizing, leftover search, Trash operation | Loose matching, risky default selection, no shared ownership proof, no running-app coordination |
| Status | CPU delta, approximate memory, disk capacity, load, thermal state, top process list, Quit/Force Quit | Pipe hang, Mach resource leak, no network/battery/disk I/O/history, process count is truncated |
| Optimize | Quick Look refresh | DNS is instructions only; RAM entry is informational but presented as runnable |
| Settings/onboarding | FDA settings links, heuristic permission probe, onboarding replay, safety explanations | No ignore rules, privacy/security links, updater, appearance control, or permission coverage report |

Useful foundations already exist: cleanup calls a central Trash service, there is no permanent-delete API in the app's cleanup implementation, Clean initially selects nothing, most UI state is on `MainActor`, the main Clean scan limits sizing to six concurrent tasks, and protected paths are checked both during discovery and mutation. No analytics SDK or in-app outbound network code was found. Hardened Runtime is enabled in the build settings.

## Priority definitions

**P0** blocks a public release with deletion or process-control features enabled. **P1** should be fixed before a dependable public beta. **P2** improves correctness, usability, and maintainability after those foundations. Severity reflects consequences, not an estimate that every user will encounter the problem.

## P0 findings

### F01. Path protection allows deletion of protected directories through their parents

Evidence: [PathSafety.swift](../Husk/Husk/Services/PathSafety.swift), lines 40-69; [AnalyzeView.swift](../Husk/Husk/Views/Analyze/AnalyzeView.swift), lines 222-225; [TrashService.swift](../Husk/Husk/Services/TrashService.swift), lines 27-43.

The deny list blocks a sensitive directory and its descendants. It does not block ancestors containing that directory. `~/Library/Keychains` is protected, but `~/Library` is accepted. A Home map can offer the Library folder itself for Trash. `/Users` is also accepted by the mutation service. Trashing a permitted parent can include protected contents. OS permissions may refuse some system moves; they do not replace Husk's promised protection for user data.

Fix: keep separate policies for reading, cache cleanup, app removal, and explicit user-file deletion. Reject blanket home/Library/container roots and ancestors of mandatory protected paths. Only accept an approved operation plan built from concrete selected targets. Ensure every entry point uses this policy, including Analyze and future automation.

Acceptance: protected descendants remain protected when their parent is selected. Read-only mapping can still display those parents.

### F02. Path validation does not resolve symlinked ancestors or bind approval to file identity

Evidence: [PathSafety.swift](../Husk/Husk/Services/PathSafety.swift), line 41; [TrashService.swift](../Husk/Husk/Services/TrashService.swift), lines 30-43.

`standardizingPath` alone does not establish the actual filesystem destination. A fixture symlink pointing to `/System` let `alias/Library` pass `isProtected`. A similar alias into sensitive user data bypasses the intended deny rule. This finding concerns a path inside a symlinked parent; trashing a symlink itself ordinarily moves the link.

There is also no identity check between scan, confirmation, and action. A directory can be replaced or redirected after the user approved it. This is a local filesystem integrity risk, not evidence of remote exploitation.

Fix: normalize and resolve ancestry, reject unsupported links/mount transitions, record volume/file identifiers and target type in a cleanup plan, and revalidate immediately before moving each item. Reject identity changes. Foundation path-based Trash calls still leave a small race window; document that limit and investigate stronger descriptor-based validation rather than claiming canonicalization makes it atomic.

Acceptance: symlink ancestors, replacement between scan and action, case variants, Unicode names, aliases, and renamed app bundles have fixture coverage. Protect Husk using its actual bundle identity/path, not the literal substring `/Husk.app`.

### F03. Some 'Safe' targets include history, installed software, or unverified app data

Evidence: [CleanScanner.swift](../Husk/Husk/Services/CleanScanner.swift), lines 423-465 and 482-499; [PathSafety.swift](../Husk/Husk/Services/PathSafety.swift), lines 82-125; [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 183-187.

Examples in the current target list:

- `.continue/dev_data` is explicitly described as session histories and chat archives, yet marked Safe.
- `.gemini/tmp` is treated as regenerable temp work without verifying the installed tool's storage format. Session data must not be classified solely from the directory name.
- The whole `Application Support/GitHub Copilot` folder is marked Safe without limiting it to verified cache subdirectories.
- `.vscode/extensions` and `.cursor/extensions` are installed extension directories, presented as extension caches.
- Claude/Cursor `versions` targets select the whole directory, although the explanation says to keep current versions. The code does not implement that retention rule.
- Whole `.aider`, `.lmstudio`, `.keras`, ChatGPT support, and Docker container directories are broader than pure regenerable caches. Some have warnings, but the operation is still whole-directory removal.

The blanket cache/log classifier also assumes location proves low regret. Cache directories can hold offline data or state; active tools may be writing to them. The hero's 'regenerable clutter only' claim is stronger than the implementation.

Fix: replace broad targets with versioned, individually reviewed rules that specify exact subdirectories, owner, data type, regeneration cost, app versions, and required inactivity. Put sessions, checkpoints, archives, installed extensions, and model libraries in explicit data-management workflows with stronger warnings and no Safe bulk selection. For tools whose storage format is unverified, exclude the target until fixtures prove it is cache-only.

Acceptance: 'Select Safe' cannot select session history, current tool installations, extensions, user models, or container data.

### F04. Uninstall matching can offer another app's data, then preselect it

Evidence: [AppUninstallService.swift](../Husk/Husk/Services/AppUninstallService.swift), lines 76-90 and 125-156; [AppsViewModel.swift](../Husk/Husk/Services/AppsViewModel.swift), lines 91-95.

Matching uses short bundle-ID/name tokens, prefix matches, and `contains(".token")`. A fixture for `com.vendor.notes` matched `com.unrelated.notes`. Application Support, Containers, and Group Containers can contain irreplaceable or shared data. There is no code-signing team correlation, entitlement inspection, other-installed-app ownership check, or confidence explanation.

The view model then selects both Safe and Review leftovers by default. This conflicts with [SAFETY.md](SAFETY.md), which says Review starts off and prefers false negatives over wrong-app deletion.

Fix: use exact bundle association first, include known app-specific rules, and verify group-container entitlements and shared ownership. Present heuristic matches as unselected uncertain suggestions. Never infer exclusive ownership from an app's display name alone. Default to only proven regenerable items, or select nothing.

Acceptance: same-vendor app suites, similarly named apps, multiple installations, shared containers, and spoofed bundle metadata cannot result in preselected unrelated data.

### F05. Generic folder names are treated as project build output without project proof

Evidence: [ProjectArtifactService.swift](../Husk/Husk/Services/ProjectArtifactService.swift), lines 21-40 and 92-125.

Discovery labels directories named `build`, `dist`, `target`, `Pods`, or `venv` as artifacts anywhere under common roots, including Desktop. It does not confirm a matching project manifest, tracked/untracked files, nested Git repositories, locally modified dependencies, or current build activity. A folder named `dist` can contain source or published assets that cannot be regenerated.

Fix: require project-type evidence such as `Cargo.toml`, `package.json` plus relevant lockfiles, or Swift manifests. Protect tracked files, nested repositories, deployment credentials, and ambiguous contents. Mark edited dependencies and vendored source as Caution or exclude them. Show the parent project, rebuild command, last activity, and reason for eligibility.

Acceptance: a Desktop `dist` folder with user documents is not offered as build junk; a Git-tracked build directory is excluded.

### F06. Monitoring can deadlock waiting for a subprocess whose pipe is full

Evidence: [SystemMetricsService.swift](../Husk/Husk/Services/SystemMetricsService.swift), lines 143-150; the same order exists in [OptimizeService.swift](../Husk/Husk/Services/OptimizeService.swift), lines 62-65.

The parent waits for process exit before reading stdout. If output fills the pipe, the child waits for the parent to read and never exits. On this host the actual `ps` invocation produced 185,036 bytes. Waiting before reading remained blocked after three seconds; a production `SystemMetricsService.sample()` probe did not return within five seconds. Killing the disposable probe ended it.

Fix: drain stdout/stderr while the child runs, bound captured output, add deadlines and cancellation, and always close handles/reap the process. Prefer native process enumeration where practical. Use one tested process runner for all system commands. Absolute executable paths and argument arrays already avoid shell interpolation; retain that property.

Acceptance: high process counts and large command output do not hang Status. Cancellation and timeout leave no child processes behind.

## P1 findings

### F07. Repeated metrics sampling leaks Mach host-port send rights

Evidence: [SystemMetricsService.swift](../Husk/Husk/Services/SystemMetricsService.swift), lines 41 and 70.

Each `mach_host_self()` call acquires a send-right reference that this code does not release. A focused probe measured references growing from 2 to 102 after 100 calls. The sampler calls it twice per sample. This is a verified resource leak; it is not the same as an ever-growing Swift heap allocation.

Fix: acquire a host port, pair it with `mach_port_deallocate(mach_task_self_, hostPort)` using `defer`, or safely own one reference for the service lifetime. Release it on all error paths too.

Acceptance: repeated successful and failed samples leave the port-reference count stable.

### F08. The status loop can retain its model until explicit stop

Evidence: [StatusViewModel.swift](../Husk/Husk/Services/StatusViewModel.swift), lines 50-68; [StatusView.swift](../Husk/Husk/Views/Status/StatusView.swift), lines 25-26; [ContentView.swift](../Husk/Husk/ContentView.swift), lines 74-85.

Despite `[weak self]`, `while let self` holds a strong reference across sleep and sampling. The model owns the task. The lifetime fixture confirmed it stays alive after its external owner disappears, then deallocates after `stop()`.

Current view-disappearance and section-change hooks mitigate this in normal navigation. This is a verified lifetime hazard when explicit stop is missed, not proof that every window close currently leaks.

Fix: make sampling a view-owned cancellable task, or limit the strong reference to one tick and release it before sleeping. Tie shutdown to window lifecycle and application activity. Add a regression lifetime test for close, onboarding replay, rapid navigation, and sampling failure.

### F09. Cancellation, task replacement, and progress publication can corrupt current UI state

Evidence: [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 110-157 and 194-207; [CleanScanner.swift](../Husk/Husk/Services/CleanScanner.swift), lines 20-35; [DiskAnalyzer.swift](../Husk/Husk/Services/DiskAnalyzer.swift), lines 32-33 and 62-63; [AnalyzeViewModel.swift](../Husk/Husk/Services/AnalyzeViewModel.swift), lines 37-73 and 85-117.

Cancellation/reset operations run in separate unstructured tasks. An old scan can finish or publish progress after a new one starts. Old catches/defers can clear the new operation's phase/loading flag. Scanner invocations share a resettable flag across actor reentrancy. DiskAnalyzer captures the Boolean cancellation state by value, so its explicit flag does not update within child work; task cancellation sometimes compensates, but the public `cancel()` contract is weaker than it looks.

Detail/app sizing does not consistently pass cancellation into `DirectorySizer`. Cancelled work may keep scanning, hold its view model, or delay newer actor work. Breadcrumb navigation does not cancel a pending drill operation. Clean rescan does not clear/cancel the inspected item.

Fix: give each operation its own cancellation token and generation ID. Cancel and await prior work in a defined order. Publish progress/results/errors only if the generation still matches. Apply `Task.checkCancellation()` inside traversal and process supervision. Avoid per-progress unstructured tasks by using an async progress stream or awaited callback.

Acceptance: rapid cancel/rescan/drill/select sequences cannot restore stale data or clear the newer loading state. Cancel completes within an explicit latency budget.

### F10. Mutation controls allow overlapping work and mutable confirmation targets

Evidence: [CleanView.swift](../Husk/Husk/Views/Clean/CleanView.swift), lines 22-35 and 70-85; [AppsView.swift](../Husk/Husk/Views/Apps/AppsView.swift), lines 46-61 and 212-215; [AppsViewModel.swift](../Husk/Husk/Services/AppsViewModel.swift), lines 108-150; [HuskApp.swift](../Husk/Husk/HuskApp.swift), lines 10 and 23-25.

Clean's keyboard shortcut checks `isScanning`, not `isBusy`, and Rescan remains available while trashing. Services lack a shared mutation gate. Multiple WindowGroup windows own independent models, while a global scan notification can trigger every visible Clean view. Apps selection can change while an uninstall awaits; its completion can then clear a newer selection or read a changed `includeAppBundle` flag. Dialog execution reads current selection rather than a frozen operation plan.

Fix: snapshot exact paths, identities, risks, and options at confirmation time. Serialize overlapping filesystem mutations across windows and modules. Guard reentry in the service/view model, not only button state. Target keyboard commands to the focused window. Disable conflicting selection/navigation actions or explicitly preserve their new state.

### F11. Partial failures are hidden or reported as success

Evidence: [TrashService.swift](../Husk/Husk/Services/TrashService.swift), lines 30-48; [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 226-245; [AnalyzeViewModel.swift](../Husk/Husk/Services/AnalyzeViewModel.swift), lines 142-157.

TrashService returns per-item failures instead of throwing. Clean ignores that list. The probe produced `finished(trashedBytes: 0, itemCount: 0)` for a nonexistent selected path. Analyze discards the result and returns true; the same fixture reported success for a nonexistent path. Analyze's error property is not displayed in its view. Status sets `lastError`, but the view never presents it. Apps reports only the first five failures.

Fix: return a structured operation result with success, failed, skipped, cancelled, and actual Trash destinations. Show all failed paths and reasons in a reviewable summary, preserve failed selection, and offer safe retry. Cancellation after partial progress must return that progress rather than discard it.

### F12. Duplicate and nested targets inflate byte counts and conflict during cleanup

Evidence: [CleanScanner.swift](../Husk/Husk/Services/CleanScanner.swift), lines 260-291, 330-370, 480-490, and 543-546; [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 84-95 and 222-224.

Generic cache discovery overlaps explicit targets such as Homebrew and Xcode. Diagnostic Reports is added both generically and explicitly. Hugging Face's root and `hub` child are both targets. On this host, target construction produced nine exact duplicate groups and one parent/child overlap. Counts vary with installed software.

UUID uniqueness and safe dictionary builders do not deduplicate filesystem targets. Selecting both copies counts bytes twice; selecting a parent and child moves one and causes the other to fail, in nondeterministic selection order. A recreated cache path could even be acted on again in the same operation.

Fix: deduplicate canonical target identities, merge category metadata, and collapse selected descendants under an approved selected parent. Make execution order deterministic. Apply the same rules to totals, selection, and deletion. Scan each physical target once.

### F13. The disk map presents partial measurements as full folder totals

Evidence: [DirectorySizer.swift](../Husk/Husk/Services/DirectorySizer.swift), lines 74-80, 98-111, and 140-143; [DiskNode.swift](../Husk/Husk/Models/DiskNode.swift), lines 43-46; [DiskAnalyzer.swift](../Husk/Husk/Services/DiskAnalyzer.swift), lines 28-49; [CacheDetailService.swift](../Husk/Husk/Services/CacheDetailService.swift), lines 39-70.

Analyze measures only the first `2 * maxChildren` entries returned by the filesystem, then keeps the largest `maxChildren` within that arbitrary sample. It can omit the actual largest directory. A fixture proved this with ten visible folders and a deliberately large folder outside the first four. Hidden folders are skipped, including many developer/AI storage roots. Protected/cloud folders are omitted from totals too. `DiskNode.byteCount` is merely the sum of retained children.

The detail inspector similarly selects the first 80 children before sorting and labels its results 'Largest'. Inaccessible directories become empty results instead of coverage errors. Zero/unavailable sizes disappear from the treemap.

Fix: enumerate every eligible child, use a bounded worker queue and streaming top-K selection, and separate measured total from displayed top entries. Represent 'Other', excluded, unavailable, and unmeasured bytes explicitly. Include hidden files when appropriate. Mark complete/partial/unavailable measurements instead of treating unknown as zero.

Acceptance: folder totals and biggest entries are correct regardless of enumeration order; inaccessible and skipped data stay visible as gaps in coverage.

### F14. Sizing fallback changes semantics and lacks a time bound

Evidence: [DirectorySizer.swift](../Husk/Husk/Services/DirectorySizer.swift), lines 26-49 and 150-230.

`du` has no deadline. Its error triggers a fallback that skips hidden files and package contents and silently stops after 250,000 entries. This can replace a failed complete measurement with an incomplete smaller number. There is no completeness/error field. Cancellation terminates `du` without waiting for exit or handling escalation. A subsequent fallback can briefly continue after cancellation.

`du` and independent file/directory measurements also cannot promise unique reclaimable bytes for APFS clones, hard links, snapshots, or files changing during a scan.

Fix: one explicit measurement contract, including allocated/logical bytes, completeness, errors, deadline, and cancellation. Propagate partial results rather than disguise them. Never label estimated allocated bytes as guaranteed additional free disk capacity.

### F15. Large bursts of blocking child work can starve Swift concurrency workers

Evidence: [DirectorySizer.swift](../Husk/Husk/Services/DirectorySizer.swift), lines 113-132 and 166-173; [CacheDetailService.swift](../Husk/Husk/Services/CacheDetailService.swift), lines 40-62; [AppUninstallService.swift](../Husk/Husk/Services/AppUninstallService.swift), lines 102-121.

Clean bounds concurrency to six, but other services enqueue up to 72/96 sizing tasks, 80 inspector tasks, or 40 leftover tasks at once. Those tasks perform synchronous filesystem operations and sleep/poll process state. The number of actually running tasks depends on the executor, but the implementation has no shared I/O/process limit and can block cooperative workers.

Fix: one global bounded sizing executor with a measured concurrency limit, process supervision, priority, and cancellation. Cache immutable results by identity/change metadata. Avoid rescanning a selected item fully and then each child again when the initial result already contains sufficient data. Benchmark against large fixture trees before choosing a Rust rewrite.

### F16. Analyze runs Trash synchronously on the main actor

Evidence: [AnalyzeViewModel.swift](../Husk/Husk/Services/AnalyzeViewModel.swift), lines 142-145.

The async method calls synchronous FileManager Trash directly on `MainActor`. Large moves, external volumes, or permission delays can freeze UI. Clean and Apps already offload their Trash calls.

Fix: route all mutations through the same supervised worker/service, with progress and an operation gate. Keep only state updates on the main actor.

### F17. Project discovery cannot find many declared hidden artifact types

Evidence: [ProjectArtifactService.swift](../Husk/Husk/Services/ProjectArtifactService.swift), lines 21-40 and 76-80.

The configured artifact set includes `.build`, `.next`, `.nuxt`, `.turbo`, `.venv`, `.gradle`, and others. Enumeration uses `.skipsHiddenFiles`, so those directories are never encountered. Default roots include case variants without identity deduplication on case-insensitive filesystems. Depth/hit caps do not have a completeness indicator.

Fix: traverse with explicit exclusions such as `.git`, discover relevant hidden artifact directories, normalize roots, support user-selected project roots, and report truncated discovery. Keep the conservative project proof required by F05.

### F18. No coordination with running apps, builds, models, or containers

Evidence: [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 217-229; [AppsViewModel.swift](../Husk/Husk/Services/AppsViewModel.swift), lines 108-129; broad targets in [CleanScanner.swift](../Husk/Husk/Services/CleanScanner.swift).

There is no running-app/build check before deleting caches or uninstalling. Processes can recreate moved paths or continue holding deleted/moved resources. Whole Docker container removal can include volumes; whole model stores remove useful models without manifest-aware selection. Trash helps recover files but does not guarantee the running app will remain consistent or a tool will be restored correctly.

Fix: associate rules with owners, warn/skip in-use targets, request graceful app quit with user approval, and revalidate after quitting. Use Docker's supported inspection/prune APIs for selected regenerable resources; preserve volumes by default. Use model manifests and names for Ollama/LM Studio, with explicit whole-library deletion only in a separate data-management flow.

### F19. Process control trusts a stale PID and does not enforce ownership

Evidence: [SystemMetricsService.swift](../Husk/Husk/Services/SystemMetricsService.swift), lines 198-204; [StatusView.swift](../Husk/Husk/Views/Status/StatusView.swift), lines 34-37 and 143-153.

The confirmation snapshot stores only a PID for execution. A process can exit and the PID can be reused before the action. The row records `isOwnedByUser`, but the service/UI do not use it. The service accepts zero/negative PIDs, which have process-group semantics with `kill`, though current `ps` rows provide positive PIDs. It also offers control for Husk itself and sensitive user session services.

Fix: require a positive PID, revalidate process identity/start time/user, reject self and protected session processes, enforce ownership, and warn about unsaved changes. Force Quit must remain explicit. Surface the actual error and distinguish a signal request from confirmed process exit.

### F20. Disk, memory, and process labels overstate what is measured

Evidence: [SystemMetricsService.swift](../Husk/Husk/Services/SystemMetricsService.swift), lines 28, 75-84, 102-104, and 188-193; [SystemMetrics.swift](../Husk/Husk/Models/SystemMetrics.swift), lines 48-67; [StatusView.swift](../Husk/Husk/Views/Status/StatusView.swift), lines 74-89.

`processCount` is the returned top-40 count, not total system processes. Search/sorting only covers this weighted subset. `ps %CPU` has different averaging semantics from host CPU interval deltas. Memory is an approximation from active/speculative/wired/compressed pages, not Activity Monitor's app-memory or pressure model. Thread count is always zero. `volumeAvailableCapacityForImportantUsage` may include purgeable capacity, although the UI simply calls it disk free.

Fix: distinguish total process count, visible ranking count, unknown metrics, physical free capacity, and capacity available for important usage. Add memory pressure and swap using appropriate native measurements. Label approximations. 'Running normally' should not be inferred only from a low CPU/RSS threshold.

Trashing does not usually increase free disk capacity until Trash is emptied. Cleanup totals must say 'moved to Trash', while any measured disk delta is reported separately. Existing completion wording mostly follows that distinction; 'reclaimable' and inclusion of existing Trash still need refinement.

## P2 findings

### F21. Accessibility and navigation need a native list alternative

Evidence: [CleanView.swift](../Husk/Husk/Views/Clean/CleanView.swift), lines 243-250 and 355-368; [AppsView.swift](../Husk/Husk/Views/Apps/AppsView.swift), lines 26-33, 107, and 168-174; [TreemapView.swift](../Husk/Husk/Views/Analyze/TreemapView.swift), lines 29-75; [HuskTheme.swift](../Husk/Husk/Theme/HuskTheme.swift), lines 10-11.

Selection/clear/refresh buttons lack useful text labels or explicit accessibility labels. Clean nests a selection Button inside an inspector Button. Treemap cells depend on tap gestures and have no explicit keyboard selection or accessible actions. Much essential path/safety text uses fixed 9-11 point fonts. The app forces dark appearance and does not read Reduce Motion/contrast settings. A 1000x680 minimum plus large fixed onboarding content needs testing on scaled displays.

Fix: separate row selection and checkbox controls, use native Toggle/Table/List semantics, add a keyboard-accessible Analyze list view, and expose name/size/risk/actions for map cells. Use semantic fonts where possible and respect system appearance, Reduce Motion, increased contrast, and color differentiation. Safety badges already include words and accessibility labels; keep them.

Example selection button shape:

```swift
Button("Select item", systemImage: "circle") { model.toggle(item) }
    .labelStyle(.iconOnly)
    .accessibilityLabel("Select \(item.name) for cleanup")
```

### F22. Treemap identity changes on every layout calculation

Evidence: [TreemapLayout.swift](../Husk/Husk/Services/TreemapLayout.swift), lines 109-111; [TreemapView.swift](../Husk/Husk/Views/Analyze/TreemapView.swift), lines 16-26.

Each layout creates a fresh UUID for every rectangle. A probe confirmed identical input produces different IDs. SwiftUI treats unchanged cells as replaced views, creating unnecessary work and complicating selection/focus/animation.

Fix: use the node ID as the rectangle ID and cache layout by stable nodes and geometry. For this constructor, replace `id: UUID()` with `id: node.id`.

### F23. Permission status is a heuristic without per-path scan coverage

Evidence: [PermissionService.swift](../Husk/Husk/Services/PermissionService.swift), lines 58-83; [SettingsView.swift](../Husk/Husk/Views/Settings/SettingsView.swift), lines 32-36.

Readability of a few Safari/Mail paths does not establish universal FDA capability. False negatives occur when those files do not exist; a positive probe also does not promise every path is readable. Rechecks do not occur automatically after returning from System Settings. Suppressed filesystem errors make permission gaps look like a clean disk.

Fix: describe permission status as detected/undetected/unknown, refresh on app activation, and report scan coverage at the path level. Allow limited scans without FDA and ask for broad access at the point of need. Do not request Accessibility or root privileges for capabilities that do not need them.

### F24. Swift 6 readiness is incomplete and unchecked sendability needs containment

Evidence: [HuskTheme.swift](../Husk/Husk/Theme/HuskTheme.swift), line 53; [SystemMetricsService.swift](../Husk/Husk/Services/SystemMetricsService.swift), line 75; [DiskNode.swift](../Husk/Husk/Models/DiskNode.swift), lines 8-14 and 43-55; [AnalyzeViewModel.swift](../Husk/Husk/Services/AnalyzeViewModel.swift), lines 52-55.

The project sets Swift 5 language mode. Strict Swift 6 checking exposes shared formatter and imported mutable-global errors. `DiskNode` is mutable and `@unchecked Sendable` without locking. Current construction mostly builds it before publication, so this is an unenforced safety assumption rather than a demonstrated data race. `CancelFlag` and `ProgressThrottle` do use locks; their unchecked declarations are better justified.

Fix: actor-isolate UI formatting or use a Sendable format style, use a supported page-size API with a narrowly justified imported-state boundary, make disk results immutable values, and resolve capture diagnostics. Switch the project to Swift 6 when the complete build passes rather than applying unchecked annotations broadly.

### F25. App discovery, stale inspection, and maintenance UX are incomplete

Evidence: [AppUninstallService.swift](../Husk/Husk/Services/AppUninstallService.swift), lines 19-21; [CleanViewModel.swift](../Husk/Husk/Services/CleanViewModel.swift), lines 110-123 and 231-243; [OptimizeService.swift](../Husk/Husk/Services/OptimizeService.swift), lines 17-46.

Apps inside vendor subfolders are absent from the listing. Clean retains old inspector/last scan state through rescan and successful deletion. Existing Trash is offered as a cleanup target although moving `.Trash` to itself is not a meaningful supported cleanup operation. Optimize offers Run buttons for DNS guidance and a RAM explanation; no operation is performed for either.

Fix: discover nested apps within a bounded depth without descending app bundles, deduplicate copies by identity, clear stale inspection state, and present Trash as an informational 'Open Trash' row. Rename Optimize to Maintenance or Troubleshoot and expose actionable tasks, prerequisites, effects, and actual applied/skipped/unavailable results. Keep memory advice as education outside the task list.

## Open-source and release readiness

Publishing the source and shipping a trusted downloadable cleaner are separate milestones. The repository can be made publicly reviewable with a clear beta warning and disabled risky rules before the deletion features are release-ready.

| Missing item | Required work |
|---|---|
| License | Choose an actual OSI-approved license and add LICENSE with correct copyright ownership. Apache-2.0 is a reasonable recommendation for an independently developed app if permissive reuse and an explicit patent grant are desired. MIT or GPL-3.0 are other deliberate choices. Do not choose solely to match a competitor. |
| Source provenance | Inventory code, copied rules, logo/images, design assets, fonts, snippets, and any future dependencies. Verify rights and attribution. Mole CLI is GPL-3.0; proprietary Mole GUI assets and other source-available projects have different terms. Reading behavior is different from copying implementation/assets. |
| Accurate README | State current Swift implementation, supported OS/toolchain, unsigned local build steps, known dangers, and current capabilities. Mark Rust, SQLite, MCP, billing, ports, sensors, and menu bar as plans. Decide whether the old free/Premium pricing model still fits the requested open-source strategy. |
| Contribution process | CONTRIBUTING, code of conduct, issue/PR templates, maintainer/support expectations, rule contribution format, and a reviewed safety checklist for new cleanup rules. |
| Security reporting | SECURITY.md with a private vulnerability reporting route, supported versions, threat model, and response policy. Existing SAFETY.md is useful product policy but lacks a private security-reporting workflow. |
| Regression tests | Add a real test target/shared test scheme. Fixtures for paths, rule classification, project detection, matching, duplicate/nested selections, mutation results, cancellation, process output/deadlines, and resource lifetimes. No test target currently exists. |
| CI | Build Debug/Release, test, and check strict concurrency on pinned supported Xcode versions. Verify signing-disabled contributor builds without your Apple team. Pin Actions by commit, limit permissions, and keep secrets out of fork PR jobs. |
| Distribution | Developer ID signature, notarization and stapling, checksum/versioned artifacts, a documented release script, rollback instructions, and signed update metadata if an updater is added. Hardened Runtime build settings alone do not prove a distributed artifact is signed/notarized. |
| Compatibility | Test macOS 14 through current supported releases, Apple Silicon and Intel, APFS/case-sensitive APFS/exFAT/network volumes, FDA denied/granted, external Trash behavior, cloud placeholders, and multiple app copies. A macOS 14 deployment target is not runtime coverage. |
| Privacy | Plain privacy policy covering local paths/process names/history. Keep telemetry absent by default. Any future update check is a network operation and should be explained. Redact paths/usernames from shared diagnostics and avoid collecting file contents. |
| Build hygiene | Move the personal Development Team to local/release configuration, resolve unused asset warnings, avoid checking generated files into source, and keep dependency lockfiles if dependencies are introduced. No obvious private-key/API-key pattern was found in the reviewed current text, but Git-history/release-secret scanning is still required. A team ID is not a secret. |

Sandbox is disabled by design, which is common for direct-distribution utilities that need broad filesystem access. Do not assume switching it on is an easy security fix. Keep the main app unprivileged, limit operations at the service boundary, keep Hardened Runtime, and document why broad access is needed. There is no reason to add a privileged helper just to implement more cache cleanup.

Before future MCP support, make read-only tools the initial version. Local file paths and process names are sensitive data even when file contents are absent. Mutations should reference short-lived approved plan IDs and require a fresh visible human confirmation, with identity revalidation, local action records, and no arbitrary path or shell execution endpoint. A local agent request is not user consent.

## Recommended architecture changes

Keep Swift unless measurements show a concrete reason to move hot code elsewhere. A Rust rewrite does not fix false ownership matches, unsafe classifications, incomplete totals, or unapproved mutations.

Separate these responsibilities:

1. **Rules and ownership.** Exact target discovery and app/project/model ownership evidence. Every rule has a reason, data class, version assumptions, and fixtures.
2. **Measurement.** One bounded cancellable sizing service returning allocated bytes, completeness, timestamps, identities, and errors. Share results across Clean, Analyze, and Apps.
3. **Operation planning.** Immutable selected plan; no duplicates or nested conflicts; risk summary; app activity checks; identity snapshot.
4. **Mutation.** A serialized Trash service that revalidates policy, applies the plan, records destinations, and returns complete per-item outcomes.
5. **Metrics.** Correct native sampling, supervised command fallback, lifecycle-controlled tasks, and bounded local history.
6. **Presentation.** MainActor state, stable identities, accessible tables/maps, and no filesystem work in view updates.

Keep rule bundles declarative. Community rules should not execute shell commands or scripts. Treat imported rule sets as untrusted input and validate their paths and schema against the central policy.

## What Husk should build after the blockers

The [Mole comparison](COMPETITOR_AUDIT_2026-10-11.md) provides the verified source details. These recommendations are for Husk, not claims that all competitors implement them.

### Cleaner and developer storage

- Group artifacts by project/tool, with activity age, exact paths, rebuild cost, app-in-use status, and persistent ignore rules.
- Offer per-project `node_modules`, DerivedData and package caches only when ownership/regeneration is verified. Preserve Git-tracked content and local dependency edits.
- Inspect model names and manifest references. Separate unused downloads from active models; avoid presenting a whole model library as cache junk.
- Offer a dedicated session/history manager for AI tools with retention previews. Explain loss of chats/checkpoints. Do not include it in Select Safe.
- Add installer/large-file discovery with explicit user review, including age/source and partial scan status. Start with local Downloads; make cloud/external-volume scans opt-in.
- Add already-uninstalled app leftover discovery only after installed-app matching/shared ownership are safe.

### Better UI

- Keep Husk's amber identity, but use labeled navigation for discoverability, with an optional compact icon rail. A Home view can show actual free capacity, scan coverage, last action, and shortcuts without a health score.
- Replace the narrow mixed flat list with a resizable split view and real table columns for item, owner/project, size, age, risk, and activity. Keep the inspector for exact path and rule evidence.
- Add a cleanup review sheet showing the frozen list, total unique estimated bytes, Caution consequences, skipped running targets, and exclusions. Show per-item results and 'Open Trash' after action.
- Analyze needs a directory/volume picker, treemap/list toggle, hidden-file control, search, breadcrumbs/back-forward, 'Other' and unavailable areas, Quick Look, keyboard multi-selection, and stable selection after drill/back.
- Preserve scan/navigation caches between sections and make background activity visible. Support system appearance and accessible text sizes.

### Useful monitoring and maintenance

- First fix `ps`, host-port ownership, lifecycle, and measurement labels. Then add memory pressure/swap, disk I/O, network throughput, and battery using supported read-only APIs.
- Add short live charts and an optional menu bar HUD. Keep sampling slower when hidden/on battery and stop it when nobody needs it.
- Add bounded local metrics history with a user-controlled retention/export policy. Explain sustained pressure rather than a fabricated machine health grade.
- Add port ownership and 'Reveal owning process'; process termination uses the validated process-control service and explicit confirmation.
- Maintenance should be task-specific troubleshooting with measured outcomes. Quick Look refresh is useful; indiscriminate RAM purging, cache churn, database vacuuming, or Spotlight rebuilding can worsen performance. Do not advertise routine speed improvements without evidence.
- Keep advanced sensors read-only. Fan control and privileged hardware helpers carry substantially more compatibility and safety work and should be deferred.

### What to defer

Automatic scheduled deletion, permanent delete/Trash emptying, fan control, broad filesystem rules, copied competitor assets, arbitrary-shell plugins, and agent-triggered mutation. Also defer licensing infrastructure until the open-source/commercial model is explicitly decided. None is needed to prove the current app can clean accurately and safely.

## Delivery order and release gates

| Phase | Work | Exit condition |
|---|---|---|
| 1. Safe internal beta | Fix F01-F06, remove unsafe rules, make defaults conservative, supervise commands | Path/ownership/classification fixtures pass; no stale confirmation can broaden an operation; Status returns under high process count |
| 2. Dependable public beta | Fix F07-F20, shared sizing/mutation services, complete errors and scan coverage | Cancellation latency bounded; no task/process/port growth after repeated operations; honest unique byte accounting |
| 3. Public source and builds | License/provenance, docs, SECURITY/CONTRIBUTING, test target, CI, signed notarized release | A new contributor builds without personal signing setup; released artifact and source tag match; safety regressions block release |
| 4. Product polish | Accessible labeled navigation, table/inspector/review sheet, accurate Analyze, running-app-aware uninstaller | Keyboard/VoiceOver flows work; mixed success is understandable; restore instructions tested on disposable volumes |
| 5. Differentiation | Project/model/session management, menu bar, local history, ports, later read-only MCP | Each feature has a bounded performance budget and documented privacy/permission requirements |

Source publication can overlap earlier phases if clearly labeled as internal beta. Public destructive-feature release should still wait for its gates. Do not make the roadmap a date promise before the failure cases are tested.

## Verification still required

- Instruments Leaks/Allocations/VM Tracker and Time Profiler across repeated scan/cancel/rescan, inspector switching, Analyze drill/back, Apps selection, Status start/stop, window close, sleep/wake, and permission errors.
- Measure resident memory, physical footprint, live allocations, open file descriptors, Mach rights, child processes, and task counts before/after idle recovery. RSS alone is not proof of a leak; allocator caches can retain memory without retaining objects.
- Disposable filesystem integration tests for Trash success/failure, restoration, external/unavailable volumes, protected descendants, symlink swaps, unreadable paths, shared containers, case sensitivity, and APFS clone/hard-link size accounting.
- Race checks with Thread Sanitizer where supported, Address Sanitizer/guard diagnostics for applicable native boundaries, and complete Swift concurrency checks. A sanitizer run is additional evidence, not a substitute for policy tests.
- Benchmarks at 10K/100K/1M fixture entries, with cold/warm runs, hidden data, slow volumes, and budgeted cancellation. Set product budgets from measured hardware rather than inheriting the planned '<30s' and '<50 MB' claims.
- Signed/notarized compatibility runs on supported OS/hardware versions and a fresh user account without FDA.

No application fixes were made during this audit. The reports and isolated verification fixtures are the deliverables.
