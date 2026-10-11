> Historical product plan. Proposed features and pricing are not current implementation claims. See the repository README and AUDIT_RESOLUTION.md for verified status.

# Features — Husk

Feature catalog derived from market research and competitor gaps (Mole, CleanMyMac, AppCleaner, Burrow, PureMac, MacPulse).

**Legend**

| Badge | Meaning |
|---|---|
| 🆓 Free | Available without license |
| 💎 Premium | Requires $9.99 lifetime license |
| P0 / P1 / P2 | Build priority |

---

## Feature map

```
Husk
├── Clean .......... cache & artifact cleanup
├── Analyze ........ disk treemap & large files
├── Apps ........... uninstall, leftovers, startup, updates
├── Status ......... live hardware / process monitoring
├── Network ........ ports & connections (premium)
├── Optimize ....... one-tap safe maintenance
├── Alerts ......... proactive environment notifications
├── Menu Bar ....... lightweight HUD
└── MCP ............ AI agent integration (premium)
```

---

## 1. Clean

**Purpose:** Reclaim disk space from caches and developer/AI artifacts with full transparency.

### 1.1 Smart cache scanner — 🆓 P0

Scan and categorize:

| Category | Examples | Default safety |
|---|---|---|
| Browser caches | Safari, Chrome, Firefox, Arc, Edge | Safe |
| System logs | `~/Library/Logs`, diagnostic reports | Safe |
| User caches | `~/Library/Caches/*` (allowlisted) | Safe–Review |
| Mail / Messages attachments (optional) | Only explicit user opt-in paths | Review |
| App support temp files | Known temp subdirs | Review |
| Trash contents | User Trash size preview | Safe |

**Rules**

- Sort results by **safety** then size  
- User must select items; nothing auto-deleted  
- Show full path, size, last modified, parent app if known  
- Actions: Move to Trash / Reveal in Finder / Deselect all of category  

### 1.2 Safety labeling system — 🆓 P0

Every item receives one of:

| Label | Meaning | UI default |
|---|---|---|
| **Safe** | Regenerable caches/logs | Selected optional (user preference) |
| **Review** | May include preferences or semi-important data | Unselected |
| **Caution** | Could affect app state or downloads | Unselected + warning |
| **Protected** | SIP / system critical | Not selectable |

### 1.3 Developer purge profiles — 💎 P1

Specialized, manifest-aware cleaners:

| Profile | Targets | Safety notes |
|---|---|---|
| **Xcode** | `DerivedData`, Archives (opt-in), old DeviceSupport | Prefer size thresholds; never touch source |
| **iOS Simulator** | Unavailable devices via `xcrun simctl delete unavailable`; optional device wipe | Use Apple CLIs, not blind rm |
| **Node / JS** | Nested `node_modules` discovery (Rust walk) | Only dirs user confirms; respect monorepos |
| **Ollama** | `~/.ollama/models/blobs`, orphaned digests | Parse manifests; avoid breaking active models |
| **LM Studio** | `~/.lmstudio/` caches & unused models | Preview model names/sizes |
| **Package managers** | Homebrew cache, pip/npm global caches | Safe caches only |
| **Docker** (optional later) | dangling images via docker CLI | P2; require Docker installed |

### 1.4 Deletion philosophy — 🆓 P0

- **Trash, never shred** (align with PureMac safety ethos)  
- No permanent `unlink` of user files in v1  
- No claiming APFS **purgeable** space as “junk cleaned”  
- Post-clean summary: space moved to Trash + reminder to Empty Trash  

---

## 2. Analyze (Disk)

**Purpose:** Instant visual understanding of where space goes.

### 2.1 Squarified treemap — 🆓 P0

- Algorithm: Bruls, Huijsen & van Wijk squarified treemap  
- Nested rectangles proportional to size  
- Bounded aspect ratios for readability  
- Drill-down / breadcrumb navigation  
- Color by type (apps, media, code, caches, other) or by depth  

### 2.2 Large file finder — 🆓 P0

