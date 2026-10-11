# Verification record, 2026-10-11

Application revision: `8139214`.

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
| Regression suite | 29 tests passed; one optional benchmark test skipped in the normal run. Swift Testing reports 30 total tests. Final run completed in 8.062 seconds. |
| Thread Sanitizer | Same fixture suite passed in 7.794 seconds; no ThreadSanitizer race report in captured output. |
| Address Sanitizer | Same fixture suite passed in 7.423 seconds; no AddressSanitizer memory error report in captured output. |
| Large stdout/stderr | 300 KiB stdout plus stderr drained without pipe deadlock; timeout/output cap/cancellation fixtures pass. |
| Resources | 10 production metrics samples show no host-right growth; 30 repeated commands show no file-descriptor growth after warm-up. Status model releases after owner release. |
| Removal | Injected moves verify mixed success/failure, cancellation, expiry, running owners, symlink swaps, identity changes, protected paths, exclusions, nested risks, serialization, and replay rejection. |
| Sizing | Largest hidden child survives top-K; package contents included; hardlinks counted once; protected/symlink roots denied; limits return partial. |
| Builds | Debug and Release succeed, signing disabled, Swift 6 mode. One unrelated Xcode metadata-extraction note for absent AppIntents dependency remains. |
| Release scripts | bash syntax check passes. Missing-license release gate rejects stub identity/profile labels before signing or network calls. No real signing/notarization performed. |
| App launch | Release app launches and creates an on-screen window. Window capture returned "could not create image from window". No visual, keyboard, or VoiceOver pass is claimed. |
| HTML discussion | Previewed at desktop and mobile widths; no horizontal overflow or console errors. Fields generate a local text draft only. |
| Git | Whitespace checks pass. Limited history scan examined 367 unique objects with no high-confidence key/token-pattern matches. No push or publication performed. |

Benchmark fixtures use newly created empty files. Both local traversals completed for 10K and 100K entries. 10K took 0.847/0.785 seconds; 100K took 8.001/8.195 seconds. Cancellation completed 1.19/0.13 milliseconds after request. These are OS-cache-dependent metadata results, not a controlled cold benchmark, real-home speed promise, or freed-byte measurement.

Sanitizers and object/resource fixtures are useful evidence for specific bugs. They do not prove the whole app is leak-free. Long Instruments allocation/footprint recordings, full window/sleep/wake flows, 1M entries, slow/network volumes, and real Trash/restore integration remain unverified. See AUDIT_RESOLUTION.md for residual policy and filesystem race limits.
