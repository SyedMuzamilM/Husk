# Mac cleaner benchmarks and ideas for Husk

Reviewed on 2026-10-11. This is a review of official websites, documentation, repository READMEs, license files, and published product screenshots. It is not hands-on testing of competitor binaries or an independent security audit of them. Vendor statements describe the advertised behavior; they do not establish measured performance, absence of vulnerabilities, or absence of leaks.

Husk should compete on safe, explainable storage recovery for developers. Its current Clean, Analyze, Apps, Status, Optimize, and Settings structure covers much of Mole's core scope. The useful next step is to make those workflows reliable and reviewable before adding more tools.

## Corrections to the existing research

The existing `docs/research.md` contains claims that should not drive implementation or public marketing without verification.

- Mole's free CLI and native Mac app are distinct distributions. `brew install mole` installs the CLI. The current CLI LICENSE is GPLv3. The native app is a separate commercial download; a public CLI repository does not establish that the native app is open source. [Mole README](https://github.com/tw93/Mole), [CLI LICENSE](https://github.com/tw93/Mole/blob/main/LICENSE), [Mac documentation](https://mole.fit/docs).
- Mole is not uniformly Trash-only. Its Mac documentation says caches are permanently deleted by default, with a Trash preference. Local snapshot removal destroys those local restore points. The CLI README says `mo clean` empties Trash by default unless protected. [Mac documentation](https://mole.fit/docs), [CLI safety and clean sections](https://github.com/tw93/Mole#safety).
- Pearcleaner is source-available under Apache 2.0 plus Commons Clause. Its license restricts selling the software. Treating it as an unrestricted open-source dependency would be a mistake. Its README currently says active development, issue responses, PR review, and releases are on hold indefinitely. [README](https://github.com/alienator88/Pearcleaner), [license](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md).
- Burrow now describes its own bundled `burrow-engine`, licensed FSL-1.1-ALv2. Its MIT app repository does not make the entire distribution MIT. The README no longer describes a pinned bundled Mole CLI. Some older text within that README still uses earlier licensing language, so use its current Attribution section and bundled notices. [Burrow README](https://github.com/caezium/burrow#attribution--license).
- PureMac explicitly documents permanent removal in several workflows, including category cleanup, scheduled auto-clean, administrator removal, and snapshot deletion. It is not strictly Trash-only. [PureMac deletion contract](https://github.com/momenbasel/PureMac#our-promise).
- Do not repeat broad claims that other cleaners have high telemetry, cause resource bloat, provide fake malware scanning, or guarantee speed improvements. Those require evidence about the specific product and version. Competitor-authored comparison tables are not evidence about another vendor.
- Do not present SwiftUI or Rust as a guarantee of low memory use or faster scanning. Benchmark Husk's actual workload and implementation.

## Verified comparison

| Product | Officially documented capabilities | Relevant benchmark for Husk | Sources |
| --- | --- | --- | --- |
| Mole native Mac app | Cleanup, app uninstall and updates, startup items, maintenance, whole-disk treemap, live CPU/memory/GPU/disk/network/thermal metrics, menu bar tools. Site advertises macOS 14+, $19 one-time, two Macs, and 14-day refunds. | Clear review before action; app data separated by risk; protected paths; actual skip reasons; folder navigation; efficient monitoring. | [Site](https://mole.fit/), [docs](https://mole.fit/docs), [releases](https://mole.fit/releases) |
| Mole CLI | `clean`, `uninstall`, `optimize`, `analyze`, `status`, developer `purge`, installer discovery, dry runs, path protections, whitelist, local operation log and history. README lists macOS 12+, Intel and Apple Silicon. GPLv3 license. | A documented safety model, inspectable dry-run output, operation history, ownership and shared-data checks. | [README](https://github.com/tw93/Mole), [LICENSE](https://github.com/tw93/Mole/blob/main/LICENSE), [SECURITY_AUDIT](https://github.com/tw93/Mole/blob/main/SECURITY_AUDIT.md) |
| AppCleaner | Drag an app into the window, discover related files, review and delete them. Download page lists versions for different macOS releases. | A short, comprehensible uninstall flow remains valuable. Husk does not need a large dashboard to make uninstalling useful. | [Official site](https://freemacsoft.net/appcleaner/) |
| Pearcleaner | App and orphan removal, developer environment manager, file search, Homebrew/package/plugin/service management, app updates, Finder extension, include/exclude directories and adjustable search sensitivity. Requires Full Disk Access and a helper for system-folder actions. | Better app discovery and per-file review; explicit exclusions; explain matching confidence and shared ownership. Avoid copying source without checking Commons Clause obligations. | [README](https://github.com/alienator88/Pearcleaner), [license](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md) |
| DaisyDisk | Interactive disk visualization, local/external/network/cloud storage, Quick Look preview, administrator scanning, protected system files, allocated-space accounting with hardlink and clone handling. | Accurate physical-space accounting and drill-down navigation matter more than a large "junk" total. Accessibility and a list alternative to the map matter. | [Official site](https://daisydiskapp.com/), [hard links](https://daisydiskapp.com/guide/hard-links), [safety](https://daisydiskapp.com/specs/safe) |
| OnyX | System-file verification, cleanup, maintenance, application uninstall, parameter changes, database and index rebuilding. Vendor warns that each major macOS version needs its matching OnyX build. | Every maintenance command needs an OS support matrix, a specific purpose, and a reason to run. A command's existence does not make it safe or useful on every OS. | [Official site](https://www.titanium-software.fr/en/onyx.html) |
| Burrow | Native cleanup/uninstall/disk mapping/status, developer purge, duplicate finding, local metric history and consent-gated MCP tools. README documents opt-out usage and diagnostic telemetry, signed/notarized releases, and separately licensed engine binaries. | Local history, an operation journal, signed releases, and explicit agent consent are useful later. An MCP server introduces a new access boundary that must be audited. | [README](https://github.com/caezium/burrow), [security](https://github.com/caezium/burrow/blob/main/SECURITY.md), [telemetry](https://github.com/caezium/burrow/blob/main/TELEMETRY.md), [notices](https://github.com/caezium/burrow/blob/main/NOTICE) |
| PureMac | MIT app source, app/orphan cleanup, folder storage explorer, exact duplicate detection, photo similarity review, configuration checks, Homebrew updates, optional scheduling and menu bar metrics. Documents SHA-256 duplicate matching with a protected retained copy and action-time rechecks. | Neutral storage facts, clear irreversible actions, exclusions, skipped-item reporting, hardlink-aware sizing, visibility-driven sampling. | [README](https://github.com/momenbasel/PureMac), [license](https://github.com/momenbasel/PureMac/blob/main/LICENSE) |
| CleanMyMac | Vendor advertises cleanup, app uninstall and updates, duplicates/similar photos, large files, cloud storage, malware tools, and notarization. | A broad suite is a useful scope comparison, but Husk should establish safe cleanup and uninstall before attempting antivirus or cloud integrations. | [Official product page](https://macpaw.com/cleanmymac) |

AppCleaner privacy behavior was not established by its product page. This report does not label it telemetry-free. PureMac's no-telemetry statement and Burrow's telemetry description are their authors' statements, not observations from network instrumentation.

## Mole native app in detail

The release page currently distinguishes v1.16.0 Preview, build 317, from stable v1.15.0 dated 2026-09-26. Preview-only behavior should not be described as shipped stable functionality. [Release page](https://mole.fit/releases).

### What the published interface does well

The official screenshots use five labeled top-level tabs. Clean has one strong primary action, "Review results", after scanning. Analyze places a sorted folder list alongside the treemap and uses a breadcrumb above it. Status combines compact metric cards, recent graphs, and a process table. Each section has a distinct theme. These observations are from marketing screenshots, not an interaction test. [Clean screenshot](https://mole.fit/img/en/clean.jpg), [Analyze screenshot](https://mole.fit/img/en/analyze.jpg), [Status screenshot](https://mole.fit/img/en/status.jpg).

Husk can adopt the clarity without copying the planets or artwork. Its 64-point icon rail already has accessibility labels and tooltips, but a visible text-label option would make six sections easier to discover. Keep Husk's identity and reserve most of the window for reviewing files. A large decorative hero is useful before a scan, then should give way to actionable results.

### Safety practices worth adapting

- The Preview Clean workflow separates backups, local iCloud files, virtual machines, and models into "Manage Separately", outside bulk cleanup totals. That is a useful model for data that belongs to another tool. [Docs, Clean](https://mole.fit/docs).
- AI cleanup separates caches/old versions, sessions/worktrees, and idle tools/maintenance. Session listing requires a retention choice, in-use files cannot be selected, and each row is checked again immediately before action. The docs explicitly protect memories, plans, and skills. [Docs, AI Cleanup & Care](https://mole.fit/docs).
- Codex session cleanup uses Codex's own command after making a recovery copy; Homebrew-owned tools use Homebrew, and supported Ollama models use Ollama's command. This supports preserving tool metadata rather than deleting arbitrary internal directories. Those integrations still need Husk-specific validation. [Docs](https://mole.fit/docs).
- Uninstall preserves data shared by other installed applications. It shows sizes and lets users review related files before removal. The release notes explicitly keep chat histories, virtual machines, and clipboard histories unchecked by default. [Docs, Software](https://mole.fit/docs), [releases](https://mole.fit/releases).
- Analyze protects system folders as view-only and confirms Trash operations. [Site, Analyze](https://mole.fit/), [docs](https://mole.fit/docs).
- Maintenance reports applied, skipped, and unavailable tasks. The docs say DNS and network resets are outside the default maintenance set. [Docs, Optimize](https://mole.fit/docs).
- A local operation log and read-only Doctor report make failures diagnosable. Logs containing file paths need restricted permissions, retention limits, and redaction before users share them. [Docs, Doctor and safety](https://mole.fit/docs).

Husk has a useful opportunity to make its default more conservative than Mole's documented permanent cache removal. Make every supported file-removal flow use Trash by default, then verify that contract. Moving files to Trash normally does not immediately release their disk allocation. Report "moved to Trash" separately from verified changes in free disk space.

### Performance ideas grounded in the release notes

The Preview release describes reusing scan measurements, avoiding repeated scans, limiting completed size updates to at most once per second, preserving navigation state, ordering equal-sized items consistently, refreshing stale folders without a complete rescan, and reducing background work while hidden. These are specific ideas for Husk's disk scanner and UI, not measured proof that Mole is faster. [v1.16.0 Preview release notes](https://mole.fit/releases).

For Husk, implement a shared bounded size cache with identity and modification checks, coalesce progress events, retain the last complete result while rescanning, cancel stale tasks, and avoid emitting a full tree for every file. Establish wall-clock time, peak memory, main-thread responsiveness, and idle energy baselines before selecting a different language or adding parallel traversal.

### Privacy and distribution

Mole's policy says scanned names, contents, browsing history, passwords, and scan results are not uploaded, and its operation log stays local. It also describes network traffic for license activation/device lists, signed Sparkle updates, third-party app updates, and public-IP lookup in versions offering it. Its website uses Google Analytics; its Mac app does not include Google Analytics. The policy describes license/customer records stored for support. "Local scans" should not be shortened to "the entire app makes no network requests". [Privacy policy, updated September 2026](https://mole.fit/privacy).

Husk should document the same distinctions explicitly: scans and removal, release checks, optional support reports, and any future telemetry. A zero-telemetry claim should be backed by a dependency inventory and network observation of a release build. Signed downloads and a signed update feed provide more assurance than a source repository alone.

## Adopt, improve, or defer for Husk

These priorities combine the competitor evidence above with the current Husk code structure. They are implementation recommendations, not claims that a competitor lacks the capability.

| Area | Decision | Concrete work | Completion evidence |
| --- | --- | --- | --- |
| Clean classification | Improve first | Separate caches, generated build output, sessions, installed tools, model assets, and user settings. Never classify age alone as permission to remove. Keep unknown and user-created data unchecked. | Fixtures for each rule and false-positive cases; visible reason and risk per candidate. |
| Shared cleanup candidates | Improve first | Deduplicate normalized paths and handle parent/child selections, hardlinks, active files, and replacements between scan and action. Use one policy for every removal entry point. | Adversarial filesystem fixtures and no double-counted totals or duplicate Trash actions. |
| Cleanup review | Adopt and improve | Add owner/tool, original path, evidence, age, allocated bytes, and "why included"; distinguish regeneration cost from irrecoverable data. Show hidden selections and exclusions. | Users can see every selected item before confirmation; total derives from unique validated targets. |
| AI/developer cleanup | Improve first | Preserve memories, plans, skills, histories and models by default. Check active builds/processes. Use tool commands where required, with per-tool support versions. | Tests against temporary representative tool data; operations preserve metadata and active work. |
| Analyze accuracy | Improve first | Use allocated bytes, explicit partial results, skipped-path counts, mount boundaries, and hardlink handling. Avoid presenting approximate totals as exact reclaimable space. | Compare against known APFS fixtures and document clone/snapshot limits. |
| Analyze UI | Adopt | Linked sortable list and treemap, breadcrumb, keyboard navigation, Quick Look, Reveal in Finder and Copy Path. Keep system data inspectable and protected. | Accessibility review and equivalent actions available without the map. |
| Scanner efficiency | Improve | Cache validated sizes, bound concurrency and memory, throttle updates, use stable identifiers, cancel old runs, and pause unnecessary hidden work. | Published large-tree timing/memory/energy baselines with regression thresholds. |
| Apps | Improve first | Explain matching evidence; preserve shared vendor folders, settings and user documents by default; enumerate nested and duplicate app installations. | Uninstall fixtures for shared data and multiple app copies; no broad name-substring deletion. |
| App updates | Defer until safe core | Start with source detection and links to official updates. Later add signed/vendor-aware update workflows with rollback and clear unsupported states. | Verified source identity and signatures; interruption/replacement failure coverage. |
| Status | Improve | Add memory pressure and swap, real short trends, process grouping/icons, and truthful unknown states. Revalidate process identity before quit/force quit. | Activity Monitor comparison; tests for reused PIDs; sampling stops while hidden. |
| Menu bar | Adopt later | Optional disk/memory/CPU popover and low-space alerts, with an explicit sampling budget and off switch. | Idle CPU/wakeup/energy measurements; no duplicate pollers. |
| Optimize | Improve first | Explain the symptom, command, permissions, possible reset effects, applicability and skipped reason. Do not promise generic speed boosts or RAM reclamation. | Supported-OS matrix and failure/timeout results for each task. |
| Operation history | Adopt soon | A local journal of attempted actions, original and Trash paths, success/failure, policy version and timestamps. Limit retention and redact exports. | A failed batch remains explainable; recovery mappings persist across restart. |
| Settings | Improve | Protected paths/types, scan roots, appearance, accessibility, sampling preferences, privacy details, release channel and diagnostic export. | Exclusions affect every scanner and removal route. |
| Navigation and accessibility | Improve | Visible section labels or expandable rail, standard macOS menus/shortcuts, light/dark/system appearance, sufficient contrast, keyboard focus and Reduce Motion. | VoiceOver and keyboard-only completion of scan, review, uninstall and reveal. |
| Exact duplicate finder | Defer | Size then content hash, protect a retained copy, handle hardlinks, revalidate identity/content immediately before action, and skip cloud-only data. | Independent duplicate fixtures including identical bytes, links, mutated files and unreadable items. |
| Long metric history | Defer | Local bounded/downsampled storage, user-selected retention, clear measurement units and private export. | Storage/energy budgets, migration and pruning checks. History is not proof of a memory leak. |
| Ports view | Defer | Read-only local listening-port/process mapping; refresh on demand before adding process termination. | Accurate ownership and reused-PID checks; no permanent background shell polling. |
| MCP/agent access | Defer | Begin with opt-in read-only snapshots. Future changes require explicit per-action user consent, revalidation, a journal, and no arbitrary shell/path commands. | Authentication/access-boundary tests and independent security review. Loopback alone is not authorization. |
| Fan/battery/WiFi controls | Defer | Hardware-dependent privileged controls expand scope substantially. Require separate design, restore-on-exit/wake failure handling, and supported-device testing. | Safe recovery if the app crashes, helpers disconnect, or authorization is denied. |
| Antivirus/cloud connectors | Defer | Do not add weak malware claims or cloud deletion merely for feature parity. Each needs a separate threat model and operational support. | An actual supported detection/integration system and dedicated review. |

## Open-source choices informed by this comparison

Pick and publish a real license for Husk and audit every dependency and asset against it. Public source without a license does not grant redistribution rights. GPLv3 Mole code, Pearcleaner's Commons Clause code, and Burrow's FSL engine have different obligations; do not paste implementations into a permissively licensed app based on their public availability. PureMac's MIT source is a separate licensing situation, but attribution and notice requirements still apply.

Publish one official download location, signed and notarized binaries, checksums, reproducible build instructions, security reporting instructions, supported macOS/architecture lists, and a permission explanation. Pearcleaner's README warning about fake download sites and Mole's distribution warning demonstrate why users need an unambiguous official source. [Pearcleaner README](https://github.com/alienator88/Pearcleaner), [Mole README](https://github.com/tw93/Mole).

Accept contributor cleanup rules only with narrow path scope, documented ownership, an explanation of what regeneration loses or costs, and fixtures that prove what must remain untouched. A community-maintained rule catalog can become Husk's strongest feature if review quality stays high.

## Recommended implementation order

1. Repair classification, action-time path/identity validation, deduplication, size accounting, process identity checks, and task cancellation. Freeze deletion-rule expansion until these are tested.
2. Ship trustworthy review screens, visible labels, exclusions, partial-scan reporting, and a local operation/recovery journal. Establish actual memory and energy baselines.
3. Add signed distribution, supported-OS checks, contributor/security documentation, and CI that exercises destructive behavior only inside fixtures.
4. Add optional menu bar summaries, useful trends, and carefully scoped developer integrations.
5. Evaluate updates, duplicates, historical metrics, ports, and read-only MCP separately. Privileged hardware controls and antivirus are a much later decision.

No competitor evidence justifies rushing unattended cleanup into Husk. The most useful promise is that users can understand the candidate, decide what to remove, and recover a supported Trash operation.
