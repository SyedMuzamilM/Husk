# Architecture — Husk

Engineering blueprint for a native, efficient, privacy-preserving macOS utility.

---

## 1. Design principles

1. **Native first** — SwiftUI app; no Electron / CEF  
2. **Hot paths in Rust** — disk walks, size aggregation, node_modules discovery  
3. **Least privilege** — elevated helper only for metrics that truly need it  
4. **Local-only data** — SQLite on device; zero telemetry  
5. **Reversible mutations** — Trash API only for user file deletion  
6. **Agent-safe** — MCP can read freely; mutations require human approval  

---

## 2. High-level system diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Husk.app (SwiftUI)                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────┐ │
│  │  Clean   │ │ Analyze  │ │   Apps   │ │  Status  │ │  ...  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬───┘ │
│       │            │            │            │           │     │
│  ┌────▼────────────▼────────────▼────────────▼───────────▼───┐ │
│  │              App Services (Swift actors)                  │ │
│  │  ScanCoordinator · UninstallService · MetricsService      │ │
│  │  LicenseService · AlertService · MCPHost                  │ │
│  └────┬───────────────────┬──────────────────┬───────────────┘ │
└───────┼───────────────────┼──────────────────┼─────────────────┘
        │                   │                  │
        ▼                   ▼                  ▼
┌───────────────┐  ┌────────────────┐  ┌──────────────────┐
│ husk_core │  │  SQLite store  │  │ Privileged Helper│
│   (Rust)      │  │  metrics.db    │  │ (SMAppService /  │
│ disk walk     │  │  30–90 days    │  │  SMJobBless)     │
│ size tree     │  └────────────────┘  │ SMC / IOReport   │
│ node finder   │                      └──────────────────┘
└───────────────┘
        │
        ▼
┌───────────────┐
│  MCP Server   │  ← Claude Code / Cursor / Zed (stdio JSON-RPC)
│  (process)    │
└───────────────┘
```

---

## 3. Technology stack

| Layer | Choice | Rationale |
|---|---|---|
| UI | SwiftUI + AppKit bridges | Native HIG, low memory, Metal-friendly |
| App model | Swift Observation / `@Observable` | Modern state; avoid heavy TCA unless needed |
| Scan engine | Rust → static lib / `cxx` or UniFFI | Memory safety + speed on huge trees |
| DB | SQLite via GRDB.swift or SQLite.swift | Embedded history; no server |
| Hardware | IOKit + SMC keys; SMCKit-class wrappers | Fans, temp, power on Apple Silicon |
| Ports | `libproc` / `lsof` subprocess carefully | Listening sockets for dev UX |
| Licensing | Lemon Squeezy License API | MoR + keys without custom DRM farm |
| Updates | Sparkle 2 | Standard for direct-distributed Mac apps |
| Packaging | Notarized Developer ID .dmg / .zip | Required outside App Store |
| CI | Xcode Cloud or GH Actions + macOS runners | Build, test, notarize pipeline |

### Explicitly rejected

| Option | Why not |
|---|---|
| Electron / Tauri web UI | RAM + “yet another cleaner bloat” optics |
| Mac App Store only | Sandbox blocks deep Library scans & helpers |
| Python scan core | Slow + packaging pain |
| Always-on root daemon | Security surface; battery; trust |

---

## 4. Repository layout (proposed)

```
husk/
├── Apps/
│   └── Husk/                 # SwiftUI app target
├── Packages/
│   ├── HuskKit/              # Shared Swift models, services
│   ├── HuskUI/               # Reusable views (optional split)
│   └── MetricsStore/             # SQLite access layer
├── Engine/
│   └── husk-core/            # Rust crate
│       ├── src/
│       │   ├── walk.rs
│       │   ├── treemap.rs
│       │   ├── node_modules.rs
│       │   └── ffi.rs
│       └── Cargo.toml
├── Helper/
│   └── HuskHelper/           # Privileged helper tool
├── MCP/
│   └── husk-mcp/             # MCP server binary or mode
├── Scripts/
│   ├── notarize.sh
│   └── release.sh
└── docs/                         # product docs (this set)
```

---

## 5. Core modules

### 5.1 Rust engine (`husk-core`)

**Responsibilities**

- Parallel directory traversal with ignore rules  
- Aggregate sizes bottom-up for treemap input  
- Detect `node_modules` roots efficiently  
- Stream progress events (path samples, bytes seen)  
- Export JSON or binary snapshots for Swift  

**Performance targets**

| Workload | Target (M-series, warm FS) |
|---|---|
| `~/Library/Caches` scan | < 5s typical |
| Home directory size map (excl. cloud placeholders policy) | < 30s typical |
| node_modules discovery under `~/dev` | < 10s for mid-size trees |

**Safety**

- Hardcoded deny list for SIP and critical paths  
- Symlink policy: do not follow into system volumes by default  
- Cancellation tokens for cooperative cancel  

**FFI options**

1. **UniFFI** — cleaner Swift bindings (preferred if viable)  
2. **C ABI** + Swift wrapper — more control  

### 5.2 ScanCoordinator (Swift)

- Owns scan sessions as actors  
- Merges Rust results with Swift-side metadata (bundle names, safety labels)  
- Applies **SafetyClassifier** rules  
- Publishes `ScanResult` to UI  

### 5.3 SafetyClassifier

Rule engine mapping paths → `Safe | Review | Caution | Protected`.

```
Input: URL, size, bundle owner?, file type
Rules:
  - isSIP / isOSProtected → Protected
  - known cache patterns → Safe
  - Preferences / Keychains adjacent → Caution or exclude
  - Developer profiles → Review (user must opt in)
