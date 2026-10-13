> Historical product plan. Current implementation is documented in README.md and ARCHITECTURE.md. Whole-app MIT licensing supersedes any paid-tier or commercial-license proposals here.

# Competitive Analysis — Husk

Derived from [`research.md`](./research.md). Use this for positioning, feature prioritization, and marketing claims (keep claims honest).

---

## 1. Market structure

```
                    High polish / marketing
                            ▲
                            │
              CleanMyMac    │
                            │
                            │         Mole for Mac
                            │              ●
     Subscriptions ─────────┼──────────────────── One-time / free
                            │
              MacPulse ●    │    ● Husk (target)
                            │
                            │    Burrow ●    PureMac ●
                            │              AppCleaner ●
                            │
                            ▼
                    Technical / minimal UI
```

**Whitespace Husk owns:**  
High technical trust + modern AI/dev workflows + consumer-grade polish + **sub-$10 lifetime**.

---

## 2. Competitor profiles

### 2.1 CleanMyMac (MacPaw)

| Dimension | Detail |
|---|---|
| **Focus** | Comprehensive consumer maintenance |
| **Price** | ~$35–90/year subscription |
| **Privacy** | High telemetry; aggressive marketing |
| **Strengths** | Polished UI, brand awareness, malware module, wide feature surface |
| **Weaknesses** | Cost, distrust among power users, bloat perception, fear UX |
| **Users** | Novice–intermediate consumers |

**Husk response**

- Never compete on malware theater  
- Win on honesty, price, and developer features  
- Use comparison tables that highlight subscriptions vs one-time  

---

### 2.2 Mole for Mac (Tw93) — primary commercial peer

| Dimension | Detail |
|---|---|
| **Focus** | Developer-centric clean + monitor + apps |
| **Price** | $19 one-time, 2 Macs, lifetime updates, 14-day refund |
| **Privacy** | Zero telemetry, local processing |
| **Requirements** | macOS 14+ |
| **Architecture** | Open-source CLI (`mo` / Homebrew) + paid native GUI |
| **UI** | Dark native UI; planetary module metaphors |
| **Strengths** | Trust via OSS CLI, treemap, clean/apps/status/optimize, community love, fair price |
| **Weaknesses (gaps)** | No long-range metrics history (vs Burrow); MCP not productized in commercial app the same way; price still 2× our target; AI artifact depth can be matched/exceeded |

**Key Mole 1.10 capabilities to parity or beat**

| Mole feature | Husk plan |
|---|---|
| Squarified treemap Analyze | Free tier parity |
| Status CPU/GPU/mem/disk/net/battery/fans | Premium advanced sensors |
| Process cost explanations | Premium |
| Low disk / BT battery alerts | Phase 4 |
| Keep Screen On (3 modes) | Phase 4 |
| Menu bar lightweight HUD | Phase 2 |
| Clean by safety + review | Free core |
| Apps uninstall + leftovers | Free core |
| Multi-source updates | Phase 5 |
| Optimize one-tap | Free/basic |

**Husk differentiation vs Mole**

1. **$9.99** vs $19  
2. **SQLite history 30–90d** (Burrow-class)  
3. **MCP-first** AI agent integration  
4. **Port monitor** for devs  
5. **Stricter trash-only / no purgeable fakes** marketing  
6. Deeper **Ollama/LM Studio** profiles  

---

### 2.3 Burrow (caezium)

| Dimension | Detail |
|---|---|
| **Focus** | Open-source GUI wrapper around Mole engine |
| **Price** | Free |
| **Extras** | 90-day SQLite metrics; MCP server for agents |
| **Strengths** | Price (free), history, AI integration, transparency |
| **Weaknesses** | Polish/productization, support, packaging trust for non-devs; depends on Mole engine pin |

**Husk response**

- Productize history + MCP with better UX and docs  
- Don’t rely on Mole engine — own the stack  
- Free tier for acquisition; paid for convenience & depth  

---

### 2.4 PureMac

| Dimension | Detail |
|---|---|
| **Focus** | Extreme safety uninstall/clean |
| **Price** | Free, MIT |
| **Ethics** | Refuses APFS purgeable inflation; `trashItem` only |
| **Strengths** | Moral high ground, simplicity |
| **Weaknesses** | Narrow scope vs full dashboard |

