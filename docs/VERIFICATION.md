# Verification record, 2026-10-11

Application repairs start at `8139214`; a subsequent memory follow-up changes only the traversal object lifetime.

Development environment: macOS 27.0 build 26A428, Apple Silicon, Xcode 27.0 build 27A5218g, Swift 6.4, local APFS SSD. This is not a compatibility claim for the macOS 14 minimum or Xcode 26.2 minimum. Remote CI has not run.

From Husk:

```sh
swift test --scratch-path /tmp/husk-fixes-tests
swift test --scratch-path /tmp/husk-tsan-tests --sanitize=thread
swift test --scratch-path /tmp/husk-asan-tests --sanitize=address
HUSK_RUN_BENCHMARKS=1 swift test --scratch-path /tmp/husk-fixes-tests --filter BenchmarkTests
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath /tmp/husk-fixed-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Release \
  -derivedDataPath /tmp/husk-fixed-build CODE_SIGNING_ALLOWED=NO build
```

| Check | Observed result |
|---|---|
| Regression suite | 29 tests passed; one optional benchmark test skipped in the normal run. Swift Testing reports 30 total tests. Final run completed in 8.094 seconds. |
| Thread Sanitizer | Same fixture suite passed in 8.746 seconds; no ThreadSanitizer race report in captured output. |
| Address Sanitizer | Same fixture suite passed in 8.154 seconds; no AddressSanitizer memory error report in captured output. |
| Large stdout/stderr | 300 KiB stdout plus stderr drained without pipe deadlock; timeout/output cap/cancellation fixtures pass. |
| Resources | 10 production metrics samples show no host-right growth; 30 repeated commands show no file-descriptor growth after warm-up. Status model releases after owner release. |
| Removal | Injected moves verify mixed success/failure, cancellation, expiry, running owners, symlink swaps, identity changes, protected paths, exclusions, nested risks, serialization, and replay rejection. |
| Sizing | Largest hidden child survives top-K; package contents included; hardlinks counted once; protected/symlink roots denied; limits return partial. |
| Builds | Debug and universal Release succeed, signing disabled, Swift 6 mode. `lipo -archs` confirms x86_64 and arm64. One unrelated Xcode metadata-extraction note for absent AppIntents dependency remains. |
| Release scripts | bash syntax check passes. Missing-license release gate rejects stub identity/profile labels before signing or network calls. No real signing/notarization performed. |
| App launch | Release app launches and creates an on-screen window. Window capture returned "could not create image from window". No visual, keyboard, or VoiceOver pass is claimed. |
| HTML discussion | Previewed at desktop and mobile widths; no horizontal overflow or console errors. Fields generate a local text draft only. |
| Git | Whitespace checks pass. Limited history scan examined 367 unique objects with no high-confidence key/token-pattern matches. No push or publication performed. |

## Native traversal memory follow-up

An optimized standalone probe compiled the actual sizing service and read the same 100K-entry empty-file fixture in two fresh processes. The initial implementation peaked at 543,244,288 bytes RSS, about 518.1 MiB, and 771,671,264 bytes physical footprint. Per-entry autorelease pools reduced those to 33,046,528 bytes RSS, about 31.5 MiB, and 17,023,672 bytes footprint. Both visited all 100,000 entries with complete coverage. Traversal times were 7.04 and 7.55 seconds. This identifies temporary Foundation object retention during the walk; it is not a full-GUI leak assessment.

Reproduce the current service with `scripts/profile-sizing.sh`. It creates its own empty-file fixture, compiles the current service with optimization, reports `/usr/bin/time -l` memory values, checks a default 160 MiB RSS budget for 100K entries, and removes its temporary files. Override with HUSK_PROFILE_ENTRIES or HUSK_PROFILE_RSS_LIMIT_MB for experiments. A second script run completed in 8.20 seconds with 34.27 MiB peak RSS and passed the budget. The pre-pool baseline exceeds that budget. The budget is an isolated-service regression check, not a product-wide memory promise.

