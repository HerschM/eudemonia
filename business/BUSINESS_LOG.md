# BUSINESS_LOG.md — Eudemonia Business Work: Handoff, Decisions & Open Questions

> State of the business workstream. Maintained by the orchestrating agent at every stopping point. Contract: [`business/AGENTS.md`](AGENTS.md).

---

## Active Handoff (Read First After Compaction or When Starting a New Business Agent)

- **Workstream opened 2026-11-24** by the user: define a business strategy for Eudemonia. Working model: orchestrator frames, reviews and recommends; `eudemonia-market-researcher` (Sonnet) gathers; `eudemonia-fact-checker` (Haiku) verifies. The user talks only to the orchestrator, who also says when `/compact` is safe.
- **Wave 1 (2026-11-24) is complete and promoted**: five reports in `research/01–05`, 24 load-bearing claims re-checked (16 confirmed, 3 partly confirmed, 1 corrected, 4 unverifiable), facts in `COMPETITIVE_LANDSCAPE.md` Sections 1–10, strategy draft in `STRATEGY.md`.
- **2026-11-25: the user answered the six founder questions, reported the state of the trigger, and proposed a price** (all recorded below).
- **Wave 2 (2026-11-25) is complete and promoted**: `research/06` (price level against conversion, voluntary payment, India, Play price mechanics) and `research/07` (Accessibility precedents, closed-testing rule, lock-screen capture routes on Android and iPhone, iPhone model limits). 22 claims re-checked (15 confirmed, 5 partly confirmed, 2 unverifiable, none refuted). Facts in `COMPETITIVE_LANDSCAPE.md` Sections 11–12.
- **2026-11-25 (second reply): the user settled the pricing disagreement and reset the brief** — one-time lifetime price, no honour system, target kept, organisation Play account, drafting of public-test materials approved (all recorded under User Decisions). The earlier v0.3 recommendation (cheap subscription) is superseded.
- **`STRATEGY.md` is v0.4 (clean rewrite, 2026-11-25)** and is the current plan: lifetime price $39.99 with a $29.99 launch offer; usage-based Synthesis trial built in the app; target = 335–500 sales a month (11–17 a day); quiet release 30 Nov → public Android launch about mid-January → one repeatable channel by end of February (tripwire: about 100 sales a month and 100+ installs a day from one source) → iPhone in March–April → 335+ sales a month by May. Channels ranked: founder posting in public, founder-filmed short video, store search, communities, personal outreach; Product Hunt saved for iPhone; no paid installs or paid influencers. Metrics: `STRATEGY.md` Section 8.
- **Orchestrator's stated judgement (the user has heard it and kept the target)**: reaching $10–15K a month within six months is unlikely and not impossible; it needs both a repeatable channel and iPhone inside the window. The tripwires exist to find out early.
- **Wave 3 (2026-11-25) is complete and promoted**: `research/08` (acquisition channels, base rates), `research/09` (one-time pricing, trials, store terms) and a direct check of Play submission requirements. 32 claims re-checked (23 confirmed, 9 partly confirmed, none refuted). Facts in `COMPETITIVE_LANDSCAPE.md` Sections 13–15. Notable: RevenueCat's Google Play conversion figure contradicts itself (0.9% or 2.6%); no conversion data exists for one-time unlock apps; the battery-optimisation exemption has no voice-recording use case in Google's policy table.
- **Launch drafts** are under `business/launch/` (written by a Sonnet subagent on 2026-11-25, reviewed by the orchestrator — see the review note at the top of each file or the status line below). Nothing has been posted, submitted or sent. No demo video is to be made until the app is ready (script only).
- **2026-11-25 (fourth reply): the five open questions are answered** (recorded under User Decisions and Facts). `STRATEGY.md` is now **v0.5**: the paywall is not built, so the recommended first release ships with Synthesis free as "early access" (Phase 0a) and the paywall follows about mid-December (Phase 0b), with real purchases required before the January push; trial = 10 Synthesis sessions with three guards; no audience, so communities, Show HN and store search carry the January push; the orchestrator recommended **against** committing to the Action screen or an iPhone date before January (iPhone: feasibility check first, February realistic if clean). The user is reading the launch drafts and will come back with comments; trial and price placeholders in `launch/` are still unfilled until the user confirms the number and the early-access wording.
- **Next**: the user decides the open questions below → fill placeholders in the drafts → the user submits to Play. After release: weekly review of the Section 8 numbers against the tripwires. Research only where a decision needs it (candidates: reading Play listings on a real phone for rivals' Android prices; iPhone feasibility is engineering).
- **Engineering questions handed to the user, not investigated here**: (0) whether the first release should request the battery-optimisation exemption at all, given Play's policy (`COMPETITIVE_LANDSCAPE.md` Section 15); whether the build uses Play Billing Library 8 or newer; (1) Android's rule that a microphone foreground service cannot be created from the background (notification and widget interaction are official exemptions); (2) Android 17 per-app memory limits against a resident 2.5 GB model; (3) whether any capture route records without unlocking; (4) on iPhone, recording from a locked phone and running the model when the app is not in front.

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
- **2026-11-25 (second reply) — Stance**: "I'm here to learn business and do business"; open to ideas, including a pivot. Prefers step-by-step validation through an early launch over perfecting the product without user insight.
- **2026-11-25 (second reply) — Price model**: a one-time lifetime purchase at a higher price point ($35–45; the orchestrator to give the number). **The honour system is dropped.** Synthesis does not work for someone who has not paid.
- **2026-11-25 (second reply) — Target kept**: $10–15K a month within two quarters is **not** dropped; the strategy must be designed to reach it and must scale in the long run.
- **2026-11-25 (second reply) — iPhone**: will launch on Apple soon, "since that is the paying market".
- **2026-11-25 (second reply) — Direct sale of the APK**: acceptable, but can wait until sales pick up.
- **2026-11-25 (second reply) — Cloud**: now open to cloud transcription or letting users add their own API key, but believes that space is overcrowded and offers no moat; saw "fully local + lifetime price" as the moat. Open to ideas. (Supersedes "no cloud stays, firmly" as an absolute; the preference for local remains.)
- **2026-11-25 (second reply) — Google Play account**: exists, approved as an **organisation** account, so the 12-tester closed-test rule does not apply.
- **2026-11-25 (second reply) — Public-test materials**: the orchestrator may draft them. **No demo video with the current app** (not ready). **No official posting or communication anywhere without informing the user.**
- **2026-11-25 (second reply) — Launch**: Capture and Synthesis as soon as possible.
- **2026-11-25 (third reply) — Target definition**: monthly revenue (not recurring) is accepted as the reading of the $10–15K target; the user accepts it will fluctuate and asked for any further metrics worth tracking.
- **2026-11-25 (third reply) — Launch date**: Google Play launch aimed at the end of November 2026 (about 2026-11-30), with two to three days of buffer (about 2026-12-03).
- **2026-11-25 (third reply) — First release without the Accessibility permission**: notification and widget only; the volume trigger comes in a later update. The launch must not be held up.
- **2026-11-25 (third reply) — Sequence after launch**: set up a daily marketing routine → start the iPhone version immediately → the remaining stages (Insights, Action) after the iPhone launch.

- **2026-11-25 (fourth reply) — Release shape**: quiet release now, public push in the first two weeks of January 2027 (the user likes the new-year timing).
- **2026-11-25 (fourth reply) — Price and trial**: $39.99 list with a $29.99 launch offer, agreed. Trial counted in **Synthesis sessions**, about 10–15. A session is one automatic run (triggered after *x* notes and *y* minutes since the last run, when thoughts are pending) over everything pending; ten thoughts becoming three notes in different folders is one session.
- **2026-11-25 (fourth reply) — Raised, not decided**: the user feels the Action tab should exist by the January push ("from raw thoughts to actions is what we would be able to sell even better") and asked whether iPhone should launch by the end of January instead of March–April. The orchestrator recommended against committing to either (`STRATEGY.md` Section 7); awaiting the user's decision.

---

## Facts Reported by the User About the Product's Current State (2026-11-25, Not Verified by Business Agents)

- **Fourth reply**: the paywall (purchase, trial counter, locked Synthesis) is **not started**. The Play developer account is created, approved and the $25 fee paid; nothing further is known to be set up for payments. The user has **no existing audience** anywhere.
- The volume-button trigger works with the screen on and locked; **it does not work with the screen off**.
- The volume-button approach cannot work on iPhone.
- The user doubts the Accessibility use will pass store review.
- Fallbacks being tried: a persistent notification usable on the lock screen, or another lock-screen capture entry point.

---

## Open Questions for the User (Answers Shape the Strategy)

Asked 2026-11-25 after the fourth reply (the earlier five are answered and recorded above):

1. **Ship the first release with Synthesis free ("early access") and add the paywall about mid-December?** (Recommended; the alternative is to delay the release until the paywall exists.)
2. **Do early-access users keep Synthesis for free once the paywall arrives?** (Recommended: yes.)
3. **Trial = 10 sessions, with the three guards** in `STRATEGY.md` Section 5?
4. **Action and iPhone before January**: accept the recommendation (neither committed; iPhone feasibility check in the week after release), or overrule it?
5. **What does Play Console show under Settings → Payments profile?** (Decides how much setup remains before anything can be sold.)