Output: label + human reason string
```

Rules versioned in code; ship updates with app releases.

### 5.4 UninstallService

Pipeline:

1. Resolve `.app` bundle → `BundleMetadata` (id, team, name)  
2. Query known path templates  
3. Optional: Spotlight / metadata correlation  
4. Present candidates; user selects  
5. `FileManager.trashItem` each path; collect failures  
6. Summary report  

### 5.5 MetricsService + store

**Sampling**

| Metric | Source | Cadence |
|---|---|---|
| CPU / mem / network | `host_statistics` / `proc` APIs | 1–2s UI; 10–30s history |
| Disk free | `URLResourceValues` | 30–60s |
| SMC temp / fans / power | Helper | 2–5s when Status visible |
| GPU | IOReport / available APIs | When Status visible |

**SQLite schema (sketch)**

```sql
CREATE TABLE samples (
  ts INTEGER NOT NULL,          -- unix ms
  cpu_pct REAL,
  mem_used_bytes INTEGER,
  mem_pressure REAL,
  disk_free_bytes INTEGER,
  net_in_bps INTEGER,
  net_out_bps INTEGER,
  cpu_temp_c REAL,
  fan_rpm REAL,
  power_w REAL
);
CREATE INDEX idx_samples_ts ON samples(ts);

CREATE TABLE process_snapshots (
  ts INTEGER NOT NULL,
  pid INTEGER,
  name TEXT,
  cpu_pct REAL,
  mem_bytes INTEGER
);
-- retain denser process data for shorter windows only
```

**Retention**

- Downsample older data (e.g. raw 10s → 1 min after 24h → 10 min after 7d)  
- Cap DB size; vacuum on schedule  

### 5.6 Privileged helper

- Minimal Mach / XPC interface  
- Methods: `readSMC(keys)`, optional restricted ops  
- Code-signed; blessed via `SMAppService` (macOS 13+)  
- No general-purpose shell execution API  

### 5.7 NetworkPortService

- Prefer programmatic APIs where stable  
- Fallback: controlled `lsof` invocation, parse stdout  
- Map PID → `NSRunningApplication` for icons/names  
- Terminate via `NSRunningApplication.terminate` then force if needed  

### 5.8 Developer purge adapters

| Adapter | Strategy |
|---|---|
| XcodeDerivedData | Size + age filters; trash folders under DerivedData |
| Simulator | Shell out to `xcrun simctl` for unavailable devices |
| NodeModules | Rust discovery → user checklist → trash |
| Ollama | Parse known manifest/index; identify unreferenced blobs |
| LM Studio | Path conventions + model listing |

Each adapter implements:

```swift
protocol PurgeAdapter {
  var id: String { get }
  func discover() async throws -> [PurgeCandidate]
  func validate(_ candidate: PurgeCandidate) -> SafetyLabel
}
```

### 5.9 MCP host

- Separate entry mode: `HuskMCP` executable or `husk --mcp`  
- Tools registered with JSON schemas  
- **Authorization:**  
  - Read tools: always (if licensed)  
  - Cleanup tools: create `PendingApproval` surfaced in UI notification  
- Local audit log table  

### 5.10 LicenseService

- Store license key in Keychain  
- Validate with Lemon Squeezy (online) + signed cache for offline grace (e.g. 14–30 days)  
- Device limit: 2 activations (configurable)  
- Features gated via `Entitlements` enum  

---

## 6. Security & privacy

| Control | Implementation |
|---|---|
| Hardened Runtime | Enabled |
| Notarization | Required for Gatekeeper |
| Sandbox | **Off** for main app (direct distribution); document why |
| Keychain | License + any secrets |
| Network | Allowlist: license API, Sparkle appcast, optional crash **none** |
| Telemetry | **None** — no analytics SDK |
| File delete | Trash only |
| Helper attack surface | Narrow XPC; auditable |

### Privacy policy commitments (product)

- No browsing history collection  
- No file contents uploaded  
- Metrics never leave device  
- Update checks may send app version only  

---

## 7. Concurrency model

- UI: MainActor  
- Scans: dedicated task group / Rust thread pool  
- Metrics sampling: background actor with backpressure  
- DB writes: serial writer queue  
- Avoid blocking main thread on any FS call  

---

## 8. Error handling

- Typed errors: `PermissionError`, `ScanCancelled`, `HelperUnavailable`, `LicenseError`  
- User-facing messages in `Localizable.xcstrings`  
- Debug logs: OSLog subsystems (`app.scan`, `app.metrics`, `app.helper`) — local only  

---

## 9. Testing strategy

| Layer | Approach |
|---|---|
| Rust engine | Unit tests for walk, ignore, treemap packing |
| Safety rules | Fixture path tables |
| Uninstall heuristics | Synthetic app bundles in temp dirs |
| UI | Snapshot tests for critical screens (optional) |
| Integration | On CI Mac: scan fixture volume |
| Manual | Checklist per release (SIP, FDA, helper install) |

---

## 10. Build & release pipeline

```
tag vX.Y.Z
  → build Release (app + helper + mcp)
  → run tests
  → sign (Developer ID)
  → notarize + staple
  → generate Sparkle appcast entry
  → upload artifacts to CDN / GitHub Releases
  → update marketing download link
