# TourKit onboarding and result layout verification

Implemented 2026-10-12. Scope is the welcome flow and result viewport sizing. Other concurrent measurement and release-tool edits were left untouched.

## Confirmed layout regression

The native fixture runner reproduced the reported screenshot before the fix. It mounted Cleanup, moved through idle and scanning, then supplied 180 results with no selected inspector. The table displayed only its header and no rows. The AppKit split view used a 184.5pt intrinsic height, and the table scroll view had only 40.5pt, including its header.

A maximum-height frame on the split container alone did not fix the issue. Both panes needed to accept the available height. Cleanup, AI Storage and Applications now do so using HuskSplitView and explicit flexible pane heights. Empty inspectors fill their panel too. Storage Map and Status tables also explicitly fill the available height. Registered Git worktree details scroll inside the AI inspector rather than taking a second table's height above the inventory.

After the fix, the 960×640 window has a 287pt cleanup table viewport, and 1200×720 has 367pt. The runner verifies visible rows, at least 180pt of table viewport, scrolling to the last result, an empty search and a repeated scanning/results transition. It also mounts AI Storage, Applications, Storage Map and Status before supplying data, then checks visible rows and table height. No scan or cleanup of existing user data runs.

## Onboarding integration

Husk uses TourKit v1.0.0, upstream commit `0cac3a51069e105286635601e82117c195058ee9`, as a reviewed local Swift package. The MIT license is retained beside the source and bundled as TourKit-LICENSE.txt. No upstream sample code or images are bundled. Local patches provide amber button colors, Reduce Motion, spoken control labels, hidden/disabled first-page Back and Left Arrow navigation. See Vendor/TourKit/README.md.

The three slides cover welcome, reviewed Trash cleanup and protected AI storage. They lead to a separate optional disk-access setup step. Skip also leads to setup. Only Get started invokes the existing completion callback; granting permission never scans or cleans. Settings' existing Replay welcome action resets the completion flag and creates a new tour. Returning from setup starts the tour again.

Artwork is bundled and can be regenerated with `swift scripts/generate-tour-artwork.swift` from the repo root. It uses the existing Husk logo and system symbols. The tour card intentionally remains dark in either appearance; surrounding screens follow the app's appearance setting. No network client or telemetry was added.

## Checks performed

- Core suite in an isolated snapshot of these changes: 39 total tests in 13 suites, 38 active and one skipped optional benchmark, passed in 5.721 seconds. The snapshot excluded the other task's in-progress edits.
- Debug and universal Release builds pass with signing disabled. lipo reports x86_64 and arm64. TourKit-LICENSE.txt in the Release app matches the vendored MIT license byte for byte. The only Xcode warning is metadata extraction for the absent AppIntents dependency.
- Native captures cover 21 screens/states in light and dark at 960×640 and 1200×720, including no-selection results, AI sessions/worktree inspection, all three tour slides, permission setup and removal sheets. Visible controls are checked with Vision at the minimum light size.
- Ten data-loading transition captures cover five result pages at both sizes. An actual Select Safe click changes the model. Native tour tests exercise mouse Continue, Left Arrow Back, Return, final setup, Back to tour, Skip and Get started with Reduce Motion false and true. Completion occurs once, after setup, without requiring disk access.
- SwiftUI's system Reduce Motion preference is read-only. The tour defaults to it; fixtures use an explicit override to verify both paths without changing host preferences.
- Shell syntax, project plist and Git whitespace checks pass. No signing, notarization, push or publication performed.

## Reproduction

After a Debug build, run from the repository root:

```sh
HUSK_UI_ASSETS=/path/to/Husk.app/Contents/Resources/Assets.car scripts/ui-smoke.sh /tmp/husk-ui-snapshots
```

The runner uses the vendored TourKit source and requires local Screen Recording access. Set HUSK_UI_TRANSITIONS_ONLY=1 for the layout regression, or HUSK_UI_ONBOARDING_ONLY=1 for layout plus tour interaction checks. It never executes cleanup. Desktop-independent captures include fixture windows across Spaces. Transient macOS capture-service failures use bounded retries and remain failures if exhausted.

These checks do not establish a full VoiceOver walkthrough, fresh-user Full Disk Access permission behavior, minimum-OS compatibility or a whole-app leak assessment. Production measurement and cleanup services were not changed in this task.