**Husk response**

- **Adopt PureMac ethics as non-negotiable policy**  
- Expand scope without abandoning safety  

---

### 2.5 AppCleaner

| Dimension | Detail |
|---|---|
| **Focus** | Drag-and-drop uninstall + SmartDelete |
| **Price** | Free / donationware |
| **Strengths** | Legacy standard, trusted, minimal |
| **Weaknesses** | Not a system dashboard; limited modern dev cleanup |

**Husk response**

- Free uninstaller must be at least as good for common apps  
- Bundle with treemap so users stay in-app  

---

### 2.6 MacPulse

| Dimension | Detail |
|---|---|
| **Focus** | Rule-based monitoring, plain-English hardware explanations |
| **Price** | ~$11.99+ one-time |
| **Strengths** | Explainability, 1-second session recording |
| **Weaknesses** | Not a cleaner/uninstaller suite |

**Husk response**

- Borrow explainability patterns in Status  
- Don’t need to match every monitor-only feature on day one  

---

## 3. Feature matrix

| Feature | CleanMyMac | Mole | Burrow | PureMac | AppCleaner | MacPulse | **Husk** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Cache cleaner | ✅ | ✅ | ✅ | ✅ | — | — | ✅ Free |
| Safety-sorted review | Partial | ✅ | ✅ | ✅ | — | — | ✅ Free |
| Disk treemap | Partial | ✅ | Partial | — | — | — | ✅ Free |
| App uninstaller | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ Free |
| Leftover heuristics | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ Free |
| Orphan detection | ✅ | Partial | Partial | Partial | — | — | ✅ Prem |
| Dev artifact purge | Weak | Strong | Strong | — | — | — | ✅ Prem |
| Local LLM cleanup | Weak | Medium | Medium | — | — | — | ✅ Prem |
| Live process monitor | ✅ | ✅ | ✅ | — | — | ✅ | ✅ |
| Historical metrics | — | — | ✅ 90d | — | — | Sessions | ✅ Prem |
| Plain-English reasons | Partial | Partial | Partial | — | — | ✅ | ✅ Prem |
| Menu bar HUD | ✅ | ✅ | Partial | — | — | Partial | ✅ |
| Port monitor | — | — | — | — | — | — | ✅ Prem |
| MCP / AI agents | — | — | ✅ | — | — | — | ✅ Prem |
| Malware scanner | ✅ | — | — | — | — | — | — (no) |
| Zero telemetry | ❌ | ✅ | ~ | ✅ | ✅ | ✅ | ✅ |
| Trash-only policy | Mixed | Good | Good | Strict | Good | n/a | **Strict** |
| Price | $$/yr | $19 | Free | Free | Free | ~$12 | **$0 / $9.99** |

---

## 4. Strategic implications

### Must match (table stakes)

- Transparent clean with previews  
- Competent uninstaller  
- Native performance feel  
- Privacy posture as good as Mole/PureMac  

### Must exceed (wedge)

| Wedge | Beats |
|---|---|
| Price $9.99 | Mole, CleanMyMac |
| Metrics history | Mole |
| MCP productization | Mole, CleanMyMac |
| Port tooling | Entire cleaner category |
| AI model artifact UX | Most cleaners |
| No purgeable lies | CleanMyMac-class tools |

### Must refuse (trap features)

- Fake system health scores  
- Subscription-only essential cleaning  
- Scareware malware upsells  
- Electron bloat  

---

## 5. Positioning statement

> **For developers and power users who don’t trust subscription cleaners,**  
> **Husk** peels away caches, leftovers, and build junk with full path-level transparency.  
> **Unlike CleanMyMac**, it never uses fear metrics or annual fees.  
> **Unlike Mole**, it adds long-term metrics history, port tools, and MCP for AI agents — at **$9.99** lifetime.

---

## 6. Competitive monitoring (ongoing)

| Signal | Watch |
|---|---|
| Mole releases | feature parity pressure |
| Burrow MCP tools | AI integration ideas |
| MacPaw campaigns | messaging to counter |
| Apple OS changes | FDA, SMC, notarization |
| New OSS cleaners | ethics + feature inspiration |

Review this doc every major release.
