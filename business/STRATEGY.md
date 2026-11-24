# STRATEGY.md — Eudemonia Business Strategy (Positioning, Business Model, Risks & Tests)

> **Status**: Draft v0.1, 2026-11-24. Written by the orchestrator after research wave 1. **Nothing here is decided.** The recommendation is conditional on the founder questions in [`BUSINESS_LOG.md`](BUSINESS_LOG.md). Facts are in [`COMPETITIVE_LANDSCAPE.md`](COMPETITIVE_LANDSCAPE.md) and are referenced here as `[CL §n]`, never restated as new facts.

---

## 1. Strategic Diagnosis (What the Evidence Says About Eudemonia's Position)

1. **The capability is unique and the uniqueness has a cause.** Nobody found ships the full chain: hardware trigger with the screen off → on-device transcription → on-device organisation, on any Android phone `[CL §3, §5]`. The likely reason is not that nobody thought of it. The trigger needs Android's Accessibility API, which Google Play polices at its discretion; phone makers solve the same need with their own privileged hardware keys `[CL §5, §6]`. **The signature feature is both the moat and the single point of failure.**
2. **Zero marginal cost changes the pricing logic.** Every cloud competitor gates usage because each minute costs them money, and every cloud competitor that sold lifetime access withdrew it `[CL §2, §3]`. Eudemonia has no such cost. Local-first products that earn recurring money all charge for something that runs on a server; purely local products charge once or on trust `[CL §7]`.
3. **Privacy is a reason to trust, not yet a proven reason to buy.** The products winning money in voice capture are cloud products; surveys show concern about privacy but little willingness to pay for AI `[CL §9]`. Privacy should support the pitch, not lead it — except for the audiences where confidentiality is the buying trigger (private journaling, confidential professional work, the on-device-AI enthusiast community).
4. **The honest size of the prize as a solo Android-only consumer app is small.** Solo cloud voice-note apps with web and iPhone reach top out around $8.5K–15K per month `[CL §3]`. Android carries about 15% of subscription revenue and converts roughly three times worse than iOS `[CL §8]`. See Section 6 for arithmetic.
5. **The squeeze from platform owners is real and will grow.** Google sells "speak and it is organised" inside a $4.99 plan, Samsung and Nothing give hardware-key voice capture away, and Google has a free offline dictation app on iOS `[CL §5]`. What they do not offer: any phone, no account, no network, pocket trigger. That gap exists today; it should not be assumed permanent.

---

## 2. Positioning Hypothesis (Category, Promise & Proof)

- **Category**: thought capture, not dictation (Wispr types into a text box), not meeting notes (Granola, Otter), not a journal app.
- **Promise**: *"Press both volume keys, say it, keep walking. Your phone turns the rambling into organised notes — by itself, on the phone."*
- **Lead with the outcome** (nothing is lost; nothing needs sorting), **support with the proof** (works in a tunnel; no account; the app holds no internet permission — a claim anyone can check and no cloud competitor can make).
- **Stance on price as part of the position**: *"No subscription. Nothing runs on our servers, so there is nothing to rent."* Against $144–180 a year for cloud dictation this is a differentiator in its own right.

---

## 3. Target Customer Sequence (Who First, Who Later, Who Not)

| Order | Customer | Why this order | Weakness |
| :--- | :--- | :--- | :--- |
| 1 | **Builders and thinkers on high-end Android** (founders, engineers, researchers, writers; on-device-AI and local-first enthusiasts) | They own 8–12 GB phones, understand "runs locally", gather in reachable communities, and value Capture + Synthesis, which is what exists. | Small; price-sensitive towards subscriptions; expects export to their own note system. |
| 2 | **Private journalers** | Proven willingness to pay ($50–130 a year at Day One, Rosebud `[CL §4]`); privacy matters most here. | Needs the Insights stage, which is not built; audience may skew to iPhone (unverified). |
| 3 | **Professionals bound by confidentiality** (therapists, lawyers, clinicians) | The only segment where "no data leaves the phone" removes a legal obstacle; teams are where dictation money is `[CL §2]`. | Needs sales effort, domain features and probably iPhone. A later bet, not a launch market. |
| Not now | **Rapid task capturers** | Competes directly with free assistants and Google Keep. | Weakest willingness to pay. |

---

## 4. Business-Model Options (Pros, Cons & Fit With the Product Principles)

