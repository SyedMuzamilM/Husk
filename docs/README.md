# Husk documentation

Husk is a native macOS storage utility. The whole app is MIT licensed and developed on `main`. Start with the [repository README](../README.md) for build instructions and current capabilities.

## Contributing and implementation

- [Contributing](../CONTRIBUTING.md), [code of conduct](../CODE_OF_CONDUCT.md), and [support](../SUPPORT.md).
- [Architecture](ARCHITECTURE.md) describes the Swift services, state ownership, and removal boundary.
- [Safety](SAFETY.md), [cleanup rule requirements](RULES.md), and [AI storage](AI_STORAGE.md) define what can be reviewed or removed.
- [Security](../SECURITY.md) and [privacy](PRIVACY.md) explain reporting and local data handling.
- [License and notices](../NOTICE.md) and [source provenance](SOURCE_PROVENANCE.md) cover reuse and dependencies.

## Verification and release

- [Current verification](OPEN_SOURCE_VERIFICATION_2026-10-13.md), [earlier verification](VERIFICATION.md), and [audit resolution](AUDIT_RESOLUTION.md).
- [Release process](RELEASING.md), [interactive readiness checklist](OPEN_SOURCE_READINESS.html), and [roadmap](ROADMAP.md).
- [Original audit](PROJECT_AUDIT_2026-10-11.md), [listing/release repair](REPAIR_VERIFICATION_2026-10-12.md), and [onboarding checks](ONBOARDING_AND_LAYOUT_VERIFICATION_2026-10-12.md) preserve the evidence behind the changes.
- [Competitor comparison](COMPETITOR_AUDIT_2026-10-11.md) records independent research into Mole and other utilities. No competitor code is bundled.

## Historical plans

PRD.md, FEATURES.md, PRICING.md, MARKETING.md, COMPETITIVE.md, DESIGN.md, BETA.md, RESEARCH_REVIEW.md, and research.md preserve earlier product planning. Their paid tiers, Rust engine, MCP, privileged helpers, and schedules are not current commitments. Current implementation and safety documents take precedence. Earlier architecture and roadmap versions remain in Git history.

The HTML discussion pages preserve proposals for features requiring more evidence. Session deletion, worktree removal, and installed-version pruning remain inspection-only.