```

---

## 11. Configuration surface

| Config | Storage |
|---|---|
| User prefs (thresholds, HUD metrics) | UserDefaults |
| Ignore paths | Application Support JSON/SQLite |
| License | Keychain |
| Metrics DB | Application Support |
| Audit log | Application Support |

---

## 12. Performance budgets

| Scenario | Budget |
|---|---|
| App cold launch to interactive UI | < 1.0s on M1 |
| Idle with menu bar | < 0.5% CPU, < 50 MB |
| Active Status tab | < 2% CPU typical |
| Full clean scan | Responsive UI; cancel < 500ms |

---

## 13. Future architecture options

| Idea | When |
|---|---|
| Open-source `husk-core` | After trust/brand established |
| Plugin API for custom purge adapters | v1.x community demand |
| iCloud-free multi-Mac license sync | If device limit pain appears |
| Endpoint Security client | Only if real security product direction (not v1) |

---

## 14. Open engineering decisions

1. UniFFI vs manual C ABI for Rust  
2. GRDB vs SQLite.swift  
3. Helper: `SMAppService` only vs fallback `SMJobBless`  
4. MCP as separate binary vs mode flag  
5. Whether to vendor a pinned open clean engine (Mole CLI–style) or fully custom  

Recommendation: **fully custom Rust core** for differentiation and license clarity; study Mole/Burrow/PureMac behavior as reference, not dependency.
