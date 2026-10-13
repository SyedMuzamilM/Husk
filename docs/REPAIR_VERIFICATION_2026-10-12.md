# Repair verification, 2026-10-12

This run verifies the release-source and directory-listing repairs described in `REPAIR_PLAN_2026-10-12.md` against the current working tree. It also checks the existing UI and onboarding edits. No source was committed or published by this repair work. Release credentials were not used, and no real user file was moved to Trash.

## Results

| Check | Result |
|---|---|
| Release-source regressions | Eight disposable Git-repository tests pass. They cover untracked files, tracked/staged edits, snapshot isolation from ignored local files, committed vendor/license inclusion, absent project license, changes during verification, export-ignore of LICENSE, and unsupported gitlinks. |
| Core tests | 44 total tests in 13 suites pass, including 43 active tests and one skipped optional benchmark. Final run took 5.628 seconds. |
| Thread Sanitizer | All 11 measurement/listing tests pass in 0.076 seconds with no ThreadSanitizer race report. Scope is these service fixtures. |
| Debug build | Succeeds with signing disabled. |
| Universal Release build | Succeeds with signing disabled; lipo reports x86_64 and arm64. |
| Vendor notice | Built Release Resources contains TourKit-LICENSE.txt. The release script now embeds the owner-selected project license and source revision before signing. Real signing has not run. |
| Native UI | 94 PNG captures pass. Checks include 21 states in light/dark at 960x640 and 1200x720, scan-to-results and rescan with no selection, scrolling, filtering, native Select Safe, tour forward/back/Return/skip/setup/completion, Reduce Motion, and removal sheets. |
| Script and whitespace checks | Bash syntax and Git whitespace checks pass. |

The available toolchain is Xcode 27.0 build 27A5218g and Swift 6.4 on an Apple Silicon development Mac. This does not validate Xcode 26.2 or the macOS 14 runtime minimum. The only app build warning was AppIntents metadata extraction being skipped because Husk does not use AppIntents.

## Full-listing performance

An optimized standalone probe compiled the actual production modules and listed the same disposable 10,000-sibling empty-file directory before and after the repair. These are development-host measurements with OS cache effects and background activity, not controlled cold-storage results or product-wide performance promises.

| Metric | Before | After |
|---|---:|---:|
| Listing elapsed time | 2.645 s | 1.490 s |
| Peak RSS | 64.17 MiB | 20.38 MiB |
| Rows retained | 100 | 100 |
| Omitted children | 9,900 | 9,900 |
| Coverage | Complete | Complete |

A separate 100,000-sibling fixture visited all 100,000 entries, retained 100 rows, and reported 99,900 omitted children with complete coverage in 7.361 seconds. Peak RSS was 27.55 MiB and peak physical footprint was 12.28 MiB. The 160 MiB service RSS budget passed. The first streaming implementation reduced memory but was slower; reducing repeated file metadata checks produced the final result above.

Reproduce the full-listing profile from the repository root:

```sh
HUSK_PROFILE_MODE=listing scripts/profile-sizing.sh
```

The normal sizing-only profile remains available with `scripts/profile-sizing.sh`. Both profiles create and remove only their own fixtures.

## Reproduction commands

From the repository root:

```sh
python3 scripts/test-release-source.py
HUSK_VERIFY_ROOT=/tmp/husk-repair-verification scripts/verify.sh
cd Husk
swift test --scratch-path /tmp/husk-repair-tsan --sanitize=thread --filter MeasurementTests
```

After the Debug build, from the repository root:

```sh
HUSK_UI_ASSETS=/tmp/husk-repair-verification/xcode/Build/Products/Debug/Husk.app/Contents/Resources/Assets.car \
  scripts/ui-smoke.sh /tmp/husk-repair-ui
```

The UI runner needs local Screen Recording access and captures its own fixture windows. Service removal tests inject the move operation. Signing/notarization, real Finder Trash restoration, minimum-OS runtime coverage, full VoiceOver/keyboard traversal, and long-run GUI resource profiling remain release gates.

## Primary sources checked

- [Apple App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) describes entitlement-based resource isolation and requires sandboxing for Mac App Store distribution. This supports treating a sandboxed edition as a separate product-scope decision.
- [Apple FileManager Trash API](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:)) takes a path URL and returns the actual Trash destination. The documented interface does not provide a file-descriptor or expected-identity conditional move.
- [GitHub macOS 15 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) currently lists Xcode 26.2 at the path configured in CI. Remote CI still needs an actual run; the inventory is not evidence that this repository's workflow has passed.
