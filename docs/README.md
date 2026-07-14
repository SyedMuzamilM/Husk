# Husk — Product Overview

> **Peel the husk.**  
> A developer-centric, privacy-first Mac cleaner and system monitor.  
> One-time price. Zero telemetry. Built for power users, not fear marketing.

**Brand:** Husk (locked) · see [`NAME_AND_BRANDING.md`](./NAME_AND_BRANDING.md)  
**Target price:** $9.99 lifetime (premium) · Free tier available  
**Platform:** macOS 14+ · Apple Silicon + Intel  
**Stack:** SwiftUI · Rust engine · SQLite · MCP server  
**Marketing:** [`MARKETING.md`](./MARKETING.md)

---

## Why this exists

The macOS utility market is stuck between:

| Legacy bloat | Emerging open tools |
|---|---|
| CleanMyMac — $35–90/yr subscriptions, heavy telemetry, fear-based UI | Mole for Mac — $19, solid but incomplete |
| Opaque scanners, fake junk metrics | Burrow / PureMac — free, technical, limited polish |

**Husk** fills the gap: technical depth of CLI tools, safety of open-source cleaners, historical metrics of Burrow, visual polish of CleanMyMac — without subscriptions or bloat.

Primary research and competitive analysis: [`research.md`](./research.md)

---

## Product docs

| Doc | Purpose |
|---|---|
| [`BETA.md`](./BETA.md) | Internal beta 0.1.0 scope, run steps, checklist |
| [`MARKETING.md`](./MARKETING.md) | Positioning, launch copy, channels, site structure |
| [`PRD.md`](./PRD.md) | Product requirements, goals, success metrics |
| [`FEATURES.md`](./FEATURES.md) | Full feature catalog (free vs premium) |
| [`DESIGN.md`](./DESIGN.md) | UI/UX principles, visual language, interaction patterns |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Tech stack, modules, security, privileged helpers |
| [`ROADMAP.md`](./ROADMAP.md) | Phased build plan from MVP → v1.0 → growth |
| [`PRICING.md`](./PRICING.md) | Freemium model, Lemon Squeezy, unit economics |
| [`COMPETITIVE.md`](./COMPETITIVE.md) | Competitor matrix and differentiation |
| [`SAFETY.md`](./SAFETY.md) | Non-negotiable safety & trust policy |
| [`NAME_AND_BRANDING.md`](./NAME_AND_BRANDING.md) | Locked brand: **Husk** |
| [`RESEARCH_REVIEW.md`](./RESEARCH_REVIEW.md) | Critique of source research + decisions taken |
| [`research.md`](./research.md) | Original market & technical research |

---

## Positioning (one-liner)

**“Peel the husk off your Mac — clean, map, and monitor with full transparency. $9.99 forever.”**

### Core promises

1. **Transparent** — Show every file before delete; no red “junk” scare counters  
2. **Safe** — Trash only, never shred; respect SIP; refuse APFS purgeable fakes  
3. **Private** — Zero telemetry; all processing local  
4. **Developer-first** — Xcode, node_modules, Ollama, LM Studio, ports, MCP  
5. **Cheap & fair** — Free core tools; $9.99 lifetime for pro features  

---

## Target users

| Persona | Pain | What they get |
|---|---|---|
| **Indie / full-stack dev** | Disk full of DerivedData, node_modules, LLM blobs | Specialized purge profiles + port monitor |
| **AI-native developer** | Agents fail on low disk; no system introspection | MCP server for Claude/Cursor/Zed |
| **Power user** | CleanMyMac feels scummy; AppCleaner too thin | Treemap + app cleaner + live status |
| **Privacy-conscious Mac owner** | Subscriptions + telemetry | One-time license, local-only |

---

## High-level modules

```
┌─────────────────────────────────────────────────────────┐
│  Husk (SwiftUI)                                     │
├──────────┬──────────┬──────────┬──────────┬─────────────┤
│  Clean   │  Analyze │  Apps    │  Status  │  Optimize   │
│  caches  │  treemap │  uninstall│ monitor │  one-tap    │
│  + AI    │  + ports │  updates │  history │  maintenance│
└──────────┴──────────┴──────────┴──────────┴─────────────┘
         │                    │
         ▼                    ▼
   Rust scan engine     SQLite metrics (30–90d)
         │
         ▼
   MCP server (stdio) ← AI agents
```

---

## Tech at a glance

- **UI:** Native SwiftUI (no Electron)
- **Scan engine:** Rust (memory-safe, multi-threaded disk walk)
- **Telemetry:** IOKit / SMC (temp, power, fans) via helper tool
- **History:** Embedded SQLite (30–90 day metrics)
- **AI:** MCP over stdio (JSON-RPC)
- **Distribution:** Direct (not App Store) via Lemon Squeezy
- **License:** Offline-friendly key validation

---

## Status

| Phase | State |
|---|---|
| Research & strategy | ✅ Complete (`research.md`) |
| Product documentation | ✅ This repo |
| MVP implementation | 🔲 Not started — see [`ROADMAP.md`](./ROADMAP.md) |

---

## License (product)

Commercial product. Free tier + paid lifetime license.  
CLI engine components may be dual-licensed later (TBD).

---

## Next steps

1. Read [`PRD.md`](./PRD.md) for scope and goals  
2. Review [`ROADMAP.md`](./ROADMAP.md) for build order  
3. Use [`ARCHITECTURE.md`](./ARCHITECTURE.md) when scaffolding the Xcode + Rust workspace  
