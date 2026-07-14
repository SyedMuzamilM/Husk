# Roadmap — Husk

Phased plan from zero → public v1.0 → differentiation features.  
Priorities map to [`FEATURES.md`](./FEATURES.md) and [`PRD.md`](./PRD.md).

---

## Timeline overview

```
Phase 0    Foundation          Week 0–2
Phase 1    MVP (private)       Week 2–8
Phase 2    Beta                Week 8–12
Phase 3    v1.0 Public         Week 12–14
Phase 4    Differentiator      Week 14–20
Phase 5    Growth              Week 20+
```

Dates are relative; adjust to part-time vs full-time capacity.

| Cadence | Solo full-time | Solo part-time (~15h/wk) |
|---|---|---|
| MVP | ~8 weeks | ~4–5 months |
| Public v1.0 | ~12–14 weeks | ~6–7 months |

---

## Phase 0 — Foundation (Week 0–2)

**Goal:** Repo, architecture, and design decisions locked.

### Deliverables

- [ ] Finalize product name & bundle ID  
- [ ] Apple Developer account + certificates ready  
- [ ] Xcode project + Swift packages scaffold  
- [ ] Rust crate scaffold + FFI hello-world  
- [ ] Document safety rules v0 (path deny list)  
- [ ] Choose: UniFFI vs C ABI, GRDB vs SQLite.swift  
- [ ] Brand basics: accent color, app icon draft  
- [ ] Lemon Squeezy store draft (can be test mode)  

### Exit criteria

- Empty app launches notarized **or** at least signed locally  
- Rust called from Swift returning a directory size  

---

## Phase 1 — MVP private build (Week 2–8)

**Goal:** A usable free-tier cleaner you’d give a friend.

### 1.1 Permissions & shell — P0

- [ ] Full Disk Access onboarding flow  
- [ ] Sidebar navigation skeleton (Clean, Analyze, Apps, Settings)  
- [ ] Zero network calls on launch  

### 1.2 Clean (core) — P0

- [ ] Cache category scanner (browser, user caches, logs)  
- [ ] Safety labels (Safe / Review / Caution / Protected)  
- [ ] Multi-select + size totals  
- [ ] Move to Trash via `FileManager.trashItem`  
- [ ] Cancelable scan + progress  

### 1.3 Analyze — P0

- [ ] Rust (or Swift) hierarchical size walk  
- [ ] Squarified treemap rendering  
- [ ] Drill-down + breadcrumbs  
- [ ] Reveal in Finder / Trash from selection  
- [ ] SIP / protected path exclusion  

### 1.4 Apps uninstaller — P0

- [ ] List installed applications  
- [ ] Bundle ID + heuristic leftover discovery  
- [ ] Preview leftovers with sizes  
- [ ] Combined trash flow  

### 1.5 Quality bar for MVP

- [ ] Does not claim APFS purgeable as cleaned  
- [ ] No permanent delete APIs  
- [ ] Crash-free on clean / uninstall happy paths  
- [ ] Manual test checklist documented  

### Exit criteria

- Dogfood daily for 1 week  
- Reclaim real GB on a developer machine safely  
- Friend test (3–5 people) without data-loss incidents  

---

## Phase 2 — Closed beta (Week 8–12)

**Goal:** Premium skeleton + monitoring + distribution dry run.

### 2.1 Status (live) — P1

- [ ] CPU / memory / disk / network cards  
- [ ] Process list (top consumers)  
- [ ] Quit / force quit actions  
- [ ] Battery info where available  

### 2.2 Metrics history — P1

- [ ] SQLite sample writer  
- [ ] 30-day retention + downsampling  
- [ ] Basic historical charts in Status  

### 2.3 Developer purge (v1) — P1

- [ ] Xcode DerivedData profile  
- [ ] Simulator unavailable cleanup via `simctl`  
- [ ] node_modules finder  
- [ ] Ollama / LM Studio path scanners (preview-first)  

### 2.4 Optimize — P1

- [ ] Quick Look rebuild  
- [ ] Other safe tasks with explicit descriptions  
- [ ] Admin prompt only when required  

### 2.5 Licensing — P1

- [ ] Lemon Squeezy product + license keys  
- [ ] Activate / deactivate / restore  
- [ ] Feature gates for premium modules  
- [ ] Offline grace period  

### 2.6 Menu bar HUD — P1

- [ ] Lightweight metrics  
- [ ] Open main window  
- [ ] Power-friendly sampling  

### 2.7 Packaging — P1

- [ ] Sparkle update feed (beta channel)  
- [ ] Notarized DMG  
- [ ] Landing page “Beta” with build download  

### Exit criteria

- 20–50 beta users  
- Refund/license flow tested  
- ≤ critical bugs open on Clean / Uninstall  

---

## Phase 3 — Public v1.0 (Week 12–14)

**Goal:** Ship freemium product at $9.99.

### Launch checklist

