# Husk repair plan

This plan addresses the follow-up audit of commit `2da07e8` and the current working tree. Earlier findings and their repairs remain recorded in `PROJECT_AUDIT_2026-10-11.md` and `AUDIT_RESOLUTION.md`. The scope is dependable storage review and a reproducible direct-download release with the current feature set.

Local repairs and current-app verification have completed. See `REPAIR_VERIFICATION_2026-10-12.md` for observed results and reproduction commands. Public-release gates below remain open.

## 1. Bind release artifacts to committed source

Build from a fresh Git archive of a clean committed revision. Reject tracked edits, staged edits, untracked files, a missing committed project license, and submodules whose contents cannot be archived. Recheck the original revision before signing and after packaging. Local ignored files must never enter the source archive. Verification and both architecture builds run against that archive with build output elsewhere.

Implemented in `scripts/prepare-release-source.sh`, `scripts/release.sh`, and `scripts/verify.sh`. Disposable Git fixtures exercise the actual release entry point before any signing or network call. A committed vendor directory and its license must survive archiving. Source paths with spaces must work.

Completion requires the regression checks to pass and a real signed release to be produced from a licensed, committed revision. The local source fix does not complete the signing requirement.

## 2. Bound Storage Map work and retained rows

Stream immediate directory entries. Measure each subtree once and accumulate the parent from the same observed files. Keep only the largest requested rows while counting hardlinks once for the parent. Hidden items contribute to the total even when their rows are hidden. Stop discovery and traversal when the global entry or time budget is reached. Display partial coverage and lower-bound item counts instead of implying the whole directory was measured.

Implemented at the existing `DirectorySizer.listing` interface. The default budgets are one million visited entries and 60 seconds. At most the requested number of display rows are retained. File identity accounting is still proportional to visited files, up to the entry budget. Blocking filesystem calls can exceed a cooperative time budget.

Completion requires regressions for largest entries, deterministic equal-size ordering, hidden files, packages, cross-subtree hardlinks, protected data, nested budgets, and cancellation. Measure the full listing on the same disposable fixture before and after the repair; the sizing-only benchmark does not establish listing performance.

## 3. State and verify the filesystem security model

Preserve the existing direct-distribution design: an unprivileged app with Hardened Runtime, explicit permission guidance, no network requests, declarative cleanup rules, visible confirmation, and Finder Trash. App Sandbox is not enabled in the current product. Choosing a sandboxed edition would require a separate scope decision about user-selected folders and filesystem access.

Keep identity, ownership, protected-path, exclusion, running-owner, expiry, and serialized-operation checks immediately before each move. An edit inside a selected directory can leave its root identity unchanged. A same-user process can also redirect a path between the last check and Foundation's path-based move. Neither notarization nor another path check makes the move atomic. The current threat model does not isolate Husk from malicious software running as the same user.

Completion for this product model requires passing service regressions and a documented, disposable-volume Finder Trash/Put Back exercise. Keep general folder removals behind Caution acknowledgement. Do not describe these operations as race-free or guaranteed reversible. If isolation from same-user software becomes a requirement, research a new mutation mechanism before claiming that requirement is met.

## 4. Verify the current UI and dependency snapshot

The working tree adds a local TourKit package, artwork, and a split-view sizing helper. Preserve those changes. Verify that the package, its retained MIT license, the app's license notice, and the new artwork are present in a fresh checkout once committed.

Build Debug and universal Release. Run the core fixtures and native UI smoke runner against the current views, including scan-to-results with no selection, light/dark appearance, minimum-size windows, onboarding transitions, and removal sheets. Captures and OCR checks do not establish keyboard or VoiceOver correctness. Those interactions need a separate walkthrough on the release build.

## 5. Close release prerequisites

These gates need decisions or environments not supplied by a local code change:

| Gate | Required evidence | Dependency |
|---|---|---|
| Project license | Owner-selected license and copyright attribution committed as LICENSE | Copyright ownership confirmed |
| Source and asset rights | Review of app code, brand/design exports, new artwork, and vendor notices | Provenance confirmed by owner |
| Private security reporting | Repository-specific reporting channel enabled and published | Maintainer account access |
| Supported platforms | Declared OS/hardware matrix; fresh-account runs with and without Full Disk Access | Test environments available |
| Compatibility | Runtime checks on the minimum supported macOS and Intel/Apple Silicon targets | Supported platforms declared |
| Native mutation | Trash and Finder restoration exercise on disposable local/external volumes | Release build and fixtures |
| Accessibility | Keyboard, VoiceOver, contrast, Reduce Motion, and scaled-display walkthrough | Current UI build |
| Long-run performance | Scan/cancel/rescan, sleep/wake, window close, and idle recovery resource measurements | Current UI build |
| Distribution | Developer ID signing, notarization, stapling, Gatekeeper assessment, source revision, checksum, and rollback artifact | All preceding release gates passed |

Do not expand cleanup into project dependencies, sessions, worktrees, models, version stores, or privileged maintenance while these gates remain open. Those are future features with their own ownership and regeneration requirements.

## Work order

Finish the release-source and listing regressions first. Verify the current UI and document the results next. In parallel with that verification, the owner can settle licensing, provenance, the support matrix, and the reporting channel. Perform compatibility, accessibility, disposable-volume mutation, and long-run resource checks against the resulting release candidate. Sign and notarize only after those gates pass.

The next engineering session can use each numbered repair as an independently verifiable task. Signing depends on the completed source fix, verified candidate, and owner release decisions. Current tests and builds can proceed while those decisions are pending.
