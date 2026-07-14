# Design System & UX — Husk

**Principle:** Technical power, calm presentation.  
No fear marketing. No fake urgency. Clarity over decoration.

---

## 1. Design goals

| Goal | How it shows up |
|---|---|
| **Trust** | Every destructive action is previewable and reversible |
| **Calm** | Neutral colors; no red “48 junk files!!!” counters |
| **Native** | Feels like a first-party macOS app (SwiftUI + HIG) |
| **Fast** | Instant feedback; progressive disclosure of depth |
| **Delight without toyishness** | Subtle motion; optional soft thematic metaphors |

---

## 2. Brand direction

### Working identity

| Element | Direction |
|---|---|
| **Name** | **Husk** (locked) |
| **Personality** | Precise, quiet confidence, developer-respectful |
| **Voice** | Plain English. “12 GB in Xcode DerivedData” not “Critical system threat” |
| **Metaphor** | Peel / shell / seed — remove the husk, keep what matters. Disk as layered terrain. Never planetary gimmicks or fear scores |

### Anti-brand (do not)

- Scare red badges and countdown urgency  
- “Your Mac is 87% infected / dirty” scores  
- Stock blue gradient SaaS clichés  
- Cartoon mascots that undermine technical trust  
- Dark patterns: fake free scans that lock results  

---

## 3. Visual foundations

### 3.1 Appearance

- **Primary:** Native dark and light mode (follow system)  
- Default marketing screenshots: dark mode (developer affinity)  
- Materials: `NSVisualEffectView` / SwiftUI materials for sidebars and HUD  

### 3.2 Color tokens (semantic)

| Token | Role | Notes |
|---|---|---|
| `bg.app` | Window background | System grouped / window background |
| `bg.sidebar` | Navigation | Ultra-thin material |
| `bg.card` | Panels, metric cards | Elevated surface |
| `text.primary` | Titles, values | Label color |
| `text.secondary` | Paths, metadata | Secondary label |
| `accent` | Interactive primary | Single brand accent (teal or soft indigo — finalize) |
| `safe` | Safety: Safe | Green (system green, muted) |
| `review` | Safety: Review | Amber |
| `caution` | Safety: Caution | Orange |
| `protected` | Non-selectable | Gray + lock icon |
| `chart.cpu` / `mem` / `disk` / `net` | Metrics | Distinct, colorblind-safe palette |
| `destructive` | Confirm delete | System red — **only** on confirm buttons, not for marketing scare |

### 3.3 Typography

| Role | Style |
|---|---|
| App title / large metrics | SF Pro, semibold, large title / title |
| Section headers | SF Pro, headline |
| Body | SF Pro, body |
| Paths / code-ish metadata | SF Mono, caption |
| Menu bar HUD | SF Pro / SF Mono compact, medium |

Prefer **tabular numbers** for sizes, percentages, and live metrics.

### 3.4 Spacing & density

- Comfortable density (not sparse consumer fluff, not terminal cram)  
- 8-pt grid  
- Lists: generous row height for path + size + safety chip  
- Prefer split views over nested modal stacks  

### 3.5 Iconography

- SF Symbols first  
- Custom symbols only where SF falls short (treemap glyph, MCP mark)  
- Module icons should be **functional**, not pure decoration  

---

## 4. Information architecture

### 4.1 Primary navigation (sidebar)

```
Husk
├── Clean
├── Analyze
├── Apps
├── Status
├── Network     (premium badge if locked)
├── Optimize
└── ─────────
    Settings
    Upgrade     (if free)
```

Optional top-level **Menu Bar** prefs live under Settings.

### 4.2 Window layout

```
┌──────────┬────────────────────────────────────────────┐
│ Sidebar  │  Toolbar (context actions)                 │
│          ├────────────────────────────────────────────┤
│          │                                            │
│          │  Main content                              │
│          │  (list / treemap / charts)                 │
│          │                                            │
│          ├────────────────────────────────────────────┤
│          │  Inspector / detail (optional trailing)    │
└──────────┴────────────────────────────────────────────┘
```

- Minimum window size: ~960×640  
- Remember size/position per Space if practical  
- Support full-screen for Analyze treemap  

### 4.3 Menu bar popover

```
┌─────────────────────────┐
│ CPU ███ 24%  Mem 61%    │
│ Disk 82 GB free         │
│ ─────────────────────── │
│ [Open Husk]         │
│ Keep Screen On ▾        │
└─────────────────────────┘
```

---

## 5. Key screens

### 5.1 Clean

**Layout**

- Top: Scan status / last scan time / free space delta  
- Middle: Category sections (disclosure groups)  
- Each row: checkbox · name · safety chip · size · chevron for path detail  
- Bottom bar: selected count · total size · **Move to Trash**  

**Empty / first-run**

- Illustration + “Grant Full Disk Access” checklist  
- Never show fake “scanning 10,000 threats”  

**Scanning state**

- Determinate progress if possible; else indeterminate with current path (throttled)  
- Cancel always available  

### 5.2 Analyze (treemap)

**Interaction**

- Click rectangle → zoom into folder  
- Breadcrumb back  
- Hover: tooltip with path + size + % of parent  
- Right-click: Reveal / Trash / Copy path  
- Toggle: Treemap | List of large files  

**Visual rules**