- [ ] Free: Clean, Analyze treemap, Uninstall  
- [ ] Premium: Dev purge, Status history, advanced sensors (if ready), menu bar full  
- [ ] Paywall UX (non-dark-pattern)  
- [ ] Privacy policy + terms (direct distribution)  
- [ ] 14-day refund policy published  
- [ ] Support email / form  
- [ ] Marketing site live  
- [ ] Product Hunt / HN / Reddit / Twitter launch kit  
- [ ] Comparison page vs CleanMyMac / Mole (honest)  

### Launch metrics to watch (first 14 days)

| Metric | Attention |
|---|---|
| Download → first scan | Funnel drop-offs |
| Crash reports (Sparkle / manual) | Stability |
| Refund rate | Pricing / expectation mismatch |
| Top support themes | Docs & UX fixes |

### Exit criteria

- Public download link stable  
- License purchase works end-to-end  
- No known data-loss bugs  

---

## Phase 4 — Differentiators (Week 14–20)

**Goal:** Become the “AI + developer” Mac utility — beyond Mole.

### 4.1 MCP server — P2

- [ ] stdio MCP binary / mode  
- [ ] Read tools: disk, processes, safe targets  
- [ ] Cleanup proposal + human approval UX  
- [ ] Docs for Claude Code / Cursor / Zed setup  

### 4.2 Network ports — P2

- [ ] Listening port table  
- [ ] Kill process flow  
- [ ] Optional MCP tool `list_listening_ports`  

### 4.3 Alerts — P2

- [ ] Low disk notifications  
- [ ] Bluetooth battery (when available)  
- [ ] Quiet hours  

### 4.4 Keep Screen On — P2

- [ ] Three modes via IOPM assertions  
- [ ] Menu bar status  

### 4.5 Uninstall depth — P2

- [ ] Orphan leftover detector  
- [ ] Improved Team ID / container matching  

### 4.6 Status depth — P2

- [ ] SMC fans / temp / power via helper  
- [ ] Explainable process cost strings  
- [ ] History → 90 days  

### Exit criteria

- Premium features clearly worth $9.99 vs free  
- At least one viral dev demo (MCP or port killer + Ollama clean)  

---

## Phase 5 — Growth (Week 20+)

**Goal:** Retention, trust, expansion revenue without subscriptions-first identity.

### Product

- [ ] App update aggregator (Sparkle / brew / MAS link-out)  
- [ ] Localization: zh-Hans (high Mole-community overlap)  
- [ ] Optional open-source of scan engine for trust  
- [ ] Advanced ignore rules & cleanup schedules (careful: don’t become bloat)  
- [ ] Docker purge adapter (optional)  

### Business

- [ ] Early-bird → standard price lock for existing users  
- [ ] Volume / team licenses (Paddle/LS B2B if needed)  
- [ ] Affiliate for creator/devs  
- [ ] Annual “membership” **optional** for tip jar / charity — never required for updates if promised lifetime  

### Moats

- [ ] Best-in-class developer profiles  
- [ ] Best MCP integration in category  
- [ ] Reputation for never faking junk numbers  

---

## Milestone summary

| Milestone | User-visible outcome |
|---|---|
| **M0** | Empty signed app + Rust bridge |
| **M1** | Free cleaner + treemap + uninstaller |
| **M2** | Beta with premium gates + history + dev purge |
| **M3** | Public $0 / $9.99 launch |
| **M4** | MCP + ports + alerts — category leadership |
| **M5** | Localize, polish, optional OSS engine |

---

## Dependency graph (build order)

```
Foundation
    └── Clean scanner ──┬── Safety labels
                        └── Trash pipeline
    └── Disk walk engine ─── Treemap UI
    └── App listing ─── Leftover heuristics ─── Uninstall UI

Clean + Analyze + Apps  ─── MVP

MVP ─── Metrics sampling ─── SQLite history ─── Status UI
    ─── Dev purge adapters
    ─── License service ─── Paywall
    ─── Menu bar
    ─── Sparkle ─── Public launch

Launch ─── MCP
       ─── Ports
       ─── Alerts / Keep awake
       ─── Helper SMC sensors
```

---

## Risk-adjusted priorities

If time is short, **cut in this order** (keep trust):

1. Keep: Clean safety, Trash-only, Treemap, Uninstall  
2. Keep: License + free/paid split  
3. Stretch: History charts  
4. Stretch: MCP  
5. Cut first: App update aggregator, BT battery, fancy metaphors  

**Never cut:** path previews, SIP exclusions, trash-only, zero fake junk scores.

---

## Suggested first sprint (Week 1)

| Day | Focus |
|---|---|
| 1–2 | Xcode app + sidebar + FDA onboarding UI |
| 3–4 | Swift cache enumerator for 2–3 Safe categories |
| 5 | Trash flow + summary |
| 6–7 | Rust walk prototype for one directory tree |

---

## Tracking

Use GitHub Projects / Linear with labels:

- `P0-mvp` `P1-v1` `P2-diff`  
- `area:clean` `area:analyze` `area:apps` `area:status` `area:mcp`  
- `type:bug` `type:safety`  

Safety bugs always jump the queue.
