# Release preparation

Husk uses the [Husk Source-Available License](../LICENSE). This release procedure is for the copyright holder or a distributor with separate permission; the project license does not grant general redistribution rights. The repository owner has approved the original brand assets and designated muzamil@mzml.dev for private reports. Repository publication, GitHub settings, and signed distribution remain separate maintainer actions. Review [licensing and prior MIT rights](LICENSING.md) before publication.

## Source verification

Run `scripts/verify.sh` from the repository root. It checks bundled license consistency, pinned CI actions, release-source regressions, the Swift suite, Debug, and universal Release without credentials. Optional UI, sanitizer, and memory commands are in [current verification](VERIFICATION.md).

Release from a clean committed checkout. `scripts/prepare-release-source.sh` rejects staged edits, tracked edits, untracked files, a missing committed license, export rules that omit the license, and submodules whose contents would not be archived. Ignored local files never enter the Git archive. The release script verifies and builds that archive, then checks that the checkout has not changed before signing and before reporting success.

Use a fresh clone or worktree when your development checkout contains private notes or other untracked files. Do not delete someone else's files to satisfy the release gate. A Git archive is the source of the build, not a copy of the working directory.

## Before public distribution

- Run remote CI at the minimum supported toolchain. Local builds on a newer Xcode do not validate that minimum.
- Validate macOS 14 and Intel runtimes, or change the documented support matrix to match tested versions.
- Test a fresh account with Full Disk Access denied and granted, external and case-sensitive filesystems, APFS sharing, and disposable-file Trash/Put Back.
- Complete keyboard and VoiceOver traversal and longer GUI resource profiling across scan/cancel/rescan, inspector switching, window close, sleep, and wake.
- Review bundled assets and third-party notices. Enable private vulnerability reporting, secret scanning/push protection, and branch protection where available when making the repository public. Email remains the private fallback.

Builds and fixture tests do not establish a leak-free or race-free app. Known Foundation Trash and process-identity race limits remain in SECURITY.md.

## Sign and notarize locally

Apple Developer ID signing requires membership and a local keychain identity. Configure notarization credentials with Apple's supported keychain workflow. Do not enter secrets into Git or chat. These variables contain identity/profile names, not private keys:

```sh
export HUSK_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export HUSK_TEAM_ID='TEAMID'
export HUSK_NOTARY_PROFILE='your-keychain-profile'
./scripts/release.sh
```

The script builds a universal app, embeds the Husk license, TourKit's MIT notice, and source revision, signs with Hardened Runtime, verifies the signing team, submits to Apple, staples, assesses, and writes a versioned ZIP plus SHA256SUMS. It does not publish source, create a GitHub release, or install an updater. Real signing/notarization has not been verified without maintainer credentials.

Inspect the result and test Gatekeeper on a clean machine. Publish only artifacts matching a source tag, revision, checksum, minimum OS/toolchain, known limitations, and installation instructions. Keep the previous signed version available. An updater would require signed metadata and a separate security review.
