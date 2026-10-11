# Security policy

Husk is an unreleased experimental beta. No production version currently receives a support commitment. Security fixes should target the current main branch; release support dates must be published before the first public release.

## Reporting

Do not post sensitive paths, credentials, private file contents, or an exploitable destructive workflow in a public issue. Before publication, the maintainer must enable GitHub private vulnerability reporting and publish its repository-specific "Report a vulnerability" link. That channel is not verified or available through this checkout. Until configured, contact the repository owner through an existing private channel. No response-time promise is made yet.

A useful private report includes the source revision, macOS version, permission state, a disposable reproduction, expected/observed behavior, and affected policy boundary. Redact usernames and personal paths. Use fixture data rather than a real destructive example.

## Threat model and boundaries

The app runs unprivileged and unsandboxed for direct-distribution filesystem review. Hardened Runtime is configured; a local unsigned build is not a notarized artifact. The current app has no networking, shell plugin endpoint, telemetry, updater, or privileged helper.

The removal boundary rejects protected ancestors/descendants, nonabsolute paths, symlink components except macOS aliases, exclusions including excluded descendants, and other-user-owned items. A five-minute immutable plan deduplicates overlapping targets and records identity metadata. A process-wide actor serializes moves and rejects replay. Known app owners are checked before review and again before each item. Unknown owners are not inferred to be safe.

Residual limits include filesystem race windows in Foundation Trash, changes inside folders without a root metadata change, incomplete owner attribution, kernel/filesystem calls that can block beyond a cooperative deadline, and PID changes between final validation and an OS quit request. These require continued review and disposable-volume testing. A malicious same-user process is not isolated from Husk by this policy.

Community rules must remain declarative. Never add arbitrary shell execution, dynamic code loading, permanent deletion, credential cleanup, or privileged mutation to implement a rule. See the [rule criteria](docs/RULES.md).
