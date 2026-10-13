> Historical product plan. Proposed features and pricing are not current implementation claims. Whole-app MIT licensing supersedes commercial-license proposals. See the repository README and AUDIT_RESOLUTION.md for verified status.

# Pricing & Go-to-Market — Husk

**Product:** Husk · **Tagline:** Peel the husk.

Commercial model designed to undercut Mole ($19) and destroy CleanMyMac subscription economics while remaining profitable for an indie/small team.

---

## 1. Pricing model

### Structure: Freemium + lifetime license

| Tier | Price | Includes |
|---|---|---|
| **Free** | $0 | Smart Clean (standard caches), squarified Analyze treemap, App Uninstaller, basic Optimize, basic Status summary, Keep Screen On (optional free) |
| **Premium** | **$9.99** one-time | Developer/AI purge profiles, full Status + SMC sensors, 30–90 day history, Network ports, MCP server, advanced menu bar HUD, orphan detector, multi-source update checks, priority updates |

### License terms (v1 proposal)

| Term | Value |
|---|---|
| Devices | 2 Macs per license (Mole parity) |
| Updates | Lifetime for purchased major line (honest policy: all 1.x, fair notice if 2.0 paid) |
| Refund | 14 days via Merchant of Record |
| Account | No account required — license key only |
| Telemetry | None |

### Psychological positioning

| Competitor | Price | Husk message |
|---|---|---|
| CleanMyMac | $35–90 / year | “Stop renting your cleaner.” |
| Mole for Mac | $19 once | “More depth for half the price.” |
| AppCleaner | Free | “Free uninstaller + treemap; pay only for pro power.” |
| Burrow | Free OSS | “Polish + support + MCP + packaging when you want a product.” |

**$9.99** is an impulse price for developers who waste one coffee run debugging disk space.

---

## 2. Optional pricing experiments

| Experiment | When | Notes |
|---|---|---|
| Early bird $6.99 | First 500–1000 licenses | Rewards risk-takers; creates urgency without fake timers |
| Student / OSS maintainer $4.99 | Ongoing | Manual or edu email — keep ops light |
| Family 5-seat $19.99 | Later | Only if support load allows |
| Team seat packs | Later | B2B via Paddle/LS |

**Avoid:** monthly subscriptions as the primary offer. Subscriptions are the enemy narrative.

Optional: “Pay what you want” tip above $9.99 on Gumroad-style — not primary store.

---

## 3. Free vs Premium gate strategy

### Free must be genuinely useful

If free is a demo stub, trust dies. Free should replace AppCleaner for many users.

### What to gate (high willingness to pay)

| Feature | Why users pay |
|---|---|
| Xcode / Simulator / node_modules / Ollama clean | Directly saves 10–50 GB on work machines |
| Historical metrics | Debugs chronic issues; unique vs Mole |
| MCP | AI-native workflow lock-in |
| Ports | Weekly pain for full-stack devs |
| Advanced sensors | Pro monitoring without iStat full price |

### What NOT to gate

| Feature | Why keep free |
|---|---|
| Path-level clean preview | Trust |
| Treemap | Acquisition & viral screenshots |
| Uninstall leftovers | Table stakes vs AppCleaner |
| Safety labels | Ethics |

### Paywall UX rules

- No blurred hostage results after a free scan  
- Soft upsell after a successful free clean: “You freed 4 GB. Unlock developer profiles for Xcode & local AI.”  
- Max one soft prompt per day  

---

## 4. Payment infrastructure

### Decision: Lemon Squeezy (Merchant of Record)

From research comparison:

| Processor | Fees | MoR / tax | License keys | Fit |
|---|---|---|---|---|
| **Lemon Squeezy** | 5% + 50¢ | Yes | Yes | **Best** |
| Paddle | 5% + 50¢ | Yes | Weak native keys | OK later B2B |
| Stripe | 2.9% + 30¢ | No | DIY | Tax/compliance burden |
| Gumroad | 10% + 30¢ | Yes | Yes | Fees too high at $9.99 |

