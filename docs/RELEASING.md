# Release preparation

Before a public release, the owner must choose an OSI license, verify all code/asset rights, enable private vulnerability reporting, and decide supported macOS/hardware versions. Apple Developer ID signing and notarization require the owner's membership and keychain credentials. No credentials should be entered into Git or chat.

`HUSK_SIGNING_IDENTITY`, `HUSK_TEAM_ID`, and `HUSK_NOTARY_PROFILE` are local identity/profile names, not private keys. Configure notarytool credentials in the local keychain using Apple's supported workflow. Run `scripts/release.sh` from a clean committed source revision after compatibility testing. It builds a universal app, signs with Hardened Runtime, submits to Apple's notarization service, staples, assesses, and writes a checksum/source-revision file. The script has been syntax checked, not executed with real signing credentials. It does not publish a GitHub release or install an updater.

Inspect the result and verify that the Developer ID team matches HUSK_TEAM_ID before distribution. Test on a fresh user account without FDA, with FDA, on both architectures, and on supported OS releases. Include real disposable-volume Trash and Finder restoration tests. Test external volumes, case-sensitive APFS, APFS clones/hardlinks, permissions, cloud placeholders, and app copies.

Profile scan/cancel/rescan, inspector switching, Analyze drill/back, Status start/stop, window close, sleep/wake, and idle recovery. Record live allocations, memory footprint, Mach rights, file descriptors, child processes, and cancellation latency. Passing builds and fixture tests do not establish a leak-free app.

Publish only versioned artifacts matching a source tag, checksum, minimum OS/toolchain, known limitations, and installation/rollback instructions. Keep the previous signed version available. An updater requires signed update metadata and its own security review.
