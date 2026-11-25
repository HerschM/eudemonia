# BUSINESS_LOG.md — Eudemonia Business Work: Handoff, Decisions & Open Questions

> State of the business workstream. Maintained by the orchestrating agent at every stopping point. Contract: [`business/AGENTS.md`](AGENTS.md).

---

## Active Handoff (Read First After Compaction or When Starting a New Business Agent)

- **Workstream opened 2026-11-24** by the user: define a business strategy for Eudemonia. Working model: orchestrator frames, reviews and recommends; `eudemonia-market-researcher` (Sonnet) gathers; `eudemonia-fact-checker` (Haiku) verifies. The user talks only to the orchestrator, who also says when `/compact` is safe.
- **Wave 1 (2026-11-24) is complete and promoted**: five reports in `research/01–05`, 24 load-bearing claims re-checked (16 confirmed, 3 partly confirmed, 1 corrected, 4 unverifiable), facts in `COMPETITIVE_LANDSCAPE.md` Sections 1–10, strategy draft in `STRATEGY.md`.
- **2026-11-25: the user answered the six founder questions, reported the state of the trigger, and proposed a price** (all recorded below). `STRATEGY.md` is now Draft v0.2 and reflects them.
- **Wave 2 (2026-11-25) is complete and promoted**: `research/06` (price level against conversion, voluntary payment, India, Play price mechanics) and `research/07` (Accessibility precedents, closed-testing rule, lock-screen capture routes on Android and iPhone, iPhone model limits). 22 claims re-checked (15 confirmed, 5 partly confirmed, 2 unverifiable, none refuted). Facts in `COMPETITIVE_LANDSCAPE.md` Sections 11–12.
- **The open disagreement (not settled by the user)**: the user proposes US $0.59–0.99 and India ₹19–29 a month, presented as an honour system. The orchestrator's recommendation (`STRATEGY.md` Section 5, v0.3): free capture; Synthesis on a cheap enforced subscription with a lifetime price beside it; US about $1.99 a month with $0.99 tested in a comparable country; India ₹49–99 a month plus a yearly plan; do not plan on $10–15K a month in two quarters; first store release without the Accessibility permission, volume trigger added as a later update; recruit 12 closed-test testers now; check iPhone feasibility early.
- **Evidence the user should weigh, both ways**: low-priced apps convert fewer installs and earn about an eighth per install (cross-app benchmark, not a test); HabitKit earns $28K a month at $1–2 with 25,100 subscribers and about 560K downloads on both platforms.
- **Next**: the user answers the four open questions below and reacts to the v0.3 recommendation. If approved, draft the public-test materials (Play declaration text, demo video script, waiting-list page copy, community posts) — the orchestrator drafts, the user submits and posts. Further research only where a decision needs it (candidates: distribution channels for the first audience; gaps 1, 8 and 9 in `COMPETITIVE_LANDSCAPE.md` Section 10).
- **No subagents are running. Safe to compact.**
- **Engineering questions handed to the user, not investigated here**: (1) Android's rule that a microphone foreground service cannot be created from the background (notification and widget interaction are official exemptions); (2) Android 17 per-app memory limits against a resident 2.5 GB model; (3) whether any capture route records without unlocking; (4) on iPhone, recording from a locked phone and running the model when the app is not in front.

---

## User Decisions (Dated, Final Unless Reopened by the User)

- **2026-11-24**: Business agents work from `PRODUCT_SPEC.md` and `UX.md` only; no effort is spent on code or engineering files.
- **2026-11-24**: A separate business agent contract and memory files are permitted; lower-tier subagents do the gathering; the orchestrator reviews and validates and is the single point of contact.
- **2026-11-25 — Ambition**: start as a profitable solo product; the deeper aim is wide reach — a safe, private but powerful tool that makes people more organised without effort. The user is "not too greedy about money"; a low price that benefits more users is preferred.
- **2026-11-25 — Money and time**: full-time (job left); about one year of runway; target $10–15K monthly recurring revenue within two quarters, then scale.
- **2026-11-25 — Principles**: iPhone will follow once the Android app is live (the reason for Flutter). A licence check over the network is acceptable. "No accounts" is a convenience choice, not a strict rule; open to ideas. **No cloud processing stays, firmly**: the user wants people truly empowered and expects local models to keep improving.
- **2026-11-25 — Distribution**: stores are preferred for the user's convenience and trust; distribution outside the stores is acceptable; no wish to cut Google or Apple out.
- **2026-11-25 — Language**: English only at first.
- **2026-11-25 — First customer**: not certain; pictured as "a lazy person" who dumps thoughts in one place and expects a clean, structured result.
- **2026-11-25 — Launch scope**: launch with Capture and Synthesis only, quickly, to test the market. Both screens are nearly done.

---

## Facts Reported by the User About the Product's Current State (2026-11-25, Not Verified by Business Agents)

- The volume-button trigger works with the screen on and locked; **it does not work with the screen off**.
- The volume-button approach cannot work on iPhone.
- The user doubts the Accessibility use will pass store review.
- Fallbacks being tried: a persistent notification usable on the lock screen, or another lock-screen capture entry point.

---

## Open Questions for the User (Answers Shape the Strategy)

1. **Honour system or subscription?** Does Synthesis keep working for someone who does not pay (a true honour system), or is it locked until payment (a cheap subscription described as a fair price)?
2. **Which gives way: the $10–15K target or the floor price?** At $0.99 a month they do not fit together.
3. **Google Play developer account**: does one exist, and is it personal or an organisation account? (It affects how soon a production launch is possible.)
4. **Public tests**: may the orchestrator draft the materials (the user would submit and post them)?
