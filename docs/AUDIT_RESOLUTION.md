# Audit resolution, 2026-10-11

Application repairs start at `8139214`; the subsequent memory follow-up bounds temporary Foundation object lifetime.

The original audit remains a record of the pre-fix code. This ledger describes the resulting implementation and what still needs verification. "Implemented" does not mean certified safe for public distribution.

| Finding | Result | Remaining work or limitation |
|---|---|---|
| F01 protected parents | Implemented ancestor/descendant overlap checks and root denial, including credential/cloud/Trash paths | Extend fixtures across case-sensitive and external filesystems. |
| F02 symlinks and identity | Implemented realpath normalization, symlink-component rejection, immutable identity snapshots, revalidation, and five-minute expiry | Foundation Trash has a residual path race. Root identity does not detect every interior file edit. |
| F03 unsafe Safe rules | Removed bulk histories, whole model/VM/install stores; unknown caches/logs require Review; unverified temp/linked stores downgraded | Version-specific regeneration evidence and rule fixtures remain required before expanding Safe rules. |
| F04 uninstall ownership | Removed token/display-name heuristics and group containers; only exact full bundle-ID paths; no Review/Caution defaults; shared installed copies preserve data | Exact association is evidence, not proof of disposability. System/own app removal is blocked. More shared-owner metadata is future work. |
| F05 project proof | Ambiguous build/dist/dependencies/environments removed. Opt-in recognized cache discovery requires a manifest and is inspection-only | Implement tracked-content, nested-repo, and active-build checks before project deletion. |
| F06 subprocess deadlock | ProcessRunner drains both pipes concurrently with bounded output, deadline, TERM/KILL, cancellation, and direct-child reaping | Fixed internal commands only; do not introduce arbitrary shell pipelines or untrusted commands. |
| F07 Mach rights | Both host calls deallocate acquired send rights | Ten repeated production samples show no host-right growth; long sleep/wake profiling remains. |
| F08 retained status model | Sampling loop avoids holding the model across await/sleep; isolated deinit cancels task | Model-release fixture passes. Full window/sleep lifecycle remains manual. |
| F09 stale tasks/progress | Per-task cancellation and generation checks replace resettable shared flags; stale progress/results ignored; prior results preserved | Add full UI rapid interaction coverage on supported OS versions. |
| F10 overlap/mutable review | Shared actor gate, immutable review list, replay rejection; highest nested risk retained; differing nested owners rejected | Review sheet execution is explicit. A future agent/API endpoint must not bypass visible human review. |
| F11 hidden failures | All destinations, failures, skipped items, cancellation, and history-write failures shown; unsuccessful items remain selected | Real Finder Trash/restore integration on disposable volumes remains. |
| F12 duplicate accounting | Canonical exact/nested target dedup and unique plan identities | Cross-target hardlinks/APFS shared blocks prevent a guarantee of uniquely freed bytes. |
| F13 misleading disk totals | Measure eligible children before top-K, include hidden/package contents, independently measure parent, show Other/partial/unavailable and issues | Per-child shared blocks can exceed independent parent totals. Listing time budget can leave unavailable children. |
| F14 sizing semantics/deadlines | One native metadata contract; no du fallback; allocated sizes, explicit logical fallback when unavailable; cooperative 20s/1M traversal and 60s listing budgets | A blocked kernel or filesystem call can exceed the cooperative budget. Need slow/network-volume trials. |
| F15 blocking task bursts | Shared four-worker BlockingIO queue, bounded child fan-out, and per-entry autorelease pools | Some small metadata/identity calls remain outside that queue. Real peak memory at 1M entries is not measured. |
| F16 Analyze main-thread Trash | All UI mutation goes through the shared actor and detached worker | Native Finder Trash calls may themselves block. |
| F17 hidden project caches | Hidden discovery enabled; .git/dependency/environment descent excluded; explicit depth/visit/hit-limit issues | Project cache deletion remains disabled. |
| F18 live owners | Known bundle IDs checked during planning and again before each move; project/model/VM cleanup disabled where unverified | Arbitrary/unknown app and CLI activity is not comprehensively attributed. General active-use detection remains open. |
| F19 process identity | Native start-time/UID/command identity, fresh validation, positive PID/self/session protection, normal Quit and explicit Force | Residual PID race remains between final validation and OS request. Requests are not reported as confirmed exits. |
| F20 misleading metrics | All returned processes counted; lifetime process CPU vs host interval labeled; memory estimate/unknown flags, pressure/swap when available, physical free vs important-usage capacity separated | Native metric accuracy across supported OS/hardware still needs comparison with Activity Monitor. |
| F21 accessibility/navigation | Native cleanup Table, Analyze List, separate controls, accessible map actions, labeled/compact navigation, system/light/dark appearance, Reduce Motion navigation | Full VoiceOver, contrast, scaled display, and keyboard walkthrough is unverified. |
| F22 treemap identity | Rectangles use node IDs instead of fresh UUIDs | Layout recomputation is bounded to displayed children; deeper profiling could justify caching. |
| F23 permission coverage | Indicator described as a readability heuristic; refresh on scene activation; per-item partial/unavailable plus discovery coverage | FDA denied/granted and nonexistent probes need fresh-user integration runs. |
| F24 concurrency/build hygiene | Swift 6 mode, immutable Sendable DiskNode, value byte formatting, page-size API, personal signing team removed, unassigned icons removed | Built on Xcode 27/Swift 6.4. Minimum Xcode 26.2 CI is authored but not yet run. Locked flags have narrow documented unchecked boundaries. |
| F25 stale details/discovery/maintenance | Bounded nested app discovery, stale inspector clearing, no user Trash target, actual Quick Look result, DNS/RAM guidance separated from executable tasks | Discovery remains bounded to three levels/10K entries per app root. |

