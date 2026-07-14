# Husk Beta 0.1.0 — Internal

**Build status:** Compiles (Debug, macOS 14+ deployment)  
**Bundle ID:** `dev.mzml.Husk`  
**Sandbox:** Off (required for real Library scans)  
**Hardened Runtime:** On  

---

## What’s in this beta

| Module | Status |
|---|---|
| **Clean** | Mole-inspired targets: caches, Xcode, package managers, **AI agents** (Claude/Cursor/Codex/Gemini), local models, **project artifacts** (node_modules, etc.). Icon-rail UI + detail inspector. |
| **Analyze** | Squarified treemap (Library-first). Drill-down, reveal, trash. |
| **Apps** | List apps, leftover discovery, uninstall to Trash. |
| **Status** | Live CPU / memory / disk / thermal + process table, Quit / Force Quit. Samples only while visible. |
| **Optimize** | Quick Look rebuild; honest “no RAM placebo”; DNS guidance. |
| **Settings** | Full Disk Access check + open System Settings; safety promises. |

### Explicitly not in 0.1.x yet

- Premium licensing / paywall  
- MCP server  
- Port monitor  
- SQLite metric history (long-range graphs)  
- Menu bar HUD  
- Rust scan engine (Swift + `du` for now)  

---

## Run

```bash
cd Husk
open Husk.xcodeproj
# ⌘R in Xcode
```

Or:

```bash
xcodebuild -scheme Husk -configuration Debug -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/Husk-*/Build/Products/Debug/Husk.app
```

---

## First-run checklist

1. **Full Disk Access** — System Settings → Privacy & Security → Full Disk Access → enable **Husk** → relaunch  
2. **Clean → Scan** — confirm sizes look real (compare a folder in Finder Get Info)  
3. Select only **Safe** items → Move to Trash → restore one item from Trash  
4. **Analyze** — open large folders, double-click to drill  
5. **Apps** — pick a non-critical app (or skip deleting); verify leftovers list  
6. Confirm no permanent-delete APIs used (Trash only)  

---

## Performance notes

- Directory sizes use allocated file size resource keys (not full file reads)  
- Analyze does **shallow** walks (top children + one extra level for large dirs) for responsiveness  
- Clean scans known targets, not a full-disk crawl  
- UI work is MainActor; scanning uses actors / detached tasks  
- Large `~/Library/Caches` trees can still take tens of seconds — progress is shown  

---

## Safety notes

- SIP / system paths denied  
- Keychains, Mail, Messages, SSH not offered  
- Nothing auto-selected for delete after scan  
- Caution items (Ollama models, Archives, Preferences leftovers) require conscious selection  

---

## Known limitations

- FDA detection is heuristic (may false-negative)  
- Leftover matching can false-positive on common name tokens — always review paths  
- Treemap is one-level-at-a-time (drill to go deeper), not a full DaisyDisk deep map  
- No update feed / notarized DMG yet  

## Fixes in 0.1.1 (stability)

- Fixed crash `Duplicate values for key: 'user-caches'` after Clean scan / dictionary uniqueness bugs  
- Clean scan no longer hangs forever — concurrent `/usr/bin/du` sizing + safe grouping  
- Analyze no longer freezes on Home — concurrent child sizing, cancel, Library-first default  
- Apps uninstall no longer crashes on duplicate leftover paths  
- App list no longer recursive-sizes every app at once  

---

## Next engineering (beta → 0.2)

1. Parallelize Clean target sizing with TaskGroup  
2. Deeper Analyze on demand with cancel + cache  
3. Orphan leftover detector  
4. Status / process list (read-only)  
5. App icon + onboarding window  
