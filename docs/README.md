# Documentation

Start with the [project README](../README.md) for capabilities, installation, and development setup.

## Implementation and safety

- [Architecture](ARCHITECTURE.md): Swift modules, task ownership, and filesystem services.
- [Safety policy](SAFETY.md) and [cleanup rule requirements](RULES.md): selection, removal, ownership, and evidence.
- [AI storage](AI_STORAGE.md): supported tool paths, protected data, and worktree inspection.
- [Privacy](PRIVACY.md): local metadata and operation history.
- [Audit resolution](AUDIT_RESOLUTION.md): repaired findings and remaining limits.

## Contribution and release

- [Contributing](../CONTRIBUTING.md), [code of conduct](../CODE_OF_CONDUCT.md), and [support](../SUPPORT.md).
- [Security reporting](../SECURITY.md), [license](../LICENSE), and [third-party notices](../NOTICE.md).
- [Verification](VERIFICATION.md): reproducible checks and recorded results.
- [Release preparation](RELEASING.md): compatibility checks, signing, and notarization.
- [Roadmap](ROADMAP.md): proposed improvements and AI maintenance requirements.
- [Source provenance](SOURCE_PROVENANCE.md): dependencies and original assets.

Obsolete product plans, prototype exports, and older audit reports remain in Git history. The performance probe under `docs/performance` is used by `scripts/profile-sizing.sh`.
