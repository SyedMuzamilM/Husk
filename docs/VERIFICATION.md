# Verification

Latest application verification: 2026-10-15.

## Storage Map overview, 2026-10-15

The native Storage Map now has actual volume capacity, shared cleanup recommendations, nested category/cleanup tiles and a bounded startup disk overview. Cleanup selections and removal plans use the existing Cleanup model and reviewed Trash service. No new cleanup rule or permanent-deletion path was added.

`scripts/verify.sh` passed on the development host with 70 tests across 17 suites, including four opt-in checks disabled in the normal run, plus repository checks, eight release-source tests, Debug and universal Release builds, bundled-license comparisons and Git whitespace checks. The added fixtures cover overlapping recommendations, conservative risk labels, partial-cache selection, omitted/hidden map allocation, bounded nested previews, injected startup roots, stale capacity results, cross-volume breadcrumb capacity and nested-folder navigation. Tests do not scan a real home directory or move existing user data.

The native fixture runner produced 20 captures and 24 passing checks, including light and dark storage views at 960x640 and 1200x720. It checked storage scan-to-results table transitions, map/list switching and selection of verified caches. It also captured cleanup colors and the selected state. Local screenshots use example data and are stored under `/tmp/husk-storage-map-final-screens`; logs are `/tmp/husk-storage-map-final-ui.log` and `/tmp/husk-storage-map-verification.log`.

Reproduce the storage UI check after building:

```sh
HUSK_UI_SCREEN_FILTER=storage \
HUSK_UI_ASSETS=/tmp/husk-storage-map-verification/xcode/Build/Products/Debug/Husk.app/Contents/Resources/Assets.car \
  scripts/ui-smoke.sh /tmp/husk-storage-map-final-screens
```

The startup overview measures Home, Applications, Library and `/opt` with existing privacy exclusions and per-root budgets. Remaining allocation is explicitly System & unmeasured, not a removal candidate. Nested previews are bounded and do not establish that a directory is disposable. Full VoiceOver, macOS 14 and Intel runtime checks remain release gates. No release, signing, notarization or installation was performed during verification.

## Earlier application verification, 2026-10-13

This pass follows the compact onboarding fix at `aa90aaf`. It incorporates the earlier listing/release repairs and fixes lifecycle, cancellation, stale-state, and large-result performance regressions. The entire app is MIT licensed on `main`. Private security and conduct reports go to muzamil@mzml.dev. No repository visibility change, push, signing, or notarization was performed.

## Corrections

- Analyze no longer returns to loading when cancelled immediately after Scan. It ignores obsolete loads and does not rescan after a removal completes in a closed window.
- Clean, Analyze, Apps, and AI tasks release their models while work is suspended. Models own and cancel their tasks; stale completion and failure paths cannot replace a newer result.
- Apps refresh clears a disappeared selected app and its old related files. AI worktree inspection clears old results and has an owned cancellable task.
- Window teardown and onboarding replay stop background work. UI fixtures skip protected-home permission probes. Free-space metadata runs through bounded I/O.
- Cleanup caches filtered rows and selection totals. Bulk selection updates once per action. Fixed rules live in CleanTargetCatalog, discovery is bounded and streamed, and target dedup resolves paths once.
- Review preparation resolves candidate paths once while preserving nested risks and ownership checks. Filesystem eligibility checks moved onto BlockingIO.
- Directory listing streams and retains top-K rows, shares hardlink accounting, and enforces a global entry/time budget.
- Native secondary controls use the existing darker amber in light mode. Primary filled buttons keep the original palette. Settings includes bundled MIT/TourKit licenses and source/report links.
- Release builds use a clean committed archive. Verification checks pinned CI actions and byte-for-byte matching notices in source and built apps.

## Evidence

Development host: Apple Silicon, macOS 27, Xcode 27 beta, Swift 6.4, local APFS. Deployment remains macOS 14, with Xcode 26.2 / Swift 6.2 as the declared minimum. Local results do not validate those runtime/toolchain minima or Intel execution.

| Check | Result |
|---|---|
| Swift suite | 60 tests across 16 suites; 56 active by default and four opt-in checks. Normal run passed in 6.383 seconds. |
| Thread Sanitizer | Same normal fixture suite passed in 5.899 seconds; no race report. |
| Address Sanitizer | Same normal fixture suite passed in 5.879 seconds; no memory-error report. |
| Release-source tests | Eight disposable-repository regressions pass, covering dirty/untracked files, archive isolation, committed license/vendor contents, source changes, export rules, and unsupported submodules. |
| Build | Debug and universal Release pass with signing disabled. `lipo` reports x86_64 and arm64. Both license resources match their originals. |
| Native fixture UI | 94 captures in light/dark at 960x640 and 1200x720. Scan/results/rescan layout, filtering, selection, protected AI controls, review/results, and tour interaction checks pass. |
| Production scene | 560x600 tour on launch/replay; Get started persists completion without Full Disk Access; main window expands to 960x640. |
| Real Trash integration | A newly created disposable file passed through the production Foundation Trash mover, the returned destination retained the payload, and a programmatic move restored it. No existing user files were moved. This does not test Finder's Put Back command. |
| Large listing | 100,000 entries visited, complete coverage, 100 rows retained, 99,900 omitted. 7.609 seconds, 27.56 MiB peak RSS and 12.09 MiB footprint. The 160 MiB service RSS budget passed. |
| Credential-pattern scan | 355 historical Git blobs and 207 current files checked; zero high-confidence private-key, AWS-key, GitHub-token, or OpenAI-style-token matches. No historical blob exceeded the 5 MB scan cap. This is not exhaustive secret detection. |
| Scripts | Shell syntax, repository policy checks, and Git whitespace checks pass. Disposable checker fixtures correctly reject a mismatched license and an unpinned CI action. |

