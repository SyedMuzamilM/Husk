# Safety policy

Husk shows exact paths and risks before moving user-selected items to Trash. A feature that cannot meet this policy stays inspection-only. The app runs unprivileged and unsandboxed; its checks are not isolation from malicious software running as the same user.

## Selection and review

| Label | Meaning | Selection |
|---|---|---|
| Safe | A documented regenerable cache with low expected loss | Eligible for the explicit Select Safe action |
| Review | Removal may reset state, remove diagnostics, or require downloads | User selects it |
| Caution | May contain personal or hard-to-replace data | User selects and acknowledges the risk in review |
| Protected | Credentials, system data, excluded storage, or unverified removal policy | Inspection only or omitted entirely |

Age, size, and a directory name never establish disposability. AI cache leaves require complete measurements and activity checks; AI sessions, worktrees, installed versions, and models remain protected. Project cache discovery is opt-in and inspection-only.

## Filesystem boundary

Block protected system paths, home roots, credentials, cloud storage, other users' files, unsafe symlink components, exclusions, and ancestors containing protected or excluded data. Exact ownership and path evidence are required for app-related files. Shared containers and fuzzy display-name matches do not qualify.

The shared removal service prepares an immutable plan with identities and a five-minute expiry. It serializes execution, rejects replay, and rechecks policy, identity, ownership, exclusions, and known active owners before each move. Unknown ownership is not evidence of safety. Confirmation always applies to the reviewed snapshot, not a changing selection.

Use Foundation's Trash API. No permanent deletion, automatic Trash emptying, arbitrary-shell cleanup rules, or privileged cleanup is allowed. Report each destination, skip, failure, cancellation, and history-write error. Do not describe a partial operation as fully successful.

Foundation's path-based move has a residual race after validation. Folder-root metadata can miss interior edits. These limits must remain documented rather than hidden behind claims of absolute safety. Restoration uses Finder's Put Back when available; it is not guaranteed recovery or a substitute for backups.

## Measurement and process controls

Allocated sizes are estimates. Shared APFS blocks, snapshots, hardlinks, and Trash retention mean selected bytes are not promised freed bytes. Never count purgeable capacity or undownloaded cloud placeholders as junk. Partial or unavailable measurements must remain visible.

Scans and subprocesses need bounded work, output limits, cancellation, and an explicit owner. Long-running work must not retain a closed view model. Process quit requests revalidate identity and user ownership. Force Quit requires separate confirmation; a sent request does not prove that a process exited.

## Data and communication

Keep file lists, metrics, and optional operation history local. Do not add analytics, remote diagnostics, or update networking without documenting the behavior and reviewing it. External source/support links open only when the user follows them.

Do not claim that Husk removes malware, guarantees a speed increase, securely erases data, or is leak-free. Performance claims need the measured workload, toolchain, and limits. A passing fixture suite is evidence for those cases, not a security certification.

Report suspected wrong-file removal privately to [muzamil@mzml.dev](mailto:muzamil@mzml.dev). Investigate with disposable data, repair the policy at its shared boundary, add a regression, and document affected versions before disclosure. See [security](../SECURITY.md) and [rule requirements](RULES.md).
