# Product Requirements Document — Husk

**Version:** 0.1  
**Status:** Draft (from research)  
**Last updated:** 2026-07-14  
**Platform:** macOS 14 Sonoma or later  

---

## 1. Problem statement

Mac power users and developers accumulate tens of gigabytes of caches, build artifacts, simulator data, and local AI models. Existing solutions force a bad tradeoff:

- **CleanMyMac-class tools:** expensive subscriptions, opaque scans, telemetry, fear-based UI  
- **AppCleaner-class tools:** safe but too limited  
- **Mole / Burrow / PureMac:** strong direction, but no single product combines polish + history + AI-agent integration + aggressive developer cleanup at a sub-$10 lifetime price  

Users want **depth without bloat, safety without hand-holding, and ownership without subscriptions.**

---

## 2. Product vision

Husk is a native macOS system utility that:

1. Makes disk usage and cleanup **visually obvious and reversible**  
2. Monitors hardware and processes with **explainable, historical context**  
3. Speaks the language of modern developers (**Xcode, Node, Ollama, ports, MCP**)  
4. Earns trust through **zero telemetry, Trash-only deletion, and transparent previews**  
5. Ships as **freemium** with a **$9.99 lifetime** unlock  

---

## 3. Goals and non-goals

### Goals (v1.0)

| ID | Goal | Metric |
|---|---|---|
| G1 | Free core tools that replace AppCleaner + basic cleaner | Free DAU retention week 1 ≥ 40% |
| G2 | Premium unlock conversion | Free → paid conversion ≥ 3–5% |
| G3 | Perceived safety | Support tickets for “deleted wrong file” < 0.1% of active users |
| G4 | Performance | Full home-dir size scan < 30s on M1/512GB typical disk |
| G5 | Privacy | Zero network calls except license activation / update check |
| G6 | AI agent value | MCP tools used by ≥ 15% of premium users within 60 days |

### Non-goals (v1)

- Full antivirus / malware suite  
- VPN, password manager, or “optimization booster” placebo features  
- Mac App Store distribution (sandbox blocks required system access)  
- Windows / Linux ports  
- Cloud sync of user metrics  
- Permanent file shredding  

---

## 4. User personas

### P1 — Full-stack developer

- MacBook Pro, always low on disk  
- Xcode + Docker + Node + multiple browsers  
- Needs: DerivedData cleanup, node_modules finder, port killer, app leftover removal  

### P2 — AI-native builder

- Runs Ollama / LM Studio locally  
- Uses Claude Code / Cursor agents daily  
- Needs: LLM blob cleanup, MCP hooks so agents can query free space / request cleanup  

### P3 — Privacy-conscious power user

- Hates CleanMyMac ads and subscriptions  
- Wants one honest tool with a clear one-time price  
- Needs: treemap, uninstaller, status, no account required  

---

## 5. User journeys

### Journey A — First clean (free)

1. Download from website → open app (no account)  
2. Grant Full Disk Access (guided)  
3. Open **Clean** → scan completes with categorized results sorted by safety  
4. Review items, expand paths, select safely labeled caches  
5. Move to Trash → empty optional  
6. Soft prompt: unlock Developer Purge for Xcode / AI (premium)  

### Journey B — Find what’s eating disk (free)

1. Open **Analyze** → squarified treemap of selected volume  
2. Drill into nested folders  
3. Context menu → Reveal in Finder / Move to Trash  
4. SIP-protected paths never selectable  

### Journey C — Stuck port (premium)

1. Open **Network / Ports**  
2. See `node` on `:3000`, `python` on `:8000`  
3. Kill process → port free for next dev server  

### Journey D — AI agent recovery (premium)

1. Agent fails build: “No space left on device”  
2. Agent calls Husk MCP → `get_disk_pressure` + `list_safe_clean_targets`  
3. Agent asks user permission → executes approved cleanup via MCP tool  
4. Build resumes  

---

## 6. Functional requirements

### Must-have (MVP)

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | Scan system/user caches with safety labels | P0 |
| FR-02 | Preview paths + sizes before any delete | P0 |
| FR-03 | Delete via Trash only (`FileManager.trashItem`) | P0 |
| FR-04 | Squarified disk treemap (user-selected roots) | P0 |
| FR-05 | Application uninstaller with leftover discovery | P0 |
| FR-06 | Exclude SIP / critical system paths | P0 |
| FR-07 | Zero telemetry by default (and no opt-in dark patterns) | P0 |
| FR-08 | Full Disk Access onboarding | P0 |

