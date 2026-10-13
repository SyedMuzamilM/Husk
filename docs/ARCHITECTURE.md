# Architecture

Husk uses Swift 6 and SwiftUI on macOS 14 or later. Foundation, AppKit, and Darwin provide filesystem and process integration. TourKit is a reviewed local Swift package. There is no Rust component, database server, remote API, privileged helper, or paid feature gate.

## Repository map

| Location | Responsibility |
|---|---|
| `Husk/Husk/Models` | Immutable measurements, removal plans, file/process identity, and display values |
| `Husk/Husk/Services` | Scanning, path policy, task ownership, removal, process supervision, and local history |
| `Husk/Husk/Views` | Native screens and reusable controls |
| `Husk/Husk/Theme` | Semantic colors, dimensions, runtime fixture detection, and navigation |
| `Husk/Husk/ContentView.swift` | App navigation, appearance, onboarding, and window-level cancellation |
| `Husk/Tests/HuskCoreTests` | Disposable filesystem, process, and view-model regressions |
| `Vendor/TourKit` | Pinned onboarding dependency, license, and documented local patches |
| `scripts` | Verification, fixture UI rendering, memory profiles, and local release tooling |

The Xcode project builds the app and bundles assets and licenses. `Husk/Package.swift` builds the same model/service source for tests, excluding the app entry point, views, and resources. Do not create a separate copy of a service for testing.

## State and task lifetime

Each feature has a main-actor observable model. Models set loading state before scheduling work, own cancellable tasks, and reject obsolete results using a generation identifier. Weak captures must remain weak across long awaits. Promoting a model to a strong reference before awaiting an operation prevents deinitialization from cancelling it.

`ContentView` stops scans, detail loading, worktree inspection, and metrics when its window disappears or onboarding is replayed. Status sampling also stops when its section loses focus. A confirmed removal reports its outcome even if the window closes; cancellation must not hide a move that already happened. Storage Map does not launch an automatic rescan after its owner has cancelled background work.

Cleanup caches sorted/filtered rows and selection totals when their inputs change. Views read these values instead of flattening and sorting the scan on every redraw. Tests inject suspended loads to verify stale-result rejection and model release without scanning the real home directory.

## Filesystem work and measurements

`BlockingIO` runs synchronous filesystem operations on an operation queue with four workers. Scanners bound their fan-out and progress updates. Cancellation is cooperative; a kernel call can outlive a deadline.

`DirectorySizer` is the shared allocated-size implementation. Traversal streams entries, scopes temporary Foundation objects to each iteration, tracks hardlinks, and reports complete, partial, or unavailable coverage. Listings retain the largest K rows with shared entry/time budgets. The parent aggregate counts each observed hardlink once, while individual child sizes can overlap. APFS clones and snapshots mean estimates cannot promise freed bytes.

`CleanTargetCatalog` defines fixed cleanup locations. `CleanScanner` combines them with bounded cache/log discovery and optional project inspection. It resolves each candidate once and removes overlapping parents by walking ancestors. `AIStorageCatalog` owns fixed AI cache leaves and protected durable state. `ProjectArtifactService` and `GitWorktreeService` inspect only; they cannot delete projects or worktrees.

## Removal boundary

Screens build `RemovalCandidate` values. `RemovalService` prepares an immutable five-minute `RemovalPlan`, then executes only that reviewed plan through a process-wide actor gate. `PathSafety`, exclusions, ownership, file identity, and known running-app checks apply at preparation and execution. AI caches require fresh activity evidence. `TrashService` reports destinations, skips, cancellation, and individual failures. Tests inject its mover.

Husk uses Finder Trash through Foundation. The path API retains a same-user race after final validation. Root metadata does not detect every edit inside a directory. Trash is not a backup, and moving an item there normally does not free its disk blocks. These limits are part of the user-facing safety contract.

`OperationJournal` optionally records up to 100 operations for 30 days in the user's Application Support directory. Settings can disable or clear history. There is no telemetry. Paths in local history should be redacted before sharing.

## Processes and permissions

`ProcessRunner` executes fixed commands with bounded output, concurrent stdout/stderr draining, deadlines, cancellation, and direct-child reaping. It does not accept arbitrary shell plugins. `SystemMetricsService` gathers native metrics and releases acquired Mach rights. Quit requests revalidate PID identity and ownership; an OS request does not guarantee exit.

`PermissionService` uses a readability probe as an indication of Full Disk Access, not an access guarantee. Individual scans report coverage failures. UI fixtures and Xcode previews bypass protected-home probes.

## Dependencies and changes

Keep TourKit's complete notice and document local patches when updating its snapshot. CI actions are pinned by commit and updated through reviewed pull requests. New dependencies need a purpose, license/provenance review, and a check for hidden networking, runtime code loading, or broader permissions. See [contributing](../CONTRIBUTING.md) and [security](../SECURITY.md).
