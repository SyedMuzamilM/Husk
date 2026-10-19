# Audit resolution

This ledger records repaired safety and correctness findings and their remaining limits. Application repairs start at `8139214`; later lifecycle and performance fixes are included in `a403aa3`. See [verification](VERIFICATION.md) for recorded checks and reproduction commands. Original audits and earlier reports remain in Git history.

| Finding | Result | Remaining work or limitation |
|---|---|---|
| F01 protected parents | Implemented ancestor/descendant overlap checks and root denial, including credential/cloud/Trash paths | Extend fixtures across case-sensitive and external filesystems. |
| F02 symlinks and identity | Implemented realpath normalization, symlink-component rejection, immutable identity snapshots, revalidation, and five-minute expiry | Foundation Trash has a residual path race. Root identity does not detect every interior file edit. |
| F03 unsafe Safe rules | Removed bulk histories, whole model/VM/install stores; unknown caches/logs require Review; unverified temp/linked stores downgraded | Version-specific regeneration evidence and rule fixtures remain required before expanding Safe rules. |
| F04 uninstall ownership | Removed token/display-name heuristics and group containers; only exact full bundle-ID paths; no Review/Caution defaults; shared installed copies preserve data | Exact association is evidence, not proof of disposability. System/own app removal is blocked. More shared-owner metadata is future work. |
| F05 project proof | Ambiguous build/dist/dependencies/environments removed. Opt-in recognized cache discovery requires a manifest and is inspection-only | Implement tracked-content, nested-repo, and active-build checks before project deletion. |
| F06 subprocess deadlock | ProcessRunner drains both pipes concurrently with bounded output, deadline, TERM/KILL, cancellation, and direct-child reaping | Fixed internal commands only; do not introduce arbitrary shell pipelines or untrusted commands. |
| F07 Mach rights | Both host calls deallocate acquired send rights | Ten repeated production samples show no host-right growth; long sleep/wake profiling remains. |
| F08 retained status model | Sampling loop avoids holding the model across await/sleep; isolated deinit cancels task | Model-release fixture passes. Long sampling, window-close, and sleep/wake resource profiling remains. |
| F09 stale tasks/progress | Per-task cancellation and generation checks replace resettable shared flags; stale progress/results ignored; prior results preserved | Add full UI rapid interaction coverage on supported OS versions. |
| F10 overlap/mutable review | Shared actor gate, immutable review list, replay rejection; highest nested risk retained; differing nested owners rejected | Review sheet execution is explicit. A future agent/API endpoint must not bypass visible human review. |
| F11 hidden failures | All destinations, failures, skipped items, cancellation, and history-write failures shown; unsuccessful items remain selected | Disposable-file Trash and programmatic restoration pass; interactive Finder Put Back and external-volume checks remain. |
| F12 duplicate accounting | Canonical exact/nested target dedup and unique plan identities | Cross-target hardlinks/APFS shared blocks prevent a guarantee of uniquely freed bytes. |
| F13 misleading disk totals | Measure eligible children before top-K, include hidden/package contents, aggregate the parent with shared hardlink accounting, show Other/partial/unavailable and issues | Per-child shared blocks can exceed independent parent totals. Listing time budget can leave unavailable children. |
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


## Current safeguards and follow-up

The shared AI catalog allows reviewed cleanup of fixed cache leaves. Unknown or incomplete activity probes block removal. Sessions, models, runtimes, updater staging, and version stores are protected across Cleanup, Storage Map, and Applications. Git worktree inspection is read-only; a clean Git status does not prove inactivity. See [AI storage](AI_STORAGE.md) for source evidence and limits.

Scan models own cancellable tasks, avoid retaining themselves across long awaits, and reject obsolete completions. Window teardown stops background work. Cleanup caches rows and totals at input changes, and bulk selection updates once per action. Full directory listings retain top-K rows under a global work budget.

Husk uses the [Husk Source-Available License](../LICENSE); [prior MIT rights](LICENSING.md) remain intact. Private reports go to muzamil@mzml.dev. Remaining distribution checks include minimum-OS and Intel runtimes, fresh-user permissions, external filesystems, interactive Finder restoration, full accessibility traversal, and long-session GUI profiling. Signing and notarization require maintainer credentials. See [release preparation](RELEASING.md).