- Avoid rainbow chaos; max ~6–8 category hues  
- Minimum cell label size; hide labels on tiny cells  
- Animate zoom with short, ease-out motion (≤ 200ms)  

### 5.3 Apps

- Master list of `/Applications` + user apps  
- Search + sort by size / name / last opened  
- Detail pane: bundle ID, size, leftover candidates  
- Uninstall flow as multi-step sheet: select leftovers → confirm → progress → summary  

### 5.4 Status

- Top metric cards (CPU, Memory, Disk, Network, Battery)  
- Charts for selected metric (live sparkline)  
- Process table below  
- Premium: history range selector (1h / 24h / 7d / 30d)  

### 5.5 Network

- Simple data table, Activity Monitor adjacent feel  
- Filters: listening only / all; search by port or process  
- Destructive action (Kill) always confirms  

### 5.6 Optimize

- Card list of maintenance tasks with one-line plain description  
- Master **Run selected**  
- Results log (local, plain language)  

### 5.7 Upgrade (paywall)

**Do**

- Feature comparison Free vs Premium  
- Concrete value: “Clear 40 GB Ollama models”, “90-day memory graphs”, “MCP for Cursor”  
- One-time price emphasis  
- Restore license  

**Don’t**

- Block free scan results behind blur  
- Fake countdown discounts  
- Nag on every launch (max soft prompt after successful free clean)  

---

## 6. Interaction patterns

### 6.1 Destructive actions

```
User selects items
    → Bottom bar shows total
    → Primary: "Move X items (Y GB) to Trash"
    → Confirm sheet if Caution items included
    → Progress
    → Success toast: "Moved to Trash · Empty Trash in Finder when ready"
```

### 6.2 Permissions

- In-app illustrated steps (System Settings deep links where allowed)  
- Feature-level gates: “Status → Fans need helper tool”  
- Never open System Settings loops without explanation  

### 6.3 Premium gates

- Locked features show content outline + unlock CTA  
- Prefer **try-once demos** for Status history (optional) over hard walls on everything  
- Free users never lose data they created  

### 6.4 Errors

- Human text + technical detail disclosure  
- Example: “Couldn’t scan ~/Library/Containers. Full Disk Access may be missing.”  
- Offer **Open Settings** / **Retry**  

---

## 7. Motion

| Motion | Spec |
|---|---|
| Screen transitions | System default navigation |
| Treemap zoom | 150–200ms easeOut |
| Metric number changes | Subtle crossfade / content transition |
| Menu bar updates | No animation thrash; update ≤ 1–2 Hz |
| Reduce Motion | Honor accessibility setting; hard cuts |

---

## 8. Content & microcopy

### Voice examples

| Bad (competitors) | Good (Husk) |
|---|---|
| “CRITICAL: 12,482 junk files harming your Mac!” | “12.4 GB regenerable caches found” |
| “Unlock to see threats” | “Developer cleanup is a Premium feature” |
| “Optimize RAM now” | “Memory: 18 GB used · Chrome 4.2 GB” |
| “Secure erase forever” | “Items will be moved to Trash” |
| “Your Mac is dirty” | “Husk found regenerable files you can peel away” |
| — | Empty state: “No husk found. Nice.” |

### Terminology

| Prefer | Avoid |
|---|---|
| Move to Trash | Delete permanently / Shred |
| Regenerable cache | Junk / garbage / infection |
| Review recommended | Dangerous / toxic |
| Free space | Liberated storage score |

---

## 9. Accessibility

- Full VoiceOver on navigation, lists, confirmations  
- Hit targets ≥ 28–32 pt  
- Color never sole safety signal (chips include text + icon)  
- Keyboard: ↑↓ lists, Space select, ⌘⌫ trash where appropriate  
- Dynamic Type where layout allows  

---

## 10. Marketing site design (aligned)

Landing page sections (for later implementation):

1. Hero — one-liner + download + price  
2. Transparency — screenshot of path-level clean  
3. Developer features — Xcode / Ollama / ports / MCP  
4. Comparison table vs CleanMyMac / Mole  
5. Privacy — zero telemetry callout  
6. Pricing — Free / $9.99  
7. FAQ — safety, refund, macOS version  

Visual: product screenshots on subtle grid; no stock “happy office” photos.

---

## 11. Design deliverables checklist

| Asset | Status |
|---|---|
| App icon (macOS 1024 + layers) | To produce |
| SF Symbol set / custom glyphs | To produce |
| Sidebar module icons | To produce |
| Onboarding illustrations | To produce |
| Treemap color mapping | Spec in implementation |
| Marketing screenshots template | Post-MVP |
| Website design | Post-MVP |

---

## 12. Design references (inspiration, not copies)

| Reference | Steal this | Don’t steal |
|---|---|---|
| Mole for Mac | Clean native chrome, module clarity | Exact planetary theme |
| PureMac | Safety messaging rigor | Overly bare utility look |
| iStat Menus / Activity Monitor | Metric credibility | Complexity overload |
| Linear / Raycast | Typography, density, polish | Unrelated product patterns |
| CleanMyMac | — | Fear UX, upsells, fake scores |

---

## 13. Open design decisions

1. Final accent color (warm husk/amber vs soft oat + cool teal for metrics)  
2. Whether free tier menu bar shows branding watermark (recommend: no)  
3. Empty-state illustration: seed/shell peel vs abstract disk layers  
4. App icon concept (stylized husk/seed mark vs minimal geometric H)  
