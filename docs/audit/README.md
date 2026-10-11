# Audit verification fixtures

These historical probes target the pre-fix revision `98c992f`. To reproduce the original observations, use a separate checkout of that revision and run `python3 docs/audit/run.py` from its repository root on macOS with Xcode. They are not compatible with the repaired removal API.

For current regression verification, run `scripts/verify.sh` or `cd Husk && swift test`. See `docs/VERIFICATION.md`.

The runner compiles current app services in a temporary directory. It creates
temporary folders and synthetic data, probes path guards without deleting their
targets, and calls Trash only for a nonexistent path. It also exercises pure
uninstall matching, treemap identity, target overlap, Mach rights, and Status
object lifetime. The metrics probe has a five-second watchdog.

For matching, the runner exposes private helper methods in a temporary source
copy. For Status lifetime, it uses the exact production loop with an immediate
stub metrics dependency, so subprocess behavior cannot obscure object retention.
The separate metrics probe calls the real production service.

These are audit observations, not a permanent regression suite. Several printed
`true` values demonstrate bugs in the audited revision. Fixture source cleanup
uses `removeItem` only within the created temporary root. The app's cleanup code
continues to use Trash.

`observed-results.txt` records the 2026-10-11 run. Target overlap and `ps` output
size depend on installed tools and the host's current processes.

Build checks used:

```sh
xcodebuild -project Husk/Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath /tmp/husk-audit-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Husk/Husk.xcodeproj -scheme Husk -configuration Release \
  -derivedDataPath /tmp/husk-audit-release CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Husk/Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath /tmp/husk-audit-swift6 CODE_SIGNING_ALLOWED=NO \
  SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete build
```

Debug and Release succeeded on Xcode 27.0 beta / Swift 6.4. The Swift 6-mode
experiment failed on formatter sendability and imported page-size global access.

Additional observed output:

```text
ps output bytes on this host: 185036
wait-before-read blocked after 3s on actual ps output
METRICS production sample starting
production metrics probe timed out after 5s; watchdog stopped fixture process
```

A 20-second Leaks-template launch recording was also attempted. Its exported
table of contents did not expose allocation/leak measurements and listed a
different app-build path than the requested Release binary. It is inconclusive
and is not evidence of a leak-free app. Repeated, controlled Instruments runs
against the intended signed build are still required.
