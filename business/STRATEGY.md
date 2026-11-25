# STRATEGY.md — Eudemonia Business Strategy (Positioning, Business Model, Risks & Tests)

> **Status**: Draft v0.3, 2026-11-25. Revised after the user's answers to the founder questions (recorded in [`BUSINESS_LOG.md`](BUSINESS_LOG.md)) and after research wave 2 (price evidence, trigger precedents; `[CL §11–12]`). **The price and the model are not decided.** Facts are in [`COMPETITIVE_LANDSCAPE.md`](COMPETITIVE_LANDSCAPE.md) and are referenced here as `[CL §n]`, never restated as new facts.

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
- **Promise (v0.2)**: *"Ramble. Get clean, organised notes. Nothing leaves your phone."* The outcome leads because it is what the user's first customer (Section 3) wants and because it holds on both Android and iPhone.
- **The trigger is no longer the identity.** v0.1 led with "press both volume keys, keep walking". The user reports that the screen-off trigger does not work today, that store approval is doubtful and that the approach is impossible on iPhone. The position therefore becomes *the fastest capture each phone allows* — volume keys where permitted, lock-screen entry points elsewhere. Pocket capture with the screen off must not be advertised until it works.
- **Support with the proof**: works in a tunnel; no account; no cloud processing — claims no cloud competitor can make. (A licence check, now acceptable to the user, means "the app holds no internet permission" can no longer be the proof; "your words never leave the phone" still can.)
- **Stance on price as part of the position**: nothing runs on our servers, so the price can be a fraction of cloud rivals' $99–180 a year. Whether that is "no subscription" or "a very cheap one" is the open pricing decision (Sections 4–5).

---

## 3. Target Customer Sequence (Who First, Who Later, Who Not)

