# Contributing to Husk

Husk uses the [Husk Source-Available License](LICENSE). You may read, build, and modify it privately. General redistribution of the source, binaries, and modified versions is restricted. The license expressly allows submitting patches and necessary excerpts to the official project. See the [licensing guide](docs/LICENSING.md) for prior MIT rights and GitHub's separate platform terms.

By intentionally submitting a contribution for inclusion, you license your original contribution under the same terms and grant Syed Muzamil the nonexclusive right to use, reproduce, modify, and distribute it as part of Husk under those terms. You retain copyright in your work. No separate CLA or mandatory commit sign-off is required. Only contribute material you have the right to license; preserve third-party notices.

## Set up

Use macOS 14 or later, Xcode 26.2 or later, and Swift 6.2 or later. The Xcode project builds the app; the Swift package runs service and view-model fixtures. From the repository root:

```sh
cd Husk
swift test
xcodebuild -project Husk.xcodeproj -scheme Husk -configuration Debug \
  -derivedDataPath /tmp/husk-build CODE_SIGNING_ALLOWED=NO build
open /tmp/husk-build/Build/Products/Debug/Husk.app
```

No Apple Developer account, personal signing team, API key, or downloaded Swift dependency is required. TourKit is vendored with its MIT notice. Full Disk Access is optional for limited scans.

## Make a change

Start from `main` and use a focused branch. Describe the concrete problem before proposing a large feature or new dependency. Native platform APIs are preferred when they meet the requirement. The [architecture guide](docs/ARCHITECTURE.md) explains the current modules and task ownership.

Keep Swift 6 concurrency checking enabled. Blocking filesystem operations belong in the bounded `BlockingIO` workers. UI state belongs on the main actor. Tasks need cancellation, stale-result checks, and an explicit owner. Never move synchronous filesystem work into a SwiftUI view body.

Changes to removal, ownership, sizing, cancellation, subprocess supervision, or resource lifetime need regression fixtures at the service boundary. Ordinary tests use disposable paths and injected Trash operations. Never scan or clean a contributor's real home directory as a test. Opt-in integration and performance checks must create and clean up only their own fixtures.

Each cleanup rule needs exact path evidence, supported tool versions, owner association, what can be lost, how the data is regenerated, active-use behavior, and protected/excluded/symlink fixtures. Unknown data starts as Review or inspection-only. Follow [the rule criteria](docs/RULES.md); community rules cannot execute shell commands.

## Verify

From the repository root, run `scripts/verify.sh`. It checks repository policy, release-source regressions, Swift tests, Debug, and universal Release without signing credentials. CI runs the same command. Optional native UI, sanitizer, integration, and performance commands are documented in [verification](docs/VERIFICATION.md).

For UI changes, check system/light/dark appearance, keyboard navigation, VoiceOver, Reduce Motion, resized windows, and review/result screens. The fixture runner can catch layout and button regressions; it does not replace a VoiceOver walkthrough.

## Submit

Submit a patch to the official repository, or open a pull request against `main` where repository access and the hosting platform's terms permit it. Include the problem, resulting behavior, checks run, and any remaining limits. The contribution permission does not permit publishing a separate build or a full source mirror. Keep commits focused and include screenshots for visual changes after redacting personal paths. If an API or behavior changes, update its documentation in the same pull request.

Do not commit credentials, signing teams, generated builds, local IDE state, private path logs, or personal screenshots. Use the repository's issue forms for ordinary bugs and feature proposals. Report vulnerabilities privately under [SECURITY.md](SECURITY.md). Participation follows the [code of conduct](CODE_OF_CONDUCT.md).

This is a volunteer-maintained project. A contribution may need revision or be declined if it expands data-loss risk, introduces ongoing support work, or lacks evidence for a cleanup rule.
