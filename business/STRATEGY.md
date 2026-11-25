# STRATEGY.md — Eudemonia Business Strategy (Positioning, One-Time Price, Growth Plan to the Revenue Target, Risks & Tests)

> **Status**: v0.5, 2026-11-25 (v0.4 plus the user's fourth reply: price and quiet release agreed, paywall not yet built, no existing audience). Clean rewrite after the user's decisions of 2026-11-25 (dated in [`BUSINESS_LOG.md`](BUSINESS_LOG.md)) and research waves 1–3. Facts live in [`COMPETITIVE_LANDSCAPE.md`](COMPETITIVE_LANDSCAPE.md) and are cited as `[CL §n]`, never restated as new facts. Everything here that is not marked **Decided** is the orchestrator's recommendation or hypothesis.

---

## 1. Decisions That Frame the Strategy (Made by the User, 2026-11-25)

- **Decided — model**: capture and transcription free for ever; Synthesis locked behind **one lifetime purchase**. No honour system, no subscription.
- **Decided — target**: $10–15K of **monthly revenue** (not recurring) within two quarters, i.e. by about the end of May 2027; the approach must scale beyond that.
- **Decided — launch**: Capture + Synthesis on Google Play at the end of November 2026 (buffer to about 3 December), from an organisation developer account; **first release without the Accessibility permission** (notification and widget capture only), volume trigger in a later update.
- **Decided — sequence**: Android release → daily marketing routine → iPhone → Insights and Action.
- **Decided — boundaries**: English only; direct sale outside the stores deferred; cloud processing or bring-your-own-key not ruled out in principle, not planned; nothing is posted or sent publicly without the user being informed.
- **Decided — price and trial (fourth reply)**: $39.99 list, $29.99 launch offer, usage-based trial counted in **Synthesis sessions** (one automatic run over all pending thoughts, whatever number of notes it produces), about 10–15.
- **Decided — release shape (fourth reply)**: quiet release now, public push in the first half of January 2027.
- **Reported by the user (fourth reply)**: the paywall is not started; the payments profile's status is unknown; there is no existing audience.
- **Open**: whether the quiet release ships with Synthesis free (Section 7, recommended); the exact trial number (Section 5, recommended 10); whether Action and iPhone are attempted before the January push (Section 7, recommended against committing to either).

---

## 2. Strategic Diagnosis (What the Evidence Says About Eudemonia's Position)

1. **The paying customer for this outcome exists, mostly on cloud products and mostly on iPhone.** "Ramble and get clean notes" sells at $40–100 a year `[CL §3]`. Google Play converts fewer installs into payers than the App Store — by how much is unclear, because the main benchmark contradicts itself (0.9% or 2.6% against 2.6–2.9%) `[CL §13]` — and Android carries about 15% of subscription revenue `[CL §8]`.
2. **Zero marginal cost is the one structural advantage.** Cloud rivals pay for every minute processed, and those that sold lifetime access withdrew or repriced it `[CL §2, §3]`. A one-time price is something they cannot match without losing money. This is a **position that is expensive for rivals to copy, not a moat**: other on-device apps can match it, and platform owners can give the outcome away `[CL §5]`.
3. **Privacy is a reason to trust, not yet a proven reason to buy.** No evidence was found that "no network" drives purchases of voice-capture products `[CL §9]`. It supports the pitch; the outcome leads it.
4. **The base rates are hard.** 4.6% of new subscription apps reach $10K a month within two years; the directly comparable on-device Android voice app drew almost no attention at launch; no solo, Android-only, one-time-priced app reaching $10K a month in 2024–2026 was found `[CL §13]`. The fast cases (AudioPen, Voicenotes) had an existing audience, a web or iPhone product and a limited lifetime offer `[CL §13]`.
5. **The hardware trigger is no longer the identity.** It does not work with the screen off today (user's report), cannot exist on iPhone, and its store approval can take weeks `[CL §12]`. It becomes a later enhancement.
6. **The squeeze from platform owners will grow** `[CL §5]`. What they do not offer today: any phone, no account, nothing leaving the device, pay once.

---

## 3. Positioning (Category, Promise & Proof)

- **Category**: thought capture — not dictation into a text box, not meeting notes, not a journal.
- **Promise**: *"Ramble. Get clean, organised notes. Nothing leaves your phone."*
- **Proof points, in order**: the before/after of one real ramble; "pay once — nothing runs on our servers, so there is nothing to rent"; works with no signal; no account.
- **Wording rules**: say "your recordings and notes never leave your phone", not "no internet permission" (the app uses Google Play for the purchase, and whether billing needs that permission is unsettled `[CL §14]`). Do not advertise pocket or screen-off capture. Be plain about the 8 GB requirement and the 2.5 GB download.

---

## 4. Target Customer Sequence (Who First, Who Later, Who Not)

| Order | Customer | Why this order | Weakness |
| :--- | :--- | :--- | :--- |
| 1 (the user's picture) | **The "lazy dumper"**: talks thoughts into one place, expects a clean structured result | The customer cloud voice-note apps already sell to `[CL §3]`; Capture + Synthesis is exactly the need. | No single gathering place; compares output with cloud models; many are on iPhone. |
| 1b (how to reach the first of them) | **Builders and thinkers on high-end Android**; on-device-AI and local-first enthusiasts | Own 8–12 GB phones, understand "runs locally", gather in reachable communities. | Small; expects export to their own note system; communities restrict self-promotion `[CL §13]`. |
| 2 | **Private journalers** | Proven willingness to pay `[CL §4]`; privacy matters most. | Needs Insights; likely iPhone-heavy (unverified). |
| 3 | **Professionals bound by confidentiality** | The only segment where "nothing leaves the phone" removes a legal obstacle. | Needs sales effort and iPhone. A later bet. |
| Not now | **Rapid task capturers** | — | Competes with free assistants; weakest willingness to pay. |

---

## 5. Price, Trial & Launch Offer (Recommendation; the Number the User Asked For)

- **List price: $39.99, once.** Anchors `[CL §14]`: one-time prices of comparable apps with organised output sit at about $39–60 (FluidVox $39, Notability Classic $39.99–49.99, Daylio $59.99); plain on-device transcription apps sit at $5–10, which is why transcription is the free part; one year of the nearest on-device rival costs $39.99 `[CL §3]`. The message writes itself: *what others charge every year, once.*
- **Launch offer: $29.99 until the end of the public launch period**, with a stated end date, as a discount offer on the same product. Limited lifetime offers are what produced fast early sales for AudioPen and Voicenotes `[CL §13]`. Never extend it silently; early buyers keep everything.
- **iPhone, later**: $39.99–49.99; Apple keeps 15% under its small-business programme `[CL §14]`.
- **India**: about ₹999–1,499. Expect little income `[CL §11]`.
- **Trial — usage-based, built in the app**: Google Play has no free trial for one-time products `[CL §14]`. The unit is the **Synthesis session** (user's definition: one automatic run over the pending thoughts; ten thoughts becoming three notes is one session), not a number of days, so that nobody's trial runs out during the model download or an idle week. No evidence exists on which trial design converts better for one-time apps `[CL §14]`; what follows is judgement. An on-device counter can be reset by reinstalling; accept that leakage.
  - **Recommended number: 10 sessions.** The user offered 10–15; the lower end asks for the decision while interest is fresh, and the number can be raised later without upsetting anyone (lowering it cannot).
  - **Weakness of counting sessions, and the guards against it**: sessions start automatically, so a person who records one thought at a time uses up the trial on ten single thoughts, and a session can be spent while the user is not looking. Guards (proposals): a session counts only if it produced or changed a note; the remaining count is always visible on the Synthesis screen; the trial never ends before the user has opened at least one synthesized note. A floor in days ("never before day 7") was considered and set aside as one rule too many for the first build.
  - **After the trial**: recording and transcription continue and thoughts queue up unsynthesized. The visible backlog is the strongest reason to buy; say so on the paywall ("12 thoughts are waiting").
- **Paywall placement**: never between the user and a recording. It appears only when Synthesis is asked for after the trial.
- **Price test**: Play's built-in experiment (one variant, $49.99 against $39.99) once volume allows; at low volume it returns nothing `[CL §14]`. Compare revenue per install, not buyer counts.
- **Confidence**: moderate on $39.99 as a starting point; low on any claim about conversion, because no published conversion rate for one-time unlocks exists `[CL §14]`.

**Options considered and set aside** (history of v0.1–v0.3): honour system — a few per cent pay at most `[CL §11]`, dropped by the user; floor-price subscription ($0.59–0.99 a month) — needs 12,000–30,000 subscribers for the target and low-priced apps convert fewer installs, not more `[CL §11]`; cheap subscription with lifetime beside it (v0.3) — superseded by the user's choice; annual subscription — no server cost to justify it and it blurs the "pay once" position; paid backup or sync service — the only proven recurring line for local-first products `[CL §7]`, kept for later; hardware button bundle and venture-scale company — out of proportion to a solo launch.

---

## 6. Revenue Arithmetic Against the Target (Ranges and Base Rates, Not Forecasts)

Net per sale: about **$30** on Google Play at $39.99 (Play keeps 25% in the US, UK and EEA `[CL §6]`), about **$22.50** at the launch offer, about **$34** on iPhone. The target is therefore about **335–500 sales a month — 11 to 17 a day**.

| Case | Buyers per 100 installs | Revenue per install | Installs a month for $10K |
| :--- | ---: | ---: | ---: |
| Google Play median for subscription apps, lower of the report's two figures `[CL §13]` | 0.9 | ≈ $0.27 | ≈ 37,000 |
| Same, higher of the two figures `[CL §13]` | 2.6 | ≈ $0.78 | ≈ 12,800 |
| Apps whose best-selling plan is lifetime `[CL §14]` | — | $0.24 | ≈ 42,000 |
| Planning case, Android | 2 | ≈ $0.60 | ≈ 16,700 |
| Strong case, Android | 4 | ≈ $1.20 | ≈ 8,300 |
| App Store median `[CL §13]`, at $34 net | 2.6 | ≈ $0.88 | ≈ 11,300 |

**Reading.** The benchmarks describe subscription apps, so they are a guide, not a measurement; our own number will be known within weeks of release. On Android alone the target needs roughly 13,000–40,000 installs a month on phones that can run Synthesis — far beyond what any comparable Android voice app is known to have reached `[CL §7, §13]`. **The target is reachable only if two things both happen inside the window: one acquisition channel becomes repeatable, and the iPhone version ships.** The orchestrator's judgement is that this is unlikely within six months and not impossible; the plan below is built to find out early which it is.

**Paid advertising does not pay at this price.** At reported install costs and benchmark conversion, a buyer costs several times the $30 earned `[CL §13]`. Growth must come from channels that cost time, not money.

---

## 7. Growth Plan to the Target (Phases, Channels & Tripwires)

| Phase | When | What happens | Tripwire to pass |
| :--- | :--- | :--- | :--- |
| **0a. Quiet release, Synthesis free ("early access")** | 30 Nov → about mid-December | The paywall is not built, so the first release ships without it rather than slipping: Synthesis free and said to be free *for now* in the listing and the app. No payments profile or billing library is needed for this release. Recruit the first 20–50 users by hand; talk to each; fix what they hit; start the daily routine (below); start the payments profile on day one (bank and tax checks take days to weeks `[CL §15]`). | No blocking onboarding failure; at least half of capable-phone users run a second session. |
| **0b. Paywall update** | about mid-December → about 10 Jan | Ship the purchase, the session counter and the locked state. Early-access users keep Synthesis (recommendation: Play promo codes or a local flag; a few dozen people, worth more as reviewers than as buyers). Gather first reviews; film the demo from the stable build. | **Real purchases seen before any public push**: at least 5 unprompted purchases among the first 50 new capable-phone users. If the paywall is not live by about 20 December, move the public push rather than launch it blind. |
| **1. Public Android launch** | about mid-January 2027 (a "get organised" month; late December is weak — judgement) | Launch offer with an end date; demo video; founder posts; community posts where rules allow; Show HN. | About 3,000 installs and 60 sales in the launch month. |
| **2. Find one repeatable channel** | to end of February | Run the daily routine; double down on whichever source shows the best revenue per install in Play Console. iPhone build in progress. | **About 100 sales a month and one source producing 100+ installs a day.** If not, the six-month target is out of reach on this plan — reopen price, audience and product with the user. |
| **3. iPhone launch** | March–April | Second launch moment in the paying market; Product Hunt saved for this (its audience is not Android-first, and the comparable Android app got almost nothing there `[CL §13]`). | iPhone revenue per install at or above Android's. |
| **4. Scale** | May onward | Price test; next paid stage; whichever channel works. | 335+ sales a month. |

**What is deliberately not in the plan before the January push (the user raised both on 2026-11-25; orchestrator's recommendation, the user decides):**

- **The Action screen.** The specified version (FR14: extraction, checkboxes, calendar time-blocks, calendar accounts) is a new stage with a new permission and new store declarations; nobody has yet asked for it, and the paywall, the launch fixes and daily posting already fill one person's December. "Raw thoughts to actions" may well be the stronger pitch — that is a hypothesis (H10), and the cheap test is the first outreach question ("what did you do with the note afterward?"). If the answer is "copied the to-dos out", build Action next and sell it as its own unlock (Section 12).
- **An iPhone launch date.** iPhone is where the buyers are (Section 2), so earlier is better — but two things are unresolved and either can sink a date: whether the model can run within iPhone memory limits, and whether Synthesis can run when the app is not in front `[CL §12]`. Recommendation: a two-to-three-day feasibility check in the week after the Android release, then set the date on what it shows. If it is clean, February is realistic; the end of January needs everything to go right while the Android public launch is also running. The "new-year resolutions" lift is a judgement, not a measured fact, and is not worth a rushed second platform.

**Channels, ranked by evidence and cost** `[CL §13]`. **The user has no existing audience (fourth reply)**, which changes the order for the January push: channels that lend an audience (communities, Show HN, store search) carry the launch; founder posting starts now but pays later.

1. **Founder-led posting in public (X and similar), daily.** The first sales of both fast comparables came from a founder's own posts; it needs an audience, which takes months to build — start now, from zero, and expect little from it by mid-January.
2. **Founder-filmed short videos** of one ramble becoming one clean note. The one detailed account found credits founder-made videos and says paid creators brought almost no conversions; AudioPen's paid-creator test also failed (secondary source). Costs time only.
3. **Store search.** One solo app's breakthrough came from ranking in the top five for a major store keyword. Slow (weeks) and uncertain, but free and compounding: title, short description and screenshots matter from day one.
4. **Communities** (on-device AI, note-taking, Android). Useful for the first hundreds; several have tightened self-promotion rules — check each before posting.
5. **Personal outreach** to the first users. Not scalable; it is how the product gets good enough for the rest to work.
6. **Later**: Product Hunt with iPhone; creators paid by promo code (Play allows 500 codes a quarter); newsletters.
7. **Not now**: paid installs; paid influencers.

**Daily routine (the user's "pipeline")**: one post or short video a day; reply to every user message and review; ten minutes on the Section 8 numbers; once a week, one conversation with a user who did not buy.

---

## 8. Metrics (All From Play Console; the App Sends Nothing)

Sales per day (the target yardstick) · installs per day by source · buyers per 100 installs by weekly cohort · **revenue per install** (the one figure for comparing channels and prices) · store-page visitors who install · installs still present after 30 days · rating, review count, refund rate · share of installs on phones with 8 GB or more.

---

## 9. Risks Ranked by Damage × Likelihood (With Mitigations)

1. **Distribution: not enough capable-phone installs.** The dominant risk (Section 6). *Mitigation*: Section 7; iPhone as early as possible.
2. **Store review holds the launch.** Battery-optimisation exemption is a restricted permission with no voice-recording use case listed; the microphone service needs a declaration with a video; review can take a week `[CL §15]`. *Mitigation*: submit early; engineering to decide whether the exemption request is needed in the first release.
3. **Output quality against cloud models.** *Mitigation*: lead with a real before/after; never promise what the model cannot do; listen for it in every early-user conversation (H8).
4. **Onboarding friction**: 2.5 GB download, 8 GB requirement. *Mitigation*: capture works before the download; usage-based trial; honest listing; watch uninstalls.
5. **Platform owners bundling the outcome** `[CL §5]`. *Mitigation*: stay cheap to run; own "any phone, no account, pay once".
6. **One-time income needs a constant flow of new buyers.** *Mitigation*: Section 12.
7. **Other on-device Android voice-note apps** `[CL §3]`. *Mitigation*: install and study them; compete on the organised result.
8. **Later: the Accessibility route for the volume trigger** — discretionary approval, slow declaration review, blocked under Android 17 Advanced Protection `[CL §6, §12]`. *Mitigation*: already decoupled from the launch.
9. **No telemetry.** *Mitigation*: Section 8 and conversations.

---

## 10. Hypotheses & the Cheapest Test That Could Disprove Each

| # | Hypothesis | Cheapest disproving test | Needs the user? |
| :--- | :--- | :--- | :--- |
| H1 | People who try Synthesis will pay $30–40 once. | The first 50 users in the quiet release; talk to those who decline. | Yes (outreach) |
| H2 | The before/after of one ramble makes people want the app on sight. | Demo video and landing page; sign-ups and installs per view. | Yes (public) |
| H3 | At least 2 of 100 Android installs buy. | Play Console, first 1,000 installs. | No |
| H4 | One free channel can deliver 100+ installs a day repeatably. | Phase 2 of Section 7. | Yes (public) |
| H5 | Buyers do not need their notes on a second device. | Ask every early user; count requests for export, backup and sync. | No |
| H6 | The lazy dumper accepts on-device output quality. | Same conversations; note every comparison with cloud tools. | No |
| H7 | $39.99 earns more per install than $49.99 or $29.99. | Play price experiment when volume allows. | Yes |
| H8 | The volume trigger can pass Play review. | Submit it as a later update with its declaration. | Yes |
| H9 | A usage-based trial converts better than a time-based one. | Cannot be A/B tested without telemetry; compare cohorts if the design is ever changed. | — |
| H10 | "Raw thoughts to actions" sells better than "clean notes". | Ask the first 20–50 users what they did with each note; count those who pulled tasks out by hand. | Yes (outreach) |

---

## 11. Product Proposals Awaiting the User's Decision (Not Tasks, Not Specification)

1. **Usage-based Synthesis trial** (first 10 Synthesis sessions free, with the three guards) and paywall wording — Section 5. Also: **first release without a paywall**, Synthesis labelled free during early access, and how early-access users keep it — Section 7.
2. **Launch offer** of $29.99 with a stated end date — Section 5.
3. **Whether the first release requests the battery-optimisation exemption** — a store-review risk `[CL §15]`; engineering question.
4. **Export to plain Markdown files**, brought forward: the first reachable audience will ask for it; involves no network.
5. **Restrict the store listing by device memory, or not**: Play can exclude phones by RAM `[CL §13]`. Keeping small phones in gives reach and reviews for free capture; excluding them protects the rating from "Synthesis does not work on my phone". Recommendation: keep them, and say plainly in the listing and in the app what needs 8 GB.
6. **iPhone feasibility check early**: recording from a locked phone and running the model when the app is not in front are both unresolved `[CL §12]`.
7. **Later, openly**: optional encrypted backup as a paid service.

---

## 12. Scaling Beyond the Target & Directions to Watch (Each a Later Decision)

- **How a one-time price grows**: iPhone; Insights and Action sold as separate paid unlocks rather than paid "upgrades" of what was bought (taking away or re-charging for bought features is what causes backlash `[CL §7, §14]`); price rises for new buyers; a paid optional backup service; a professional edition for confidentiality-bound work.
- **Signals that would justify a change of direction** (the user is open to a pivot; none is proposed before launch data exists): early users love capture but ignore Synthesis; buyers come overwhelmingly from one profession; the commonest request is for something adjacent (dictation into other apps, meeting notes, a desktop companion); Android revenue per install stays far below the planning case while interest from iPhone owners is strong.