- Threshold filter (e.g. > 100 MB / 1 GB)  
- Sort by size, date, type  
- Context actions: Trash, Finder, Quick Look  

### 2.3 Exclusions — 🆓 P0

Never scan or offer for delete:

- SIP-protected system paths  
- Active Time Machine local snapshots (display only if useful later)  
- User-defined ignore list  

---

## 3. Apps

**Purpose:** Complete application lifecycle hygiene.

### 3.1 Smart uninstaller — 🆓 P0

Multi-layer leftover discovery:

1. **Bundle ID** (`CFBundleIdentifier`)  
2. **Team ID** from code signature  
3. **Path heuristics** across:  
   - `~/Library/Application Support`  
   - `~/Library/Preferences`  
   - `~/Library/Caches`  
   - `~/Library/Logs`  
   - `~/Library/Containers`  
   - `~/Library/Group Containers`  
   - `~/Library/Saved Application State`  
   - `~/Library/WebKit` / HTTP storages where applicable  
4. **Spotlight / metadata** hints when available  

**UX**

- Preview every leftover with size  
- Select/deselect individuals  
- Show total reclaimable before confirm  
- Trash app bundle + selected leftovers together  

### 3.2 Orphan detector — 💎 P2

Cross-reference Library folders against installed apps to find remnants of previously deleted software.

### 3.3 Startup items — 🆓 P1

- List Login Items, LaunchAgents (user), selected LaunchDaemons (view)  
- Enable/disable with explanation of impact  
- Never silently remove system agents  

### 3.4 App updates (multi-source) — 💎 P2

Detect updates where possible:

| Source | Approach |
|---|---|
| Sparkle apps | Read `SUFeedURL` / appcast when present |
| Mac App Store | Link out / `mas` if available (no private MAS APIs abuse) |
| Homebrew | `brew outdated` when brew present |

---

## 4. Status (Monitor)

**Purpose:** Activity Monitor–class insight without the complexity wall.

### 4.1 Live metrics — 🆓/💎 P1

| Metric | Free | Premium |
|---|---|---|
| CPU / Memory summary | ✅ | ✅ |
| Per-process top list | Limited (top N) | Full |
| Disk I/O | Basic | Detailed |
| Network throughput | Basic | Detailed |
| Battery health / cycle (where available) | ✅ | ✅ |
| GPU sampling | — | ✅ |
| Fan / thermal (SMC) | — | ✅ |
| Board power (watts) | — | ✅ |

### 4.2 Explainable process ranking — 💎 P1

Inspired by MacPulse:

- Rank by real cost (CPU × time, memory pressure contribution)  
- Plain-English: “High CPU — compiling Swift”, “Memory — browser with many tabs” (heuristic)  
- Click process → details + Quit / Force Quit  

### 4.3 Historical trends — 💎 P1

- Local SQLite store  
- Retention: 30 days (MVP) → 90 days  
- Charts: CPU, memory, temperature, disk free over time  
- Use cases: chronic leaks, thermal throttling during compiles  

### 4.4 Sampling performance budget

- Adaptive sample rates when menu bar only  
- Never compete with user workloads during heavy scans  

---

## 5. Network / Ports — 💎 P2

**Purpose:** Developer localhost conflict resolution.

- Background parse of listening sockets (e.g. `lsof -iTCP -sTCP:LISTEN -n -P` or equivalent safe APIs)  
- Table: PID, process name, port, protocol, user  
- Actions: Reveal process, Terminate, Copy address  
- No DNS resolution by default (keep snappy, low battery impact)  

---

## 6. Optimize — 🆓 P1

One-tap **safe** maintenance:

| Task | Method | Privilege |
|---|---|---|
| Rebuild Quick Look cache | `qlmanage -r` / safe equivalent | User |
| Refresh icon services | Documented safe commands | User |
| Rebuild Spotlight index (opt-in) | Explicit confirm — disruptive | May need admin |
| Flush DNS cache (opt-in) | Explicit confirm | Admin |

**Rules**

- No placebo “RAM liberator”  
- No fake score meters  
- Show exactly what will run before executing  
- Admin prompt only when kernel/OS requires it  