Benchmark fixtures use newly created empty files. Both local traversals completed for 10K and 100K entries. 10K took 0.847/0.785 seconds; 100K took 8.001/8.195 seconds. Cancellation completed 1.19/0.13 milliseconds after request. These are OS-cache-dependent metadata results, not a controlled cold benchmark, real-home speed promise, or freed-byte measurement.

Sanitizers and object/resource fixtures are useful evidence for specific bugs. They do not prove the whole app is leak-free. Long Instruments allocation/footprint recordings, full window/sleep/wake flows, 1M entries, slow/network volumes, and real Trash/restore integration remain unverified. See AUDIT_RESOLUTION.md for residual policy and filesystem race limits.

## Original design refinement and AI storage, 2026-10-11

The original compact rail, hidden title bar, centered cleanup hero, amber pills, subtle background glow and rounded panels are restored. Shared headers, readable light-mode labels and split inspectors carry that style through all seven sections, onboarding and removal sheets. Compact navigation is the default; Settings can show navigation labels. The welcome action stays visible while longer permission guidance scrolls.

| Check | Observed result |
|---|---|
| Final core suite | 39 total tests in 13 suites, 38 active plus one skipped optional benchmark, passed in 6.915 seconds. |
| Thread Sanitizer | Same suite passed in 6.707 seconds; no race report in captured output. |
| Address Sanitizer | Same suite passed in 6.736 seconds; no memory-error report in captured output. |
| AI policy | Fixed cache leaves vs lookalikes/parents, case variants, blocked/empty activity probes, protected/partial selections, redirected discovery and shared scanner rules pass. Fresh activity at execution prevents the injected Trash mover from running. |
| Worktree integration | A disposable real Git repo and locked working copy report untracked changes while keeping contents and registrations intact. NUL-delimited paths preserve spaces/newlines. |
| Native UI | 52 captures: 13 screens/states, light and dark, 960×640 and 1200×720. Visible control text verified with Vision at the minimum light size. An actual NSEvent click on Select Safe changes the model; AI selections and protected-session controls retain their policy. Screens cover start/results, applications, populated process metrics/table, maintenance, settings, onboarding and both removal sheets. |
| Fixture isolation | UI runner suppresses live app enumeration, status sampling and history reads. Fixtures contain demonstration paths only. Capture targets only the runner's windows; no cleanup action executes. |
| Builds | Final Debug and universal Release succeed with signing disabled. lipo reports x86_64 and arm64. |
| Memory follow-up | Current 100K-entry sizing probe visited all entries in 7.588 seconds, peak RSS 34.39 MiB and footprint 16.25 MiB; 160 MiB RSS budget passed. No traversal implementation changed in the UI refinement. |
| HTML | AI policy discussion checked at desktop/mobile widths in light/dark, no horizontal overflow or console errors; local-note download exercised. |

Reproduce with `swift test --scratch-path /tmp/husk-ai-tests`, adding `--sanitize=thread` or `--sanitize=address` with separate scratch directories. Run `scripts/ui-smoke.sh` from the repo root after a Debug build; `HUSK_UI_ASSETS` can point to the built Assets.car. It needs local Screen Recording access. Captures are generated outside the repository. The fixture host uses fixed window sizes; Vision runs off the main actor using supported CPU compute stages, and transient ScreenCaptureKit stream-start errors have two bounded retries. Native controls are rendered in their active state.

These captures verify rendering and one native selection action. They do not establish a full VoiceOver/keyboard walkthrough, real-home cleanup, compatibility with every supported OS, or a whole-app leak assessment. Sessions, worktrees, models and installed tools remain inspection-only. Grok has no verified standalone cache rule. Owner-specific retention and version pruning are listed in AI_STORAGE_DISCUSSION.html. No signing, notarization, push or publication was performed.
