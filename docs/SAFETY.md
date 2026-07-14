# Safety & Trust Policy — Husk

Non-negotiable product rules. If a feature conflicts with this document, change the feature.

---

## 1. Core tenets

1. **Show before you act** — Users see exact paths and sizes before any cleanup.  
2. **Trash, never shred** — User data deletion uses `FileManager.trashItem` (or equivalent Trash).  
3. **No fake junk** — Never count APFS purgeable space, Time Machine locals, or iCloud placeholders as “cleaned junk.”  
4. **Default to conservative** — Risky items start unchecked.  
5. **SIP is sacred** — Protected system paths are never selectable for delete.  
6. **Local by default** — File lists and metrics do not leave the device.  
7. **Agents don’t get a blank check** — MCP mutations require human approval.

---

## 2. Safety labels

| Label | Definition | Default selection | Delete allowed |
|---|---|---|---|
| **Safe** | Regenerable caches/logs with low regret | User preference (off by default recommended) | Yes → Trash |
| **Review** | Likely OK but may reset app state | Off | Yes → Trash after user opt-in |
| **Caution** | May include user-generated or hard-to-replace data | Off + extra confirm | Yes only after confirm sheet |
| **Protected** | OS/SIP/critical | N/A | No |

Every row in Clean/Uninstall must show a label and a short reason (e.g. “Browser cache — recreated automatically”).

---

## 3. Path deny list (minimum)

Never offer for deletion (extend during implementation):

- Anything under SIP-protected system locations  
- `/System`, `/usr` (except documented safe caches if any — default deny)  
- Keychains, passwords, mail indexes without explicit expert mode (v1: deny)  
- User home root blanket deletes  
- Active project source trees (only known artifact dirs like `DerivedData`, `node_modules`)  

Developer profiles must target **known artifact directories**, not “delete large folders in ~/code.”

---

## 4. Deletion rules

| Rule | Detail |
|---|---|
| API | Trash only in v1 |
| Batch | Partial failure reported; continue when safe |
| Undo | “Undo” = restore from Trash (Finder); communicate that |
| Empty Trash | User responsibility; we may remind, never force |
| Admin | Only for OS-required maintenance tasks, never for casual cache clean |

---

## 5. Uninstaller rules

- Never remove another app’s files without bundle/team/path correlation confidence  
- Prefer false negatives (leave leftover) over false positives (delete wrong app data)  
- Show confidence / match reason in UI when possible  
- System apps / Apple-protected apps: uninstall disabled or strongly warned  

---

## 6. Developer & AI adapters

| Adapter | Hard rule |
|---|---|
| Xcode | Do not touch source projects; only DerivedData/Archives/DeviceSupport as opted |
| Simulator | Prefer `xcrun simctl` over raw directory deletes when mutating devices |
| node_modules | Only directories explicitly listed from scan results |
| Ollama / LM Studio | Prefer manifest-aware orphan detection; warn before removing models |

---

## 7. Monitoring & helper

- Privileged helper exposes **read-only metrics** APIs only (v1)  
- No remote shell, no arbitrary command execution endpoint  
- Process kill requires confirm for Force Quit  

---

## 8. MCP / AI agent policy

| Operation | Policy |
|---|---|
| Read disk free, list processes, list safe targets | Allowed (licensed) |
| Propose cleanup set | Allowed |
| Execute cleanup | **Human confirmation** in UI (or explicit typed confirm policy) |
| Kill process | Human confirmation |
| Export file contents to agent | **Not provided** (paths/sizes only) |

Log agent-initiated proposals/actions locally for user audit.

---

## 9. Communications policy

### Allowed claims

- “Preview every file before cleaning”  
- “Moves items to Trash”  
- “No telemetry”  
- “Does not count purgeable space as junk”  

### Forbidden claims

- “Makes your Mac X% faster” without evidence  
- “Removes viruses” (out of scope)  
- “Secure erase / military wipe”  
- Inflated GB numbers from non-junk sources  

---

## 10. Incident response

If a user reports wrong-file deletion:

1. Treat as **P0**  
2. Reproduce with path rules  
3. Patch classifier; add regression fixture  
4. Improve confirm UX if needed  
5. Document in release notes  

---

## 11. Alignment with open-source ethics

Husk intentionally aligns with **PureMac**-style safety and **Mole**-style transparency, while rejecting **CleanMyMac**-style fear marketing.

See [`COMPETITIVE.md`](./COMPETITIVE.md) and [`research.md`](./research.md).
