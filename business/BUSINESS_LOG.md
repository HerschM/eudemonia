# BUSINESS_LOG.md — Eudemonia Business Work: Handoff, Decisions & Open Questions

> State of the business workstream. Maintained by the orchestrating agent at every stopping point. Contract: [`business/AGENTS.md`](AGENTS.md).

---

## Active Handoff (Read First After Compaction or When Starting a New Business Agent)

- **Workstream opened 2026-11-24** by the user: define a business strategy for Eudemonia. First step requested: detailed research into the business models of similar companies, large (e.g. Wispr Flow) and small (e.g. AudioPen).
- **Working model**: orchestrator frames, reviews and recommends; `eudemonia-market-researcher` (Sonnet) gathers; `eudemonia-fact-checker` (Haiku) verifies. The user talks only to the orchestrator. The orchestrator tells the user when `/compact` is safe.
- **Research wave 1 (launched 2026-11-24)** — five briefs, reports land in `business/research/`:
  1. `01_voice_dictation_platforms.md` — Wispr Flow, Superwhisper, Willow, Aqua Voice, Typeless, MacWhisper, VoiceInk (+ Android finds).
  2. `02_indie_voice_note_apps.md` — AudioPen, Voicenotes, TalkNotes, Cleft, Letterly, Whisper Memos, Voicepal, Oasis (+ finds).
  3. `03_ai_memory_meeting_journaling.md` — Otter, Granola, Limitless, Bee, Plaud, Rosebud, Day One, Mindsera, Mem, Reflect, Notion AI.
  4. `04_local_first_monetization_precedents.md` — Obsidian, FUTO, Private LLM, PocketPal, MacWhisper, Hyprnote, Standard Notes etc.; subscription benchmarks; licensing without accounts.
  5. `05_platform_incumbents_policy_risk_market.md` — Google / Samsung / Nothing free features; Google Play accessibility and foreground-service policy; sideloading restrictions; fees; addressable devices; willingness to pay.
- **Status (2026-11-24, end of first session)**: wave 1 complete. All five reports reviewed by the orchestrator; 24 load-bearing claims re-checked by two independent fact-checkers (16 confirmed, 3 partly confirmed, 1 corrected, 4 unverifiable — see status codes in `COMPETITIVE_LANDSCAPE.md`). `COMPETITIVE_LANDSCAPE.md` written (facts, sections 1–10). `STRATEGY.md` draft v0.1 written (diagnosis, positioning, seven model options, conditional recommendation, arithmetic, risks, hypotheses, product proposals).
- **Current recommendation (not decided by the user)**: capture and transcription free for ever; one-time unlock for Synthesis at $25–40 after a trial; Google Play first; later stages as later separate unlocks. Confidence moderate; hybrid annual + lifetime is the fallback. The business question is distribution, not pricing.
- **Largest risk found**: the trigger depends on Android's Accessibility API — Play approval is discretionary and Android 17 Advanced Protection blocks it for users who enable it. Cheapest test: put a build through Play closed-testing review early.
- **Two engineering questions surfaced, handed to the user, not investigated here**: (1) Android's rule that a microphone foreground service cannot be created from the background; (2) Android 17 per-app memory limits against a resident 2.5 GB model.
- **Next**: the user answers the founder questions below and reacts to the product proposals in `STRATEGY.md` Section 9 → revise the recommendation → wave 2 research only where a decision needs it (candidates: gaps 1, 3 and 7 in `COMPETITIVE_LANDSCAPE.md` Section 10; distribution channels for audience 1).
- **Subagent definitions** `eudemonia-market-researcher` and `eudemonia-fact-checker` are registered and were used for the fact-check.

---

## User Decisions (Dated, Final Unless Reopened by the User)

- **2026-11-24**: Business agents work from `PRODUCT_SPEC.md` and `UX.md` only; no effort is spent on code or engineering files.
- **2026-11-24**: A separate business agent contract and memory files are permitted; lower-tier subagents do the gathering; the orchestrator reviews and validates and is the single point of contact.

---

## Open Questions for the User (Answers Shape the Strategy)

1. **Ambition**: a profitable solo/indie product, a venture-scale company, or an open-source / reputation project?
2. **Money and time**: is this full-time; how long can it run without revenue; is there a revenue target and date?
3. **Which principles are negotiable for business reasons**: zero outbound bytes (even for licence checks or opt-in crash reports), no accounts, Android-only, no cloud option ever?
4. **Distribution**: is Google Play a requirement, or is direct sale (APK from a website) acceptable?
5. **Geography and language**: which markets first (speech model languages limit this)?
6. **Who is the first customer in the user's own mind**: the founder persona, the journaler, or the task capturer?
