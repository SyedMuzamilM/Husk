# Research Review — Audit of `research.md`

This is a critical pass over the original strategic analysis: what holds, what to tighten, and what decisions we locked into product docs.

---

## Overall verdict

**Strong research.** Suitable as a foundation for building. Market framing, competitor map, technical mechanisms (SMC, uninstall heuristics, developer artifacts), and commercial stack (SwiftUI/Rust, Lemon Squeezy, freemium at $9.99) are coherent and actionable.

**Grade:** A− (strategy) / B+ (needs validation of live competitor claims before marketing copy ships)

---

## What is solid

| Area | Assessment |
|---|---|
| **Market insight** | Correct: power users reject CleanMyMac-style subscriptions and opacity |
| **Competitor set** | Mole, CleanMyMac, AppCleaner, Burrow, PureMac, MacPulse — good coverage |
| **Whitespace** | History + MCP + dev/AI purge + polish + low one-time price is real |
| **Tech direction** | Native SwiftUI + Rust engine + no Electron is the right default |
| **Safety ethics** | Trash-only / no purgeable fakes aligns with trust-sensitive buyers |
| **Distribution** | Direct + MoR (not App Store) is correct for this category |
| **MoR choice** | Lemon Squeezy fits indie license-key + tax handling |
| **Artifact targets** | Xcode DerivedData, simulators, node_modules, Ollama, LM Studio — high-value |

---

## Gaps and cautions

### 1. Competitor facts need live verification

Research cites Mole **$19 / 2 devices / macOS 14+ / zero telemetry** and Burrow’s **90-day SQLite + MCP**. These should be re-checked against live sites/changelogs before public comparison tables. Pricing and features move.

**Action:** Re-verify at launch; keep [`COMPETITIVE.md`](./COMPETITIVE.md) as living doc.

### 2. “Better for $9.99” is ambitious on scope

Shipping Mole parity **plus** Burrow history **plus** MCP **plus** ports **plus** superior polish at half price is a **multi-phase** product, not an MVP.

**Action:** Locked in [`ROADMAP.md`](./ROADMAP.md) — MVP is free Clean + Treemap + Uninstall only.

### 3. Community evidence is thin

HN/thread-style engagement (~18 replies) is directional, not proof of large TAM. Chinese-speaking Mole community is a useful GTM clue, not a full market study.

**Action:** Treat as qualitative; measure real conversion post-beta.

### 4. SMC / IOReport complexity underestimated in prose

Reading fans/power/GPU via IOKit/SMC/IOReport on Apple Silicon is fragile across hardware generations and may need a privileged helper. Research is directionally right; implementation cost is non-trivial.

**Action:** Advanced sensors deferred to Phase 4; basic Status first ([`ROADMAP.md`](./ROADMAP.md)).

### 5. Legal / policy surface

- Notarization, Full Disk Access messaging, and uninstaller false positives are liability/reputation risks.  
- Trademark for final name not researched in source doc.  
- “Lifetime updates” promises need careful wording for 2.0.

**Action:** [`SAFETY.md`](./SAFETY.md), [`NAME_AND_BRANDING.md`](./NAME_AND_BRANDING.md), [`PRICING.md`](./PRICING.md).

### 6. Open-source hybrid not decided

Mole’s trust flywheel is OSS CLI + paid GUI. Research suggests studying it but the blueprint also implies a closed custom Rust core.

**Action:** Architecture recommends **custom core** for license clarity; optional OSS later ([`ARCHITECTURE.md`](./ARCHITECTURE.md) §13).

### 7. MCP security

Exposing cleanup to agents is powerful and dangerous. Research under-specifies approval UX.

**Action:** Human-in-the-loop required ([`SAFETY.md`](./SAFETY.md) §8, [`FEATURES.md`](./FEATURES.md) §10).

### 8. Unit economics optimism

$9.99 × high volume works only with strong free-tier distribution. Research’s strategy is sound; acquisition cost of Mac utility users can still be non-zero if relying on ads.

**Action:** Community-led GTM first ([`PRICING.md`](./PRICING.md) §6).

---

## Decisions taken from research → product docs

| Research recommendation | Decision |
|---|---|
| SwiftUI + Rust | Adopted |
| SQLite 30–90d history | Premium; 30d MVP → 90d later |
| MCP stdio | Premium, Phase 4 |
| Lemon Squeezy | Primary MoR |
| $9.99 lifetime freemium | Adopted |
| Free uninstaller + treemap | Adopted |
| Trash never shred | Policy |
| No App Store v1 | Adopted |
| Port monitor | Premium differentiator |
| Keep Screen On / alerts | Phase 4 |
| Product name | **Husk** (locked) · domains `husk.fit` / `huskmac.com` to register |

---

## Recommended validations before writing code-heavy investment

1. Manually use Mole (trial) + AppCleaner + note missing workflows on your machine  
2. Measure your own reclaimable GB from DerivedData / Ollama / node_modules (marketing proof)  
3. Domain + name clearance  
4. Spike: Rust directory size walk of `~/Library` bridged to SwiftUI list (1–2 days)  
5. Spike: Lemon Squeezy license activate in a dummy app  

---

## Conclusion

`research.md` is a **credible blueprint**, not vapor. The main risk is **scope compression** — trying to out-feature Mole and Burrow on day one. Product docs intentionally sequence delivery so trust-critical free tools ship first, then paid wedges (history, dev/AI, MCP, ports).

Proceed to Phase 0 in [`ROADMAP.md`](./ROADMAP.md).