| Option | What it is | For | Against |
| :--- | :--- | :--- | :--- |
| **A. Free capture + one-time unlock** | Capture and transcription free for ever; Synthesis (and later stages) unlocked by one payment after a trial. | Matches zero marginal cost and every purely local precedent; no server; simple honest message; friendly to the first audience; no backlash risk. | Income depends on a steady flow of new users; no built-in way to charge for major upgrades on Google Play; Play keeps 25% of a one-time purchase in the main markets against 15% of a subscription `[CL §6]`. |
| **B. Subscription (annual)** | Same split, paid yearly. | Recurring income; matches the nearest on-device rivals, which offer yearly plans. | No server cost to justify it; AI-app annual retention is about one in five `[CL §8]`, so most "subscribers" pay once anyway; hostile reception likely in audience 1. |
| **C. Hybrid: annual + lifetime** | Both offered, lifetime at 2–3× annual. | Lets buyers choose; common pattern `[CL §8]`. | More to explain and maintain; the annual plan undercuts the lifetime price for the many who would leave anyway. |
| **D. Honour system / open source** | Everything works; a notice asks for payment (FUTO's model `[CL §7]`). | Maximum trust and reach; strongest story for the enthusiast audience. | No data anywhere on what share pays; likely the lowest income. Right only if the goal is reputation. |
| **E. Free app + paid service with a real server cost** | Encrypted backup or sync across devices, sold monthly (Obsidian's model `[CL §7]`). | The only local-first model with proven recurring income. | Breaks "zero outbound bytes" unless strictly optional; needs infrastructure and accounts. A principle change — the user's decision. |
| **F. Hardware bundle** | A small Bluetooth button sold with the app (Plaud's logic `[CL §4]`). | Removes dependence on the Accessibility API; hardware is a trust and distribution lever. | Capital, logistics, support; far too heavy before demand is proven. |
| **G. Venture-scale company** | Raise money, add iPhone, cloud, teams. | Where the large outcomes are. | Requires abandoning several principles; competes head-on with a $2B-valued leader and platform owners. |

---

## 5. Current Recommendation (Conditional on the Founder Questions)

**If the ambition is a profitable independent product (the assumption until the user says otherwise): Option A now, with E kept open as a later, explicitly optional add-on.**

1. **Never charge for capture.** All triggers, recording, transcription, playback and the Capture stream are free for ever, on any phone. This is the wedge, the source of store reviews, and it honours the first product principle. It also resolves the device problem honestly: phones too small for the language model still get a better voice-memo app.
2. **Charge once for Synthesis.** A generous on-device trial (value before payment raises what people pay `[CL §7]`), then a single unlock. Working price range **$25–40**, to be tested; anchors: on-device rivals $40 a year and $25–64 one-time, cloud rivals about $99 a year `[CL §2, §3, §7]`.
3. **Start with a lower launch price and raise it**, never removing anything from existing buyers. Backlash in every case found came from taking paid features away, not from charging newcomers more `[CL §7]`.
4. **Treat later stages as later, separate unlocks** (Insights, Action) — *only if* Synthesis sells. The four-stage pipeline is a natural, honest ladder of one-time purchases and solves the missing paid-upgrade mechanism on Google Play.
5. **Sell through Google Play first.** Purchases restore through the buyer's Google account, so no Eudemonia account is needed, and distribution outside Play is becoming harder from 2027 `[CL §6]`. A direct build is a fallback, not the plan.

**Why not a subscription first — and how sure this is**: the numbers are close, not decisive. With about one in five AI-app subscribers renewing after a year `[CL §8]` and Play's lower fee on subscriptions, a $30 annual plan nets roughly $30–35 per payer over its life; a one-time price of $29 nets about $22, and of $39 about $29. So a one-time price has to sit near $35–40 to match, or convert more buyers. The case for one-time rests on three things the numbers do not capture: it is the simplest thing to build and explain, it fits the audience most likely to adopt first, and it is itself part of the positioning. **Confidence: moderate.** The disconfirming evidence is that the on-device rivals found offer yearly plans alongside lifetime `[CL §3]`. If the closed beta (H4) shows weak one-time conversion, Option C is the fallback.

**What would change this recommendation**: a venture-scale ambition (then G, and the principles must be reopened); a reputation goal (then D); evidence from the first buyers that they want their notes on several devices (then E becomes the recurring line).

---

## 6. Revenue Arithmetic & Sensitivity (Ranges, Not Forecasts)

Monthly income ≈ installs per month × share who pay × net per sale.

- **Net per sale** at a $29 price: about $22 after Play fees (25% on one-time purchases in the US, UK and EEA, 15% in most other markets `[CL §6]`), before income tax.
- **Share who pay**: 1–4%. Reference points: 2% median for freemium subscription apps, Android lower than iPhone `[CL §8]`; a one-time price and a real trial may help; unknown until measured.
- **Installs**: the number the result is most sensitive to, and the least knowable. One on-device Android voice app has about 63K installs in total after roughly three years `[CL §7]`.

| Scenario | Installs / month | Pay | Net / sale | Income / month |
| :--- | ---: | ---: | ---: | ---: |
| Quiet niche | 1,000 | 2% | $22 | ≈ $440 |
| Working channel | 5,000 | 3% | $22 | ≈ $3,300 |
| Breakout | 20,000 | 4% | $22 | ≈ $17,600 |

**Reading**: without a channel that works, this is pocket money; with one, it is a real but modest independent income; the breakout row is what AudioPen-class success looks like and should not be planned on. Costs are near zero in every row, so every row is profitable. **The business question is therefore distribution, not pricing.**

**What raises the ceiling** (each a separate later decision): iPhone (about 85% of subscription revenue `[CL §8]`); a professional/teams edition; a paid optional service (E); becoming the capture front-end for people who keep notes in Markdown systems.

---

## 7. Risks Ranked by Damage × Likelihood (With Mitigations)

1. **Platform dependence on the Accessibility API.** Play approval is discretionary; Android 17's Advanced Protection blocks such apps for users who switch it on; rules have tightened twice in a year `[CL §6]`. *Mitigation*: put a build through Google Play review **before** investing in launch (the cheapest test of the largest risk); make sure the product stays worth using when the chord is unavailable (lock-screen action and in-app trigger are already in the specification; phone makers' own key mappings are a further route).
2. **Platform owners bundling the same outcome for free or $5.** *Mitigation*: stay cheap to run, take value early, own the niche they will not serve (no account, no network, any phone).
3. **Distribution: small reachable audience, weak Android conversion.** *Mitigation*: Section 8, tests H1–H3; a demo video is the core asset because the product's moment is physical.
4. **Output quality against cloud models.** A 4B model on a phone will be compared with the best cloud models. *Mitigation*: compete on capture and trust, keep the "fidelity before brevity" rule, never promise what the model cannot do.
5. **Other on-device voice-note apps on Android** — one confirmed on Google Play with monthly, yearly and lifetime plans; one reported as free and open source but not verified `[CL §3]`. *Mitigation*: the trigger and the session pipeline are the difference; install and study both.
6. **No telemetry: decisions without data.** *Mitigation*: Google Play's own console reports installs and purchases without the app sending anything; a user-initiated "send feedback" and a small community replace analytics.
7. **Onboarding friction**: accessibility warning screen, battery exemption, multi-gigabyte model download. *Mitigation*: free capture must work before the big download; measure with beta users in person.
8. **One-time income dries up.** *Mitigation*: staged unlocks (Section 5.4), price rises for newcomers, option E if wanted.

---

## 8. Hypotheses & the Cheapest Test That Could Disprove Each

| # | Hypothesis | Cheapest disproving test | Needs the user's approval? |
| :--- | :--- | :--- | :--- |
| H1 | Google Play will accept the app with its Accessibility use. | Submit a build to a closed testing track with the declaration and demo video. | Yes (developer account, external submission) |
| H2 | The pocket-capture moment makes people want the app on sight. | A 30-second demo video and a one-page site with a waiting list; count sign-ups from two or three community posts. | Yes (public) |
| H3 | On-device-AI and local-first communities are a workable first channel. | Same posts as H2; compare sign-ups per community. | Yes (public) |
| H4 | People who try Synthesis will pay $25–40 once. | Closed beta of 20–50 users; ask for payment at the end of the trial; talk to those who decline. | Yes |
| H5 | Buyers do not need their notes on a second device. | Ask every beta user; count requests for export, backup and sync. | No |
| H6 | The trigger survives real phones (Samsung, Xiaomi, Android 17 with Advanced Protection). | Beta users' devices; an engineering check, outside this workstream. | Engineering |

---

## 9. Product Proposals Awaiting the User's Decision (Not Tasks, Not Specification)

These follow from the business analysis. Each needs the user's decision before it enters `PRODUCT_SPEC.md`.

1. **Launch scope**: launch with Capture + Synthesis and sell Synthesis; build Insights and Action only after Synthesis has buyers. The specification currently treats all four stages as version 1.
2. **Free/paid line**: capture and transcription free for ever; Synthesis behind a one-time unlock after a trial.
3. **Export to plain Markdown files** brought forward from the version 2 roadmap: the first audience keeps notes in such systems and will ask for it first. Involves no network.
4. **Trigger redundancy as a stated product goal**: the app must remain fully usable when the Accessibility route is denied by Play, by Advanced Protection or by the user.
5. **"No internet permission" as a checkable promise**, including a check that Google Play's billing component does not add one (unverified `[CL §7]`).
6. **Later, openly**: revisit the iPhone non-goal (newer iPhones have a programmable hardware button — from memory, not researched), and an optional encrypted backup service.
