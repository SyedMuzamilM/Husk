# Husk

Husk is an experimental native macOS utility for reviewing storage, moving selected items to Trash, uninstalling apps, and observing system processes. It uses Swift 6, SwiftUI, Foundation, AppKit, and Darwin. Onboarding uses a reviewed local snapshot of [TourKit](https://github.com/rampatra/TourKit), licensed under MIT. There is no telemetry, privileged helper or network client.

Requires macOS 14 or later and Xcode 26.2 or later with Swift 6.2. Only the current development machine has been verified. This is not a signed public release or a completed security certification.

## Current capabilities

- Cleanup table with search, risk filters, an inspector, and explicit path review.
- Shared, serialized removal plans with expiry, file identity checks, exclusions, known running-app checks, and per-item outcomes.
- Disk analysis with folder picker, list and treemap views, hidden files, and complete/partial/unavailable allocated-size estimates.
- Nested app discovery and exact bundle-ID data associations. Shared group containers and fuzzy name matches are excluded; personal data requires acknowledgement.
- CPU, estimated memory, pressure/swap when available, actual volume free capacity, and process CPU/RSS. Quit requests revalidate process identity and user ownership.
- Quick Look troubleshooting, system/light/dark appearance, persistent exclusions, and optional local operation history.
- Apple-style TourKit welcome slideshow with Husk artwork, back/skip controls, keyboard navigation and Reduce Motion. Optional disk-access setup follows the tour; replay it from Settings. [Integration and layout verification](docs/ONBOARDING_AND_LAYOUT_VERIFICATION_2026-10-12.md).

Project cache discovery is opt-in and inspection-only. Bulk project/dependency removal, whole AI histories/models/VMs, automatic deletion, emptying Trash, MCP, Rust, SQLite, billing, and menu-bar monitoring are not implemented. Older product documents describe proposals, not shipped functionality.

## Build and test

From the repository root:

```sh
cd Husk
swift test
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath /tmp/husk-build CODE_SIGNING_ALLOWED=NO build
open /tmp/husk-build/Build/Products/Debug/Husk.app
```

Unsigned local builds may need macOS privacy permissions. Full Disk Access is optional for limited scans. The app deliberately excludes credentials and cloud locations even when broad read access is available. No administrator password is needed.

Husk keeps its original compact rail, warm amber actions and rounded panels, with system, light and dark appearance. AI Storage inventories recognized caches, sessions, working copies, models and installed tools. Only verified cache leaves can be selected for reviewed cleanup. Sessions, model weights, worktrees and version stores remain inspection-only. See [AI storage policy and sources](docs/AI_STORAGE.md) and the [remaining policy decisions](docs/AI_STORAGE_DISCUSSION.html).

Tests use disposable fixtures and inject the move operation; they never send existing user data to Trash. Build Release with the same command and `-configuration Release`. Run `scripts/verify.sh` for the full local verification sequence, including a universal Release build. Run `scripts/profile-sizing.sh` for an opt-in 100K-entry service memory check using disposable fixtures; its default RSS budget is 160 MiB. This profiles the sizing service, not the full GUI. After a Debug build, run `scripts/ui-smoke.sh` to capture fixture screens in light/dark mode at 960×640 and 1200×720. The local runner requires Screen Recording access, verifies visible control labels, tests scan-to-results table heights with no selection, clicks Select Safe and walks the tour with mouse/keyboard input. It never runs cleanup. Set `HUSK_UI_ASSETS` if Assets.car is outside the default `/tmp/husk-ui-build` location.

## Safety limits

Sizes estimate allocated bytes, not guaranteed freed space. APFS clones, snapshots, hardlinks, and purgeable storage complicate accounting. Moving to Trash usually does not release space until Trash is emptied. Child estimates can share blocks and need not sum to the independently measured parent.

Identity checks detect item replacement and root metadata changes, not every edit inside a selected folder. Foundation's path-based Trash API retains a small race between validation and moving. No path policy can prove arbitrary user data is disposable. Read the exact paths and risks before confirming. Restore using Finder's Put Back when available; Husk records destinations but does not automate restoration.

See [the original audit](docs/PROJECT_AUDIT_2026-10-11.md), [fix status](docs/AUDIT_RESOLUTION.md), [security policy](SECURITY.md), [privacy](docs/PRIVACY.md), and [contributing](CONTRIBUTING.md).

## Open-source status

The repository is being prepared for open-source publication. An OSI license and verified copyright ownership still need the owner's decision. No reuse license is granted yet. Do not describe the project as open source until LICENSE is added. Proposed pricing and Premium features in historical plans are undecided.

Competitor behavior informed the roadmap; no Mole code or assets were imported. [The verified comparison](docs/COMPETITOR_AUDIT_2026-10-11.md) distinguishes the GPLv3 CLI from the proprietary GUI.