### Should-have (v1.0)

| ID | Requirement | Priority |
|---|---|---|
| FR-09 | Live CPU / memory / disk / network / battery monitor | P1 |
| FR-10 | Process list ranked by resource cost + plain-English reasons | P1 |
| FR-11 | SQLite historical metrics (30 days MVP, 90 days target) | P1 |
| FR-12 | Developer purge profiles (Xcode, Simulator, Node, Ollama, LM Studio) | P1 |
| FR-13 | Startup items management | P1 |
| FR-14 | One-tap Optimize (Quick Look, metadata, safe service refresh) | P1 |
| FR-15 | Menu bar HUD (lightweight metrics) | P1 |
| FR-16 | License activation via Lemon Squeezy | P1 |

### Nice-to-have (v1.x)

| ID | Requirement | Priority |
|---|---|---|
| FR-17 | MCP server (stdio) for AI agents | P2 |
| FR-18 | Live port / listening socket table + kill | P2 |
| FR-19 | Low disk + Bluetooth battery alerts | P2 |
| FR-20 | Keep Screen On modes | P2 |
| FR-21 | App update detection (Sparkle, MAS, Homebrew where possible) | P2 |
| FR-22 | Orphan leftover detection (apps already removed) | P2 |

---

## 7. Non-functional requirements

| Area | Requirement |
|---|---|
| **Performance** | Idle menu bar mode < 0.5% CPU avg; < 50 MB RAM typical |
| **Safety** | No permanent delete API in v1; trash only |
| **Privacy** | No analytics SDKs; update check is the only optional network call |
| **Security** | Hardened runtime; notarized; privileged helper only for root metrics when required |
| **Reliability** | Scan cancellable; crashes never leave partial destructive state |
| **Accessibility** | VoiceOver labels on primary controls; keyboard navigation for lists |
| **Localization** | English first; architecture ready for zh-Hans (strong Mole community) |
| **Compatibility** | macOS 14+; Apple Silicon primary; Intel supported |

---

## 8. Permissions model

| Permission | Why | When prompted |
|---|---|---|
| Full Disk Access | Scan Library, Containers, protected user data | First scan / Clean |
| Accessibility (optional) | Advanced process control if needed | Only if feature requires |
| Notifications | Low disk / BT battery alerts | First alert feature use |
| Admin / privileged helper | SMC / certain IOReport metrics | First Status advanced sensors |

Never request more than needed for the active feature.

---

## 9. Success metrics (first 90 days post-launch)

| Metric | Target |
|---|---|
| Website → download | ≥ 25% |
| Download → first successful clean | ≥ 50% |
| Free → paid conversion | ≥ 3% |
| Refund rate | ≤ 5% |
| Crash-free sessions | ≥ 99.5% |
| NPS (optional in-app, local only) | ≥ 40 |

---

## 10. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| User deletes important files | High | Safety labels, defaults off for risky items, trash only, confirm dialogs |
| Apple SIP / privacy changes break scans | High | Modular path providers; graceful degradation |
| Lemon Squeezy outage | Medium | Cached license; offline grace period |
| Comparison to free Burrow | Medium | Superior UX + freemium value + polish |
| Malware false association (cleaners category) | Medium | Open docs on what we touch; notarization; transparent path lists |
| Scope creep into “suite bloat” | High | Strict non-goals; feature budget per release |

---

## 11. Open questions

1. ~~Final product name~~ → **Husk** (locked; domains still to register)  
2. Whether core scan engine is open-sourced for trust (Mole-style hybrid)  
3. Early-bird pricing ladder ($6.99 → $9.99)  
4. Whether menu bar is free or premium  
5. Minimum support window for macOS versions after launch  

---

## 12. Related docs

- [`FEATURES.md`](./FEATURES.md) — feature catalog  
- [`DESIGN.md`](./DESIGN.md) — UI/UX  
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — engineering  
- [`ROADMAP.md`](./ROADMAP.md) — delivery plan  
- [`PRICING.md`](./PRICING.md) — commercial model  
- [`COMPETITIVE.md`](./COMPETITIVE.md) — market map  
