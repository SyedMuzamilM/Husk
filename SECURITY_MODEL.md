# Security model: Husk

Threat model used to prioritize security scan findings for this repository. It was written with the maintainer from the code and [SECURITY.md](SECURITY.md). Facts marked *(maintainer)* came from the maintainer; the rest is read from the code. Edit it as the system changes.

## Maintainer priorities *(maintainer)*
- **Assets:** all assets weigh the same; none is ranked above the others.
- **Attackers:** all count. None is ruled out.
- **Out of scope:** `docs/`, `examples/`, `bench/` and tests (`test/`, `tests/`, `Tests/`, `*.test.*`, `*_test*`). Findings located only in those paths are not worth fixing. Production code that a test exercises stays in scope.

## Components

| Component | Code | Trust boundary |
|---|---|---|
| **Husk** | `Husk/Husk/**` (Models, Services, Views), `Husk/Tests/**` | Local, unprivileged, unsandboxed macOS app; filesystem removal boundary |

## System, entry points, assets and attackers

Source: [`SECURITY.md`](SECURITY.md) (maintainer-written). Runs unprivileged, unsandboxed, Hardened Runtime; no networking, telemetry, updater, shell plugin endpoint or privileged helper. Critical control: the removal boundary (rejects protected ancestors/descendants, non-absolute paths, symlink components except aliases, exclusions, other-user-owned items; 5-minute immutable plans with identity metadata; serialized actor rejects replay; owner checks before review and each item). Accepted residual limits *(maintainer, SECURITY.md)*: Foundation Trash race windows, changes inside folders without root metadata change, incomplete owner attribution, blocking kernel calls past deadline, PID reuse between validation and quit request. **Out of scope** *(maintainer, SECURITY.md)*: a malicious same-user process. Community rules must stay declarative (no shell exec, dynamic code, permanent deletion, credential cleanup, privileged mutation).
