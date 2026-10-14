# Roadmap

The entire Husk app is MIT licensed. Development continues on `main`; there is no separate proprietary edition or paid feature gate. These priorities describe proposed work, not delivery dates.

## Public beta gates

The code and repository preparation can be reviewed locally. Before distributing a public binary:

- Run the configured GitHub workflow and enable branch protection and private vulnerability reporting after publication.
- Validate macOS 14 and Intel runtime behavior, or narrow the stated support matrix based on evidence.
- Test a fresh user account with Full Disk Access denied and granted, external and case-sensitive volumes, and real Finder Trash/Put Back with disposable data.
- Complete keyboard and VoiceOver walkthroughs and longer GUI memory/resource profiling across window close, sleep, wake, and repeated scans.
- Sign with Developer ID, notarize, test Gatekeeper on a clean machine, and publish artifacts tied to a source revision and checksum.

See [the release process](RELEASING.md) and [current verification](VERIFICATION.md). The owner will publish the repository separately; local commits do not change repository visibility.

## Next useful improvements

1. Add cache rules only where exact paths, regeneration behavior, and active-use checks are documented. A missing rule is preferable to deleting durable data.
2. Improve app ownership evidence for shared installations and sandbox containers without relying on fuzzy display-name matches.
3. Measure real scan bottlenecks on large and slow filesystems before introducing more concurrency or caching.
4. Add an opt-in diagnostic export that redacts paths and includes coverage and cancellation timings. It must remain local unless the user shares it.
5. Consider a read-only port view and small metric history after lifecycle and energy costs are measured.

## AI maintenance requiring design work

Caches from supported tools can be reviewed now. Sessions, models, working copies, and installed versions remain protected. New mutation support requires:

| Proposed operation | Evidence required before implementation |
|---|---|
| Session retention | Tool-specific database/index consistency, active sessions, export/restore, and explicit user retention settings |
| Worktree removal | Git-managed removal, dirty/ignored/nested content checks, activity detection, and fresh registrations |
| Installed-version pruning | Active executable resolution, updater locks, references, and a retained rollback version |
| Model removal | Manifest references, active loaders, shared blobs, and clear re-download costs |

See [AI storage policy](AI_STORAGE.md). No automatic or permanent deletion is planned. A future MCP interface needs its own security design; it is not implemented.

## Inspiration and licensing

Mole informed exact-path review, exclusions, developer caches, and maintenance workflows. Husk implements these independently in Swift. Reusing GPL code would require a separate licensing decision and cannot be treated as an MIT contribution. The AI storage guide retains primary-source links and the reviewed Mole revision.