---

## 7. Alerts — 💎 P2

Proactive, non-nagging notifications:

| Alert | Trigger |
|---|---|
| Low disk | Free space < user threshold (default 10–15 GB or 10%) |
| Critical disk | Free space < 5 GB |
| Bluetooth peripheral battery low | When API available for connected devices |

Preferences: thresholds, quiet hours, disable per type.

---

## 8. Display utilities — 🆓/💎 P2

### Keep Screen On — 🆓 or 💎 (decide at GTM)

Three modes:

1. **While plugged in**  
2. **For timed duration** (30m / 1h / 2h / custom)  
3. **Until disabled** (presentation / long compile)  

Uses standard `IOPMAssertion` patterns; shows clear status when active.

---

## 9. Menu Bar HUD — 🆓 basic / 💎 full P1

Lightweight always-available metrics:

- Free: disk free % or single metric  
- Premium: CPU · Memory · Network · optional temp  
- “Less power on the menu bar” — low sample rate, coalesced UI updates  
- Click → popover with mini charts / open main app  

---

## 10. MCP Server (AI agents) — 💎 P2

**Purpose:** Make Husk part of the AI development stack (inspired by Burrow).

### Transport

- Model Context Protocol over **stdio**  
- JSON-RPC tool interface  

### Example tools

| Tool | Description |
|---|---|
| `get_disk_usage` | Free/used/total for volumes |
| `get_disk_pressure` | Whether free space is critically low |
| `list_safe_clean_targets` | Safe regenerable caches with sizes |
| `list_developer_artifacts` | Xcode/Node/LLM candidates (summary) |
| `request_cleanup` | Propose cleanup set; **requires user approval** in UI or explicit flag |
| `get_top_processes` | Top CPU/memory processes |
| `list_listening_ports` | Dev port table |

### Safety for agents

- Default: agents can **read** freely; **write/delete requires human confirmation**  
- Audit log of agent-initiated actions (local)  

---

## 11. Onboarding & trust — 🆓 P0

1. Welcome → privacy promise (zero telemetry)  
2. Permission guide (Full Disk Access with screenshots)  
3. First scan tutorial  
4. Optional: sample “safe clean” recommendation  
5. No forced account; no email wall  

---

## 12. Licensing & updates — P1

| Capability | Free | Premium |
|---|---|---|
| Core Clean / Analyze / Uninstall | ✅ | ✅ |
| Developer profiles, history, ports, MCP, advanced Status | — | ✅ |
| License devices | — | 2 Macs (parity with Mole; adjustable) |
| Updates | Free updates for free features | Lifetime updates for premium features |
| Refund | — | 14-day via MoR policy |

Activation via Lemon Squeezy license key (see [`PRICING.md`](./PRICING.md)).

---

## 13. Explicitly out of scope (v1)

- Antivirus / malware scanner  
- “Privacy protection” VPN upsells  
- Fake system scores / gamified health  
- Cloud backup of scans  
- Browser extension  
- iOS companion app  
- Permanent secure erase  

---

## 14. Competitive feature matrix (summary)

| Feature | CleanMyMac | Mole | Burrow | PureMac | **Husk** |
|---|---|---|---|---|---|
| Treemap disk analysis | Partial | ✅ | Partial | — | ✅ Free |
| App uninstaller | ✅ | ✅ | via engine | ✅ | ✅ Free |
| Dev / AI artifact purge | Weak | Strong | Strong | — | ✅ Premium |
| Historical metrics | — | — | ✅ 90d | — | ✅ Premium |
| MCP for AI agents | — | — | ✅ | — | ✅ Premium |
| Port monitor | — | — | — | — | ✅ Premium |
| Zero telemetry | ❌ | ✅ | Mostly | ✅ | ✅ |
| Price | $35–90/yr | $19 once | Free | Free | **$0 / $9.99** |
| Trash-only safety | Mixed | Good | Good | Strict | **Strict** |

Full competitor write-up: [`COMPETITIVE.md`](./COMPETITIVE.md)