| Order | Customer | Why this order | Weakness |
| :--- | :--- | :--- | :--- |
| 1 (user's picture, 2026-11-25) | **The "lazy dumper"**: someone who wants to talk thoughts into one place and get a clean, structured result without effort | It is the customer AudioPen and its imitators already sell to at about $99 a year `[CL §3]`, so willingness to pay for the outcome is demonstrated; Capture + Synthesis is exactly what they need. | A mass audience with no single gathering place, so it is expensive to reach; it compares output quality with cloud models; many are on iPhone. |
| 1b (reachable beachhead) | **Builders and thinkers on high-end Android** (founders, engineers, researchers, writers; on-device-AI and local-first enthusiasts) | They own 8–12 GB phones, understand "runs locally", gather in reachable communities, and value Capture + Synthesis, which is what exists. A way to reach the first lazy dumpers, not a different product. | Small; price-sensitive towards subscriptions; expects export to their own note system. |
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
| **G. Venture-scale company** | Raise money, add iPhone, cloud, teams. | Where the large outcomes are. | Requires abandoning several principles; competes head-on with a $2B-valued leader and platform owners. Ruled out by the user's "no cloud" decision (2026-11-25). |
| **H. Floor-price monthly subscription (the user's proposal, 2026-11-25)** | US $0.59–0.99 and India ₹19–29 a month, presented as an honour system. | Serves the reach ambition; at this level the objection "why rent software that runs on my phone" largely disappears; Play's fee on subscriptions is lower than on one-time purchases `[CL §6]`; cheap plans are cancelled less `[CL §11]`; one solo app earns $28K a month this way `[CL §11]`. | Needs three to five times as many payers as a $2.99 plan for the same income, and the benchmarks point the other way: low-priced apps convert fewer installs, not more `[CL §11]`; cannot reach the user's revenue target (Section 6); more payers per dollar means more support per dollar; "honour system" and "subscription" are different models (D versus B) and must not be blurred in what users are told. |

---

## 5. Current Recommendation (v0.3 After Wave 2 Evidence; Price and Model Still the User's Decision)

**What the evidence says about the user's floor-price proposal (Option H)** `[CL §11]`:

- *Against*: across many apps, low-priced apps convert **fewer** installs into payers than high-priced ones (1.4% against 2.8%) and earn about an eighth of the income per install. This compares different apps, so it does not prove a price cut lowers conversion — but nothing found supports the idea that a floor price multiplies payers. No test of a cut to about $1 a month was found; published tests show price rises paying off. WhatsApp abandoned its $0.99 fee. India and South-East Asia convert worst of all regions (0.7%).
- *For*: low-priced apps keep subscribers longer (36% against 23% after a year) and are refunded less. **HabitKit is the existence proof**: a solo founder reports $28,000 a month from 25,100 subscribers at about $1–2 a month. It also shows the price of that route: about 560,000 downloads, both iPhone and Android, an app that runs on any phone, and a price the founder later doubled on iPhone.
- *Neutral but useful*: Google Play keeps existing subscribers on their old price when the price rises, so a low launch price is reversible for newcomers.

**Recommendation**

1. **Reach is delivered by the free tier.** Capture and transcription free for ever, on any phone.
2. **Synthesis is paid by a cheap subscription with a lifetime price beside it** (Option C at a low level). This replaces the v0.1 one-time-only recommendation: the user prefers it, Play's fee is lower, the "renting local software" objection is weak at this level, and cheap plans retain well.
3. **Start in the US at about $1.99 a month and $14.99–19.99 a year, with lifetime at about $29, and test $0.99 a month in a comparable country** (H7). Whichever earns more per install wins. $1.99 is the level the one successful $1 app moved to; it is still about a quarter of AudioPen's price ($99 a year `[CL §3]`). Confidence in the exact numbers: low. Confidence that $0.99 should be tested rather than assumed: high.
4. **India: price for reach, expect little income.** ₹49–99 a month is already below every named reference found (₹59–149); ₹29 is possible but nothing suggests it is needed. Offer a yearly plan (about ₹399–499) because every monthly debit triggers a mandatory notice and many automatic debits fail.
5. **Do not call an enforced subscription an honour system.** If Synthesis works unpaid, expect a few per cent to pay at most (Thunderbird: 3%) and treat income as incidental. The user decides which model it is.
6. **The $10–15K target within two quarters should not be planned on** (Section 6). Replace it with measured gates: launch date, installs per month, share who pay, income per install — and a decision point at month six of the runway.
7. **Launch sequence that cannot be blocked by the Accessibility review** `[CL §12]`: first store release with the notification and widget routes only (both officially allowed to start the microphone); recruit 12 testers now, because the closed test must run 14 days before production access; add the volume trigger as a later update with its declaration, which Google says can take weeks and holds the update while pending.
8. **Check iPhone feasibility early** — it is the largest income lever `[CL §8]` and two things are unresolved `[CL §12]`: recording from a locked phone, and running the language model when the app is not in front. Engineering questions for the user to route.

The v0.1 reasoning below (Option A) is kept as the comparison case; items 1, 3 and 5 of it still stand.

**v0.1 (2026-11-24): Option A, with E kept open as a later, explicitly optional add-on.**

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

### Subscription Arithmetic Against the User's Target of $10–15K a Month (Added 2026-11-25)

Paying subscribers needed = target ÷ net per payer per month. Play keeps 15% of subscriptions `[CL §6]`. India figures assume about ₹88 to the dollar and that the listed price includes 18% GST (assumptions; the net for a developer located in India was not established `[CL §11]`).

| Price | Net per payer / month | Payers for $10K | Payers for $15K |
| :--- | ---: | ---: | ---: |
| US $0.59 a month | ≈ $0.50 | ≈ 20,000 | ≈ 30,000 |
| US $0.99 a month | ≈ $0.84 | ≈ 11,900 | ≈ 17,900 |
| US $2.99 a month | ≈ $2.54 | ≈ 3,900 | ≈ 5,900 |
| US $29.99 a year | ≈ $2.12 | ≈ 4,700 | ≈ 7,100 |
| India ₹29 a month | ≈ $0.24 | ≈ 42,000 | ≈ 63,000 |
| India ₹19 a month | ≈ $0.16 | ≈ 64,000 | ≈ 96,000 |

**Reference case** `[CL §11]`: HabitKit's reported 25,100 subscribers on about 562,000 downloads is roughly 4.5 subscribers per 100 downloads (rough: the download period is not stated). At that ratio $10K a month needs about 265,000 downloads at $0.99 and about 130,000 at $1.99.

**Reading**: at $0.99, 11,900 payers means about 600,000 installs at the 2% benchmark `[CL §8]`, or 120,000 even if one in ten pays — on phones with 8 GB or more, within six months, before cancellations. The one on-device Android voice app with a known figure has about 63K installs after roughly three years `[CL §7]`. The solo cloud voice-note apps that reached this income did so at about $99 a year with web and iPhone reach `[CL §3]`. The floor price and the target cannot both hold; the target is unlikely in two quarters at any price.

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
| H7 | (The user's) A floor price converts so many more people that it earns at least as much as a moderate price. | Set different prices in comparable countries during the beta (for example $0.99 in one, $2.99 in another) and compare income per install, not payer counts. The floor price must bring more than three times the payers to win. | Yes |
| H8 | The lazy dumper accepts on-device output quality. | Give beta users the same ramble processed by Eudemonia and ask whether the result is good enough to pay for; note every comparison with cloud tools. | No |

---

## 9. Product Proposals Awaiting the User's Decision (Not Tasks, Not Specification)

These follow from the business analysis. Each needs the user's decision before it enters `PRODUCT_SPEC.md`.

1. **Launch scope** — **agreed by the user 2026-11-25**: launch with Capture + Synthesis; Insights and Action later.
2. **Free/paid line**: capture and transcription free for ever; Synthesis is the paid part. How it is paid for (one-time, cheap subscription, honour system) is open — Section 5.
3. **Export to plain Markdown files** brought forward from the version 2 roadmap: the beachhead audience keeps notes in such systems and will ask for it first. Involves no network.
4. **Trigger redundancy, strengthened 2026-11-25 — the launch must not depend on the Accessibility permission**: ship the store build so that it is complete with entry points that need no special permission (lock-screen notification, quick-settings tile, widget); treat the volume-key trigger as an optional extra that can be added, reviewed or dropped without holding the launch. A build with the volume trigger can also be offered outside the store, which the user accepts. Notification and widget routes are officially allowed to start the microphone `[CL §12]`; whether they work without unlocking is an engineering check.
5. **The privacy promise must be restated now that a licence check is acceptable**: "your words and notes never leave the phone" rather than "no internet permission". The exact wording should be true and checkable.
6. **iPhone** — **direction set by the user 2026-11-25** (after Android is live). Its capture entry point and the limits on running the language model there are unresolved `[CL §12]`. **Later, openly**: an optional encrypted backup service.