### Unit economics at $9.99

| Item | Amount |
|---|---|
| List price | $9.99 |
| Lemon Squeezy fee (5% + $0.50) | ~$1.00 |
| **Net approx.** | **~$8.99** |
| Apple App Store comparison (30%) | would be ~$7.00 — and sandbox blocks product |

At 1,000 paid licenses ≈ **$9k** net  
At 10,000 ≈ **$90k** net  

Volume is driven by free tier virality + dev communities, not ads first.

### License enforcement (lightweight)

- Keychain-stored key  
- Online validation on activate + periodic  
- Offline grace 14–30 days  
- Device activation count via LS API  
- **No** invasive hardware fingerprint DRM that punishes reinstalls  

---

## 5. Distribution

| Channel | Role |
|---|---|
| Product website | Primary download |
| Direct DMG (Developer ID + notarized) | Install path |
| Sparkle | Updates |
| Homebrew cask | Dev discovery (`brew install --cask`) post-stability |
| Setapp | Optional later — revenue share tradeoff |
| Mac App Store | **Not for v1** (sandbox) |

---

## 6. Go-to-market sequence

### Pre-launch

1. Build in public (Twitter/X, blog): treemap GIFs, “0 telemetry”, before/after GB freed  
2. Waitlist with free beta DMG  
3. Collect 3–5 credible testimonials from beta devs  

### Launch week

| Channel | Angle |
|---|---|
| Hacker News | “Show HN: $9.99 Mac cleaner with MCP for AI agents, no subscription” |
| Reddit r/MacOS, r/macapps, r/swift | Honest comparison; follow self-promo rules |
| Product Hunt | Polished gallery; free tier callout |
| Twitter/X | Demo video: Ollama cleanup + port kill + treemap |
| Chinese Mac communities | Mole users already trained on category (localize later) |

### Message pillars

1. **Safety** — Trash only, no fake junk  
2. **Developer depth** — Xcode, Node, local LLMs  
3. **AI agents** — MCP  
4. **Fair price** — $9.99 lifetime  
5. **Privacy** — zero telemetry  

### Anti-messages

- Don’t smear Mole personally — differentiate features/price  
- Don’t claim “best antivirus”  
- Don’t fake urgency countdowns  

---

## 7. Support & ops cost control

| Area | Approach |
|---|---|
| Support | Email + public FAQ; canned replies for FDA / permissions |
| Docs | In-app tips + website docs |
| Refunds | MoR handles payment refunds; revoke key |
| Tax | MoR |
| Analytics | Sell-side only: LS sales dashboard — **not** user behavior telemetry |

Target: < 5 minutes support per paid user lifetime average.

---

## 8. Financial scenarios (illustrative)

### Conservative year 1

| Input | Value |
|---|---|
| Unique downloads | 20,000 |
| Free→paid conversion | 3% |
| Paid licenses | 600 |
| Net @ ~$9 | ~$5,400 |

### Base year 1

| Input | Value |
|---|---|
| Downloads | 80,000 |
| Conversion | 4% |
| Paid | 3,200 |
| Net | ~$28,800 |

### Upside year 1 (HN + PH hit)

| Input | Value |
|---|---|
| Downloads | 250,000 |
| Conversion | 5% |
| Paid | 12,500 |
| Net | ~$112,000 |

Costs: Apple dev ($99), domain, notarization infra, time. Low COGS software.

---

## 9. Pricing policy changelog (living)

| Version | Change |
|---|---|
| 0.1 | $9.99 lifetime premium; free core tools; 2 devices; LS MoR |

Future price increases apply to **new** buyers only; grandfather early adopters when possible.

---

## 10. Open commercial decisions

1. Exact early-bird count and price  
2. Whether menu bar full metrics are free acquisition or premium  
3. Lifetime definition for 2.0 major rewrite  
4. Name trademark search before paid ads  