Swift 6.4 warns about immutable weak test locals; they remain compatible with the declared Swift 6.2 minimum. Xcode skips AppIntents metadata extraction because Husk does not use AppIntents. Neither warning is a test/build failure.

The lifecycle tests were first run against the broken behavior. Immediate cancellation and suspended model-owner tests failed, then passed after the task changes. A separate test reproduced the late removal-triggered rescan before its generation check was added.

## Measured fixture performance

Optimized builds on the development host, with OS cache and background-process effects:

| Workload | Before | After |
|---|---:|---:|
| 50 result reads / selection changes over 10,000 cleanup rows | 0.1456 s | 0.000097 s |
| Deduplicate 1,000 cleanup targets | 27.68 s | 0.0836 s |
| Select and clear 10,000 safe rows | Still running after 3 minutes; stopped | 0.0260 s |
| Prepare a 300-item removal review | 0.6040 s | 0.2785 s |

The bulk-selection issue came from rebuilding and sorting selected totals for every insertion/removal. It now assigns each set operation once. These measurements describe fixtures, not a whole-app speed guarantee or reclaimed storage. The earlier dedup/redraw baseline and the bulk-selection regression were separate runs.

## Reproduce

From the repository root:

```sh
HUSK_VERIFY_ROOT=/tmp/husk-verification scripts/verify.sh
HUSK_PROFILE_MODE=listing scripts/profile-sizing.sh
HUSK_UI_ASSETS=/tmp/husk-verification/xcode/Build/Products/Debug/Husk.app/Contents/Resources/Assets.car \
  scripts/ui-smoke.sh /tmp/husk-ui-captures
HUSK_UI_WINDOW_ONLY=1 scripts/ui-smoke.sh
cd Husk
swift test --scratch-path /tmp/husk-tsan --sanitize=thread
swift test --scratch-path /tmp/husk-asan --sanitize=address
HUSK_RUN_INTERACTION_BENCHMARKS=1 swift test -c release --filter InteractionBenchmarks
HUSK_RUN_TRASH_INTEGRATION=1 swift test --filter TrashIntegrationTests
```

UI runners require local Screen Recording access. Ordinary tests inject removal. The opt-in Trash test explicitly exercises a real move and restore using only its own new fixture. It does not enumerate or empty the user's Trash.

Logs and screenshots from this pass were written under `/tmp/husk-opensource-*`, with additional `/tmp/husk-bulk-selection-*`, `/tmp/husk-review-*`, and `/tmp/husk-trash-integration.log` records. They are local artifacts, not committed evidence bundles, and may be cleared by macOS.

## Remaining release gates

- Maintainer publishes the repository, runs remote CI, and enables private vulnerability reporting and available repository protections. Email is the current private reporting route.
- Maintainer supplies local signing/notary credentials; actual notarization, Gatekeeper on a clean machine, and public artifact distribution remain untested.
- Test macOS 14 and Intel runtime compatibility, fresh-user disk-access flows, case-sensitive/external volumes, and interactive Finder restoration.
- Complete VoiceOver/keyboard and long-session GUI allocation/energy profiling, including sleep/wake. Service memory/resource fixtures do not establish a leak-free GUI.
- Foundation Trash and PID identity retain documented same-user race windows. Arbitrary unknown app activity is not fully attributable.
- AI sessions, worktrees, installed versions, and model data remain inspection-only. New cleanup support requires tool-specific reference, activity, and recovery evidence.

See [release preparation](RELEASING.md) for the distribution checklist and signing commands. A clean checkout is required for release-source verification.

## Committed-source verification

The final application/policy revision is `a403aa34e9fd3d84b8d7b92a239e3a80e26a3969`. A fresh temporary local clone passed the clean-source gate, and prepare-release-source.sh exported its committed files. The archive contained neither Git metadata nor the unrelated `idea/` directory. The full verify.sh sequence exited successfully from that archive, including repository checks, eight release-source tests, the Swift suite, Debug, universal Release, and both bundled-license comparisons. No signing credentials were used.

Final native contrast verification produced 94 captures and 100 passing check messages. Later documentation consolidation does not alter the tested application code or build scripts. Earlier reports and audit artifacts are available in Git history.
