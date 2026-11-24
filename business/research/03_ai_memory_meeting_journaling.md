# Business-Model Research: AI Memory, Meeting Notes, Wearable Recorders, AI Journaling, Second-Brain Notes

Research date: 2026-11-24. Pages fetched on that date unless stated. Labels: [OFFICIAL] company site/store listing, [PRESS] news, [FOUNDER] founder statement, [ESTIMATE] third-party estimate. "NOT FOUND" means I could not locate it; nothing is guessed.

Caveat on fetching: plaud.ai product/pricing pages returned HTTP 429/404 repeatedly; Plaud prices below come from Plaud's own regional page global.plaud.ai (fetched OK) cross-checked with a March 2026 third-party article. Several sources are web-search summaries of pages I could not open directly; those are flagged.

---

## Otter.ai

1. **What:** Cloud meeting transcription/notes bot (joins Zoom/Meet/Teams). Android: NOT FOUND in fetched sources (not verified).
2. **Cloud/privacy:** Fully cloud. Faces a privacy class action (see 7).
3. **Pricing** (https://otter.ai/pricing, fetched 2026-11-24) [OFFICIAL]:
   - Basic free: 300 min/month, 30 min per conversation, 3 lifetime file imports, 25 most recent conversations, 20 AI chat queries/month, exports mp3/txt only.
   - Pro: $16.99/user/month monthly, $8.33/user/month billed annually; 1,200 min/month, 90 min per conversation, unlimited history, 10 imports/month.
   - Business: $30/user/month monthly (shown $24 with promo), $19.99/user/month annual; unlimited minutes, 4 h per conversation.
   - Enterprise: custom (SSO/SCIM, HIPAA add-on). Student Pro annual $79.99. A Black Friday 50%-off banner was live on the page.
   - Gated: history length, per-meeting length, minutes, exports, concurrent meetings, AI chat queries, integrations.
4. **Funding/team:** Equity raised ~$70-73M across seed to Series B ($50M Series B, Spectrum Equity, 2021) [ESTIMATE] https://sacra.com/c/otter/ . On 2026-10-20 raised $320M non-dilutive from General Catalyst's Customer Value Fund (financing for sales/marketing, repaid from revenue share, no equity) [PRESS] https://siliconangle.com/2026/10/20/otter-ai-raises-320m-in-funding-for-its-ai-meeting-assistant/ . Valuation: NOT FOUND. Headcount: NOT FOUND (a Caplight listing showed ~291, undated, unverified).
5. **Traction:** $100M ARR announced 2025-12-22 [OFFICIAL press release, title seen via search] https://www.businesswire.com/news/home/20251222704206/en/ (page not fetchable, 403); Sacra dates $100M to Mar 2025, $81M end 2024 [ESTIMATE] https://sacra.com/c/otter/ . 40M+ users, 86% of Fortune 500 employees [PRESS, 2026-10-20, siliconangle link above]; Sacra: 25M users in 2025 vs 14M in 2023.
6. **Growth channel:** "Bot-in-meeting" viral exposure to attendees; Sacra estimates CAC ~$0.32/user and sales teams = 68% of revenue but 31% of users [ESTIMATE]. Now buying growth: plans to triple sales/marketing budget [PRESS, siliconangle link].
7. **Outcome/controversy:** In re Otter.AI Privacy Litigation (N.D. Cal. 5:25-cv-06911), class action filed Aug 2025 alleging recording without all-party consent, wiretap/CIPA and Illinois biometric claims; motion to dismiss pending, no ruling found [PRESS] https://www.npr.org/2025/08/15/g-s1-83087/otter-ai-transcription-class-action-lawsuit . Fireflies hit with a BIPA suit Dec 2025 (same search summary).
8. **Lesson:** Free tier is a hard-capped taste (minutes, history, exports) and the paid tiers monetize volume; cloud recording of other people is now a litigation risk that a purely on-device, own-voice app avoids.

---

## Granola

1. **What:** AI notepad that transcribes meetings from the device audio (no meeting bot) and merges with typed notes. Platforms: Mac, Windows, iOS; **Android launched 2026-07-01** (in-person capture; phone-call capture iOS only) [OFFICIAL] https://www.granola.ai/blog/introducing-granola-for-android . Which plans include Android: not stated on that page.
2. **Cloud/privacy:** Cloud. Audio not stored (mobile uses temporarily cached audio); transcription via Deepgram/AssemblyAI, summaries via OpenAI and Anthropic; notes in US AWS VPC; trains on anonymised data with opt-out (Enterprise off by default); some notes cached locally [OFFICIAL] https://www.granola.ai/security .
3. **Pricing** (https://www.granola.ai/pricing, fetched 2026-11-24) [OFFICIAL]: Basic $0 (30-day meeting history, Auto AI model only, no integrations/API/pre-meeting briefs); Business $14/user/month; Enterprise $35/user/month. Page showed monthly prices only (no annual). Free-tier meeting count cap: conflicting. Sacra says "25 free meetings" and a $18 individual plan [ESTIMATE, undated] https://sacra.com/c/granola/ ; current official page shows no individual $18 plan and no meeting-count cap; Granola's own startup post reportedly says free has no meeting limit (seen only in a search summary). Change log: voice typing added to all plans 2026-10-30 [ESTIMATE/tracker] https://pricingsaas.com/companies/granola .
4. **Funding/team:** $125M Series C 2026-03-25 at $1.5B valuation, led by Index Ventures with Kleiner Perkins; previous $43M at $250M (May 2025); total raised $192M [PRESS] https://techcrunch.com/2026/03/25/granola-raises-125m-hits-1-5b-valuation-as-it-expands-from-meeting-notetaker-to-enterprise-ai-app/ . Team size: NOT FOUND.
5. **Traction:** No ARR, user count or paid-user count published (TechCrunch article above gives none). CEO said revenue grew 2.5x since January (Bloomberg via secondary summary, no dollar base) [PRESS, secondary] https://implicator.ai/granola-raises-125-million-at-1-5-billion-valuation-for-ai-notetaker/ . Sacra: 57% of users in leadership roles [ESTIMATE]. 5,000 weekly users in Oct 2024 [ESTIMATE, aggregator]. Enterprise logos: Vanta, Gusto, Thumbtack, Asana, Cursor, Lovable, Decagon, Mistral AI [PRESS, TechCrunch link].
6. **Growth channel:** Organic/word of mouth in tech founders and investors, "Superhuman strategy" targeting influential users who evangelise [ESTIMATE] https://sacra.com/c/granola/ ; Betaworks says team wanted primarily organic growth (search summary). Then land-and-expand via exec champions into Business/Enterprise, MCP/API integrations with Claude/ChatGPT [PRESS, TechCrunch link].
7. **Outcome/pivots:** Moved from prosumer notepad to enterprise "context" platform (Spaces, API, MCP) [PRESS, TechCrunch link]. Pricing tiers simplified in 2026 (Individual plan no longer on official page; exact date NOT FOUND, trackers conflict).
8. **Lesson:** The unicorn path was a 1-user-per-tab habit product that spread among influencers, then monetized through team seats; solo-user willingness to pay was never disclosed, and the free tier now exists mainly to feed seat upgrades. A consumer-only on-device app has no seat upsell.

---

## Limitless (formerly Rewind)

1. **What:** Pendant ($99) + desktop/web app that recorded and summarised conversations; Rewind was the earlier Mac screen/audio recorder. Platforms: iOS/Mac/Windows/web; Android not found.
2. **Cloud vs on-device:** Rewind was local-first; Limitless chose cloud because "people wanted access across devices with privacy" [FOUNDER] https://creatoreconomy.so/p/dan-siroker-building-ai-wearable-limitless .
3. **Pricing (pre-acquisition):** Pendant $99 [PRESS] https://www.techcrunch.com/2025/12/05/meta-acquires-ai-device-startup-limitless/ . Pro $20/month, free tier = unlimited audio storage + 10 h AI/month [ESTIMATE, Sacra] https://sacra.com/c/limitless . Other sources gave $19 annual / $29 Unlimited; unreconciled. Current official page has no pricing (acquired).
4. **Funding/team:** >$33M raised (a16z, First Round, NEA); acquisition price and valuation undisclosed [PRESS] TechCrunch link above. Sacra: $350M valuation in 2023 round [ESTIMATE].
5. **Traction:** ~10,000 pendants pre-ordered in 24 h at announcement, ~40% buyers outside US [FOUNDER interview] creatoreconomy link. Sacra estimates ~$2M ARR Apr 2025 (from ~$0.9M end 2024) [ESTIMATE] https://sacra.com/c/limitless . Lifetime units: NOT FOUND.
6. **Growth channel:** Founder-led social/Twitter and launch hype (inferred from pre-order spike; no explicit source), i.e. not verified.
7. **Outcome:** Acquired by Meta, announced 2025-12-05 (Reality Labs wearables). Pendant sales ended 2025-12-05; existing customers supported through 2026, subscriptions dropped, Unlimited plan free; Rewind capture ended 2025-12-19; service removed in EU, UK, Brazil, China, Israel, South Korea, Turkey; users in those regions had until 2025-12-19 to export before deletion; continuing users must accept updated privacy terms [OFFICIAL] https://www.limitless.ai . Users' first reaction included refund demands and Meta privacy fears; one report claims the new policy dropped "no data sales/ads" language (unverified) [PRESS, search summary] https://techinformed.com/meta-acquires-limitless-pendant-users-moved-to-free-unlimited-plan/ .
8. **Lesson:** Even a well-funded, much-loved capture product ended as an acqui-hire with users stranded within two weeks; an on-device app whose data lives on the user's phone survives the vendor ending, which is a sellable promise.

---

## Bee (Amazon)

1. **What:** Wearable (wristband/clip) AI assistant that records conversations and builds memory. Android app exists (Google Play link on bee.computer) [OFFICIAL] https://www.bee.computer .
2. **Cloud/privacy:** Cloud processing; says audio is processed then deleted, conversations private/encrypted with user-controlled keys, "Not even Amazon can access your data unless you choose to share it" [OFFICIAL] https://www.bee.computer (footer now (c) 2026 Amazon).
3. **Pricing:** Official page shows Frontier Edition at $52.49 via Amazon (Eclipse pre-order, no price); Bee Pro price not shown [OFFICIAL] https://www.bee.computer . Press: Frontier launched 2026-10-15 at $74.99, includes summaries/recaps and 14 days history free; Eclipse $99.99; Bee Pro $11.99/month (~$99-99.99/year); 30 days Pro free; Pioneer owners keep prior features free [PRESS/secondary search summary, unfetchable articles: https://www.techrepublic.com/article/news-amazon-bee-frontier-free-pro-features/ ]. $52.49 vs $74.99 conflict (possibly a discount); original Pioneer was $49.99 + $19.99/month plan [PRESS, same summary].
4. **Funding/team:** $7M round Jul 2024 led by Exor (incl. $1.5M pre-seed) [PRESS] https://techcrunch.com/2024/07/29/former-squad-and-twitter-execs-raise-7m-to-build-a-hardware-ai-assistant ; team of 8 in Jan 2026 [PRESS] https://techcrunch.com/2026/01/12/why-amazon-bought-bee-an-ai-wearable/ .
5. **Traction:** No user or unit numbers found (TechCrunch Jan 2026 gives none).
6. **Growth channel:** Cheap $49.99 impulse price and press hype; now Amazon distribution [PRESS].
7. **Outcome:** Amazon announced acquisition 2025-07-22 [PRESS] https://techcrunch.com/2025/07/22/amazon-acquires-bee-the-ai-wearable-that-records-everything-you-say/ ; shown at CES Jan 2026, not replacing Alexa, to converge later; reintroduced as freemium (free device features + $11.99 Pro) in Oct 2026 per press.
8. **Lesson:** Hardware at ~$50-75 plus a ~$12/month "memory" subscription is the converged pattern; the real price pressure from Amazon is on hardware, not on software.

---

## Plaud (NotePin / Note / Note Pro + subscription)

1. **What:** AI voice-recorder hardware (credit-card Note, clip/pendant NotePin) with cloud transcription/summary app. Android app exists: "Plaud: AI Work Companion" on Google Play [OFFICIAL] https://play.google.com/store/apps/details?id=ai.plaud.android.plaud (page truncated; stats not read).
2. **Cloud/privacy:** Cloud. Claims ISO 27001, ISO 27701, GDPR, SOC 2, HIPAA, EN 18031 [PRESS, 2026-06-18] https://itbrief.com.au/story/plaud-hits-usd-100-million-arr-with-hardware-led-ai .
3. **Pricing** (https://global.plaud.ai/pages/edm-welcome-flow, fetched 2026-11-24, USD) [OFFICIAL]:
   - Hardware: Note $159, NotePin $159, NotePin S $179, Note Pro $189. (Plaud One earbuds on pre-order, price not shown.)
   - Starter: free, 300 min/month on every device.
   - Pro: 1,200 min/month, $17.99 monthly or $8.33/month billed annually (~$99.99/year).
   - Unlimited (24 h/day cap): $29.99 monthly or $19.99/month annually (~$239.99/year).
   - Team: $35 (listed $30) per user monthly, $25 (listed $20) annual.
   - Device purchase includes one-time 600 free minutes. Top-up packs 600 min $12.99, 3,000 min $59.99, 6,000 min $99.99, expire after 24 months [ESTIMATE, Omi blog 2026-03-17, competitor] https://www.omi.me/blogs/ai-note-takers/plaud-pricing . Gated: minutes, features.
4. **Funding/team:** No venture funding claimed; "reached profitability without giving up equity" [PRESS, Bloomberg-based 2026-06-16] https://startupfortune.com/plaud-reached-250-million-in-recurring-revenue-without-a-single-venture-dollar-and-is-now-targeting-500-million-in-2026-sales/ . Sacra lists ~$4.75M convertible note Apr 2025 (Carbide Ventures) [ESTIMATE] https://sacra.com/c/plaud ; conflict with "no venture funding". Team size: NOT FOUND. CEO Nathan Xu (Sacra spells Hsu).
5. **Traction (conflicting):**
   - >2M devices shipped; **software subscription ARR >$100M**; nearly 50% of device buyers convert from free to paid Pro/Unlimited [OFFICIAL via press, 2026-06-17] https://aiweekly.co/alerts/plaud-hits-100m-arr-on-2m-ai-notetaker-devices .
   - Bloomberg-based coverage: "$250M recurring revenue", target $500M total 2026 sales, 10x yoy growth two years running [PRESS] startupfortune link above. Sacra estimates ~$250M annualized total revenue Sep 2025, ~50/50 hardware vs subscription, hardware gross margin ~25% [ESTIMATE] https://sacra.com/c/plaud .
   - Homepage claims "over 3 million professionals" [OFFICIAL] https://www.plaud.ai (fetched 2026-11-24). Hardware/software split, margins, profit: NOT officially disclosed.
   - Reconciling note: $100M (software only) and $250M (apparently total annualised revenue) are probably different definitions; I could not confirm.
6. **Growth channel:** Hardware-led: the device is acquisition, free 300 min is the funnel into paid; US/Japan/Europe ~80% of business [PRESS] search summary; named rivals Anker, Viaim, Vibe, Pocket [PRESS, aiweekly link].
7. **Outcome/pivots:** Expanded to Plaud Teams (2026), new Plaud One earbuds with 4G/agents announced June 2026 [PRESS] https://www.channelinsider.com/ai/news-plaud-one-ai-earbuds-4g-esim/ (headline seen only). Tencent rumored interest [PRESS headline only] https://amp.kr-asia.com/tencents-rumored-plaud-deal-points-to-looming-ai-hardware-contest . No shutdown/privacy scandal found.
8. **Lesson:** Users will pay ~$160-190 for a physical capture button plus ~$100-240/year for transcription; a ~50% claimed free-to-paid conversion shows the free quota (300 min) is a paywall by design, not generosity. Eudemonia has no marginal cost to justify metering minutes, so the equivalent paid value must be features (insights, sync), not capacity.

---

## Rosebud (AI journaling)

1. **What:** AI journal that asks questions, recalls past entries, gives weekly reports/patterns; voice or text. iOS, Android (Google Play), web [OFFICIAL] https://www.rosebud.app .
2. **Cloud/privacy:** Cloud AI; "encrypted in transit and at rest", HIPAA-aligned badge; Apple privacy label shows data linked to user (email, user content for support, usage) [OFFICIAL] https://apps.apple.com/us/app/id6451135127 .
3. **Pricing** [OFFICIAL] https://www.rosebud.app and https://apps.apple.com/us/app/id6451135127 (fetched 2026-11-24): Free basic. Bloom $12.99/month or $107.99/year ($8.99/month; struck from $155.99). IAP list also shows Bloom Affiliate $11.00/$92.00, Thrive 2x $24.99/$199.99, Thrive 5x $59.99/$499.99 (periods unlabelled; higher tiers = bigger AI usage budget per search summary). Student/disability discounts. Free-tier exact limits: NOT FOUND. Official /pricing URL returned 404.
4. **Funding/team:** $6M seed, led by Bessemer, with 776, Initialized, Fuel, Avenir, Tim Ferriss, announced 2025-06-04 [OFFICIAL] https://www.rosebud.app/blog/rosebud-raises-6m-to-expand-the-worlds-leading-ai-journal . Small LA team (founders Chrys Bader, Sean Dadashi + four named staff). Valuation: NOT FOUND.
5. **Traction:** **7,500+ paying customers** (company, June 2025) [OFFICIAL, same blog]; "150K+ users" / "100K+" on homepage [OFFICIAL]; 4.9 rating ~3.4K ratings on App Store [OFFICIAL]. Revenue: Adapty modeled estimates ~$50K-$100K/month (page shows both), <1K monthly iOS downloads, captured Sep 2026 [ESTIMATE] https://adapty.io/paywall-library/rosebud/ . An $800K MRR claim from a paywalled teardown is unverified [ESTIMATE] https://www.openaitoolshub.org/ai-product-research/rosebud-journal . If 7,500 payers x ~$9-13/month = roughly $70-100K MRR, consistent with Adapty (my arithmetic, not a source).
6. **Growth channel:** Therapist/coach recommendations (claimed, no numbers), App Store/Play, social [OFFICIAL blog]. Product Hunt launches (search result).
7. **Outcome:** Launched mobile Aug 2024; added Thrive usage tiers (priced up to $499.99/year). No shutdown. No privacy scandal found.
8. **Lesson:** Journaling does carry real paid demand (~$9-13/month for conversational AI), but the pricing ladder is by AI-usage cost; a zero-marginal-cost on-device app can price flat and cheaper, though the Bloom price anchor ($108/year) bounds what users accept.

---

## Day One (Automattic)

1. **What:** Long-running journaling app (founded 2011 by Paul Mayne; acquired by Automattic 2021). iPhone, iPad, Watch, **Android**, Mac, Windows, web [OFFICIAL] https://dayoneapp.com/about/ .
2. **Cloud/privacy:** Synced cloud journal; free tier includes end-to-end encryption; AI features are cloud with daily usage limits [OFFICIAL] https://dayoneapp.com/pricing . "Privacy Pledge" referenced but encryption details not on About page.
3. **Pricing** (https://dayoneapp.com/pricing, fetched 2026-11-24, annual only listed) [OFFICIAL]:
   - Basic $0: unlimited entries/journals, 1 photo/entry, **1 device only**, E2EE, prompts, templates, streaks.
   - Silver $49.99/year: 30 photos/videos per entry, unlimited devices + sync, **audio recording and transcription**, integrations, Labs access, 25% off printed journals.
   - Gold $74.99/year: adds Daily Chat, reflective AI summaries/prompts, entry summaries, title suggestions, image generation, 35% off prints.
   - App Store showed Silver monthly $8.99 [OFFICIAL] https://apps.apple.com/app/id1044867788 (via search summary). Free trial one month.
4. **Funding/team:** Part of Automattic; team size NOT FOUND (2021: team of 12) [PRESS] https://techcrunch.com/?p=2165883 .
5. **Traction:** 10M+ downloads, 500K+ five-star ratings [OFFICIAL] https://dayoneapp.com/about/ . Subscriber count/revenue: NOT FOUND.
6. **Growth channel:** Longevity, App Store features, Automattic ecosystem (not stated explicitly).
7. **Outcome:** Moved from one-time purchase to subscription (2021-era; Mayne said subscription would sustain app) [PRESS, TechCrunch link]; now tiered with AI at top tier.
8. **Lesson:** The strongest data point on journaling willingness to pay: free tier is crippled by **device-sync and voice (audio transcription) gating** at $49.99/year, with AI at $74.99. Voice capture is a paid feature at the category leader, which suggests Eudemonia's core feature has a proven price floor, and sync is the natural cost-free gate for a local app.

---

## Mindsera / Stoic (journaling, second-tier)

**Stoic** (more data, Android yes):
1. **What:** Journal/mindset app. Mac, web, iPhone/iPad, Android, Watch [OFFICIAL] https://www.getstoic.com .
2. **Privacy:** "Private & Free to start"; journals stored on device, Premium backs up/syncs; if AI is on, entries are sent to AI providers [OFFICIAL, same].
3. **Pricing:** App Store IAPs (periods unlabelled): Stoic premium $6.99, $17.99, $26.99, $39.99; Stoic AI $12.99, $69.99, $99.99; **Lifetime Premium $299.00** [OFFICIAL] https://apps.apple.com/us/app/stoic/id1312926037 . Earlier snapshot showed lifetime $199.99; a 2026 release note announces lifetime access [OFFICIAL, search summary]. Free tier details: NOT FOUND.
4. **Funding/team:** NOT FOUND. 5. **Traction:** "Over 4 million downloads", 4.8 rating, 36K App Store ratings [OFFICIAL].
6-7. **Channel/outcome:** NOT FOUND beyond App-of-the-Day features. Lifetime price rose $199.99 to $299 (lifetime offered as a revenue lever).
8. **Lesson:** A local-first journal can sell a $299 lifetime tier, directly relevant to a zero-marginal-cost app.

**Mindsera:**
- Android + iOS + web [OFFICIAL] https://mindsera.com . Free "Curious"; "Genius" $14.99/month or $10.75/month annual ($129/year); trial offered; voice mode, emotion/topic analysis gated. States writing encrypted, not used to train AI. Funding/traction: NOT FOUND.

**Reflectly (for context):** Third-party estimate under $5K/month revenue, ~$9.99/month, $39.99-59.99/year [ESTIMATE] https://adapty.io/paywall-library/reflectly/ and https://screensdesign.com/apps/reflectly-journal-ai-diary/ ; no shutdown found. Lesson: mood-journal category alone is a weak monetizer without differentiation.

---

## Mem

1. **What:** AI notes app ("self-organizing" notes). **Shutting down.**
2. Cloud.
3. **Pricing:** Official pricing page gone; only wind-down notice [OFFICIAL] https://get.mem.ai/pricing : "We're no longer offering new paid subscriptions", charging paused, **notes read-only 2026-12-18, shut down 2027-01-15**. Historic: Free / Pro $12 / Teams; Feb 2026 raised to $14.99; Aug 2026 trackers show re-tiering to usage-capped (Mem Plus $9, Pro $29, up to $199) and a $99/month "Proactive" tier Jul 2026 [ESTIMATE/tracker] https://costbench.com/changelog/mem-price-increase-2026-02/ , https://usagepricing.com/blueprint/activity/mem-2026-08-25-packaging (conflicting; unverified).
4. **Funding:** Company does not state. HN commenter says ~$29M [ESTIMATE, unverified] https://zeli.app/story/50526537 . Team: NOT FOUND.
5. **Traction:** NOT FOUND.
6. **Channel:** NOT FOUND.
7. **Outcome:** Shutdown announced 2026-11-16/17 by founder Kevin Moody (blog, via aggregator dated 2026-11-17; HN discussion 126 comments) [FOUNDER] https://zeli.app/story/50526537 . No reason stated. Repricing toward usage-metered AI immediately precedes the shutdown.
8. **Lesson:** An AI-notes app paying for cloud inference per user failed to find a pricing level that worked and gave users ~2 months to export; on-device inference removes exactly the variable cost that the late repricing was chasing.

---

## Reflect Notes

1. **What:** Networked notes with GPT-style AI. Mac (free, no subscription), iPhone/iPad (paid subscription); Android not mentioned [OFFICIAL] https://reflect.app/ .
2. **Privacy:** Local files, bring-your-own API key; AI calls go directly to the user's provider; private notes excluded from AI [OFFICIAL, same]. App Store lists E2EE and "Reflect App, LLC" [OFFICIAL] https://apps.apple.com/ms/app/reflect-notes/id1575595407 .
3. **Pricing:** Official page says Mac app free; mobile requires subscription, price not shown. Third-party: $10/month billed annually ($120/year), $15 monthly, 14-day trial, no free tier [ESTIMATE] https://costbench.com/software/note-taking/reflect/ (conflicting; unverified, page not opened). **Official pricing: NOT FOUND.**
4-7. Funding, traction, channel, outcome: NOT FOUND.
8. **Lesson:** BYO-API-key keeps vendor cost zero; this is a tiny-niche model. Note the platform bias (no Android).

---

## Notion AI (brief: pricing only)

- Notion pricing (https://www.notion.com/pricing, fetched 2026-11-24) [OFFICIAL]: Free $0; Plus $10; Business $20 (recommended); Enterprise custom; per member/month, up to 20% off yearly. Free and Plus: Notion AI is a trial only. Business: Notion Agent and AI Meeting Notes included. **Custom Agents are metered: "Free to try, then $10 per 1,000 monthly Notion credits."**
- Notion confirmed AI features stay included on Business/Enterprise with no price change, credits for Custom Agents on sale from 2026-05-04 [OFFICIAL] https://www.notion.com/fr/help/custom-agent-pricing (via search summary).
- Lesson: AI was moved from add-on to bundled in the higher seat tier, with metered credits only for autonomous agents; incumbents bundle, not separately sell, basic AI.

---

## Cross-Category Patterns (What Users Pay For, Hardware Bundles, Exit Outcomes)

| Company | Cloud/on-device | Entry hardware | Sub price (annual / monthly) | Free tier gate | Traction (source type) | Outcome |
|---|---|---|---|---|---|---|
| Otter | Cloud | none | Pro $8.33/mo yr, $16.99 mo | 300 min, 30-min meetings, 25 history | $100M ARR, 40M users | Raised $320M revenue-share debt; privacy class action |
| Granola | Cloud (no audio stored) | none | Business $14/seat/mo | 30-day history, no integrations | $1.5B val; no ARR | Series C Mar 2026; Android Jul 2026 |
| Limitless | Cloud | $99 pendant | ~$19-29/mo [ESTIMATE] | 10 h AI/mo [ESTIMATE] | ~$2M ARR [ESTIMATE], 10K pre-orders | Acquired by Meta Dec 2025; pendant discontinued, EU/UK cut off |
| Bee | Cloud, audio deleted | $49.99 -> $74.99 | Pro $11.99/mo, ~$99/yr [PRESS] | 14 days history free | not disclosed | Acquired by Amazon (Jul 2025); freemium relaunch Oct 2026 |
| Plaud | Cloud | $159-189 | Pro ~$99.99/yr, Unlimited ~$239.99/yr | 300 min/mo | >2M devices; $100M sub ARR (company) / $250M (Bloomberg-based); ~50% convert (company) | Independent, profitable (claimed); $500M 2026 target |
| Rosebud | Cloud | none | $107.99/yr; $12.99 mo | not found | 7,500+ payers (Jun 2025); ~$50-100K MRR [ESTIMATE] | $6M seed |
| Day One | Cloud, E2EE | none | Silver $49.99, Gold $74.99/yr | 1 device, 1 photo, no voice | 10M+ downloads | Owned by Automattic |
| Stoic | Local + optional cloud/AI | none | $6.99-$39.99 + AI tiers; lifetime $299 | not found | 4M+ downloads | Active |
| Mindsera | Cloud | none | $129/yr, $14.99 mo | basic journaling | not found | Active |
| Mem | Cloud | none | $12-14.99/mo then metered | n/a | NOT FOUND | **Shutting down 2027-01-15** |
| Reflect | Local + BYO API | none | ~$120/yr [ESTIMATE] | Mac free | NOT FOUND | Active |
| Notion AI | Cloud | none | Business $20/seat; agent credits $10/1,000 | AI trial only | n/a | Bundled |

**Patterns**

1. **What users pay for:** Capacity and convenience, not the base capture. Gates are minutes (Otter, Plaud), history length (Otter, Granola, Bee), device sync (Day One), voice/audio transcription (Day One Silver), and AI depth (Rosebud, Day One Gold). Every company in this set runs cloud inference, so each gate maps to a variable cost; Eudemonia's cost structure is different.
2. **Price points:** Consumer annual price clusters at ~$50-130/year (Day One $49.99-$74.99, Rosebud $107.99, Mindsera $129, Plaud Pro $99.99, Bee ~$99). Lifetime exists at the local-first end (Stoic $299). Meeting tools price per seat ($14-$30/month).
3. **Hardware bundles:** Hardware is a distribution and trust lever, not just margin: Plaud sells $159-189 devices with a free 300-minute funnel and claims ~50% paid conversion (company claim); Sacra estimates ~25% hardware gross margin. Cheap hardware ($49.99 Bee) with a sub has been absorbed by Amazon. No evidence found that a phone-only (no hardware) capture app has matched those economics; the volume-button trigger is Eudemonia's "free hardware".
4. **Exit outcomes:** Of the wearables, both small ones (Limitless, Bee) were acquired by big platforms within ~2 years, with users cut off or repriced; Plaud is the independent winner. Mem (pure cloud AI notes) is shutting down. Otter is financing sales with revenue-share debt, not equity. Consumer journaling apps stay small (Rosebud $6M seed, ~7.5K payers) except Day One inside Automattic.
5. **Privacy as differentiator:** Incumbents run cloud transcription with third-party LLMs (Granola names Deepgram/AssemblyAI/OpenAI/Anthropic), face litigation (Otter), or changed policies after acquisition (Limitless/Meta). No competitor here is fully on-device with zero network traffic; Stoic/Reflect are the nearest (local storage, optional AI).
6. **Android gap:** Granola only reached Android in Jul 2026 and scoped it to in-person capture; Plaud, Bee, Rosebud, Day One, Mindsera, Stoic have Android apps; Limitless and Reflect: not found.

**Not verified / open items:** Plaud first-party pricing pages (blocked, used global.plaud.ai + third party); Plaud ARR definition conflict ($100M vs $250M); Granola ARR/users/team; Bee official Pro price and unit sales; Rosebud real revenue and free-tier limits; Reflect official price; Mindsera/Stoic funding and traction; Mem funding; Otter headcount and Android; Limitless total units and subscriber count.