## Verification performed

Environment: Apple Silicon, macOS 27.0 build 26A428, Xcode 27.0 build 27A5218g, Swift 6.4, local APFS SSD. The deployment target remains macOS 14. Tests on this development OS do not validate all macOS 14+ behavior.

- Swift package regression suite passes. See Tests/HuskCoreTests for policy, removal gate/replay, stale identity, symlink swap, exclusion overlap, largest/hidden/package sizes, hardlinks, discovery, command supervision/cancellation, host rights, descriptor reuse, and view-model lifetime fixtures.
- The Trash mover is injected for mutation tests. Existing user data was never sent to Trash by verification.
- Debug and Release builds pass with signing disabled and Swift 6 mode. Remaining Xcode note: AppIntents metadata extraction is skipped because this app has no AppIntents dependency. A universal Release build also succeeds for arm64 and x86_64.
- Thread Sanitizer suite result is recorded in VERIFICATION.md. Sanitizer coverage is the service fixtures, not a full UI workload.
- scripts/verify.sh and scripts/release.sh pass shell syntax checking. Release signing/notarization and remote CI are not executed.
- App launch produced a visible app window. The host could not capture its window image, so visual/VoiceOver verification is not claimed.
- A limited secret-pattern scan of Git history found no matches; see SOURCE_PROVENANCE.md for its scope.

The opt-in benchmark command is `HUSK_RUN_BENCHMARKS=1 swift test --filter BenchmarkTests` from Husk. Empty-file metadata fixtures produced:

| Entries | First traversal | Second traversal | Cancellation after request |
|---|---:|---:|---:|
| 10,000 | 0.847 s | 0.785 s | 1.19 ms |
| 100,000 | 8.001 s | 8.195 s | 0.13 ms |

All measured entries were visited, with complete coverage. These are local fixture runs with OS cache effects, not controlled cold-disk tests or guarantees. No 1M-entry, network filesystem, real Trash, or memory-footprint result is claimed.

## Publication and product decisions

Implemented preparation: accurate README, contribution/security/privacy/rule documents, source inventory, minimal read-only CI, and local signing/notarization tooling. Pending owner decisions: OSI license and copyright identity, asset rights, private security contact, contribution terms, Apple signing/notary credentials, release OS/hardware matrix, and whether any future paid services fit the open-source model.

Mole-inspired changes shipped here are transparent review, exclusions, shared measurement, list alongside treemap, labeled navigation, honest coverage, local history, and task-specific maintenance. AI Storage now inventories model/session/tool stores and offers Git worktree inspection, with shared protection across all removal screens. Owner-managed session deletion, model removal and version pruning remain future work. Ports, live charts/menu bar and read-only MCP are also future product work. Automatic deletion, permanent deletion, arbitrary-shell plugins, and privileged hardware control remain deferred.


## UI refinement and AI storage follow-up

The app retains the original compact rail, warm amber palette, centered cleanup hero and rounded panels. Light-mode text uses darker amber/teal variants; native tables preserve stable identities and keyboard selection. The native fixture runner passed 52 captures at two sizes in both appearances, visible control-label checks and an actual Select Safe click. Full VoiceOver/keyboard and fresh-user permission walkthroughs remain unverified.

The shared AI catalog admits only fixed cache leaves for review. Unknown or empty activity probes block cleanup; known executables and unattributed CLI JavaScript runtimes block affected caches. Activity is rechecked before each Trash move. Broad AI containers, sessions, models, runtimes, updater staging and version stores are protected from Analyze/Apps removal too. Case variants cannot bypass root protection. Read-only Git worktree probes disable hooks, fsmonitor and optional index writes and ignore inherited GIT_* settings. Clean status never implies inactivity. See AI_STORAGE.md for paths, source evidence, residual activity/path races and omitted custom tool homes.
