# Local-First / Privacy-First / On-Device-AI Monetisation Precedents

Research date: 2026-11-24. Method: web search plus page fetches done on 2026-11-24. Fetched pages were read through a summarising tool, so quotes are as returned by it; anything that looked inconsistent is flagged.

Label key: [OFFICIAL] = vendor's own page or docs. [PRESS] = news/third-party reporting. [FOUNDER] = statement by a founder/maintainer. [ESTIMATE] = third-party tracker or blog estimate, unverified. "NOT FOUND" = searched, nothing reliable.

---

## Obsidian

**What / platforms.** Local-first Markdown notes. Free core app, no sign-up needed. Desktop, iOS, Android. [OFFICIAL] https://obsidian.md/pricing (fetched 2026-11-24: "Free without limits", no sign-up required).

**Current pricing (fetched 2026-11-24).** [OFFICIAL] https://obsidian.md/pricing
- Sync: $4 per user per month billed annually, $5 billed monthly.
- Publish: $8 per site per month billed annually, $10 monthly.
- Catalyst: $25 one-time (early access to betas, badges, channels; no functional unlock of the core app).
- Commercial: $50 per user per year (optional).
- Refunds: Sync and Publish 7 days; Catalyst, Commercial and Credit are non-refundable. 40% discount on Sync/Publish for students, faculty and nonprofit staff.

**CONFLICT on Sync tiers.** The pricing page above shows one Sync tier. https://obsidian.md/sync (fetched 2026-11-24, [OFFICIAL]) still shows two: Standard $4/mo annual ($5 monthly), 1 vault, 1 GB, 5 MB max file, 1 month history; Plus $8/mo annual ($10 monthly), 10 vaults, 10 GB (up to 100 GB), 200 MB max file, 12 months history. The Standard tier was announced 2024-03-20: https://obsidian.md/blog/standard-plan/ [OFFICIAL].
- A competitor blog (remio.ai) claims a June 2026 Sync price hike with the 1 GB tier removed, about 35% rise, no grandfathering, 300+ forum replies: https://www.remio.ai/post/obsidian-s-sync-pricing-hike-triggers-community-backlash [ESTIMATE, unverified]. The official blog index (https://obsidian.md/blog/, fetched 2026-11-24) lists no 2026 pricing post, only the Cure53/Trail of Bits Sync audit (2026-05-13), plugin/community posts and the Oct 2026 community post. Treat the hike as UNCONFIRMED.

**What is gated.** Only server-side services (Sync, Publish) and optional support tiers. All app features are free. [OFFICIAL] https://obsidian.md/blog/free-for-work/ ("All features are available free, without limits"; no account, no ads or tracking; data local in plain-text Markdown).

**2025 commercial licence change.** On 2025-02-20 the Commercial licence became optional; previously orgs with 2+ employees had to buy it. Reasons given: terms were confusing, and the Obsidian Manifesto. Orgs buying 25+ seats are featured on the Enterprise page. Over 10,000 organisations use Obsidian for work (named: government, cybersecurity, healthcare, finance). [OFFICIAL] https://obsidian.md/blog/free-for-work/ (2025-02-20). Press: https://alternativeto.net/news/2025/2/obsidian-is-now-free-for-work-purposes-making-the-commercial-license-optional [PRESS].
- The Commercial licence page: priced per seat, one key works on all of a person's devices; applying it "does not provide any functional benefits within the app"; air-gapped orgs need not apply it in the app; in-app activation is Settings > General > Commercial license; web purchase needs an Obsidian account; non-refundable; does not include Sync, Publish or Catalyst. [OFFICIAL] https://obsidian.md/help/teams/license. This is an honour-system licence: the key unlocks nothing.

**Funding / team.** "100% supported by our users, not investors." Team size and revenue not stated. [OFFICIAL] https://obsidian.md/about. Founders listed: Shida Li (co-founder, CTO), Erica Xu (co-founder, COO), Steph Ango/kepano (CEO). Sync's flexible-plans post says growth "past a million users" (2023-11-21): https://obsidian.md/blog/new-sync-plans/ [OFFICIAL]; it also says the aim is to keep the price Obsidian launched with in 2020.
- Revenue/headcount are only third-party estimates and conflict: Latka ~$2M 2025 revenue and ~18 staff; Taskade ~$25M ARR (derived from $2M/month, Sept 2025); Everydev $2M-$5M ARR and 8 staff; 1.5M MAU (Taskade). Sources: https://getlatka.com/companies/obsidian.md/team , https://www.taskade.com/blog/obsidian-history , https://www.everydev.ai/developers/obsidian [ESTIMATE]. Obsidian does not publish revenue. Any figure here is unreliable by roughly an order of magnitude.

**Payment / licensing without violating privacy.**
- Sync, Publish and Catalyst are bought on the website against an Obsidian account; the app itself needs no account unless you use those services. [OFFICIAL] https://obsidian.md/blog/free-for-work/.
- Android: a forum request (2024-03-02, still open in May 2025 replies) asks for Play Store billing because payment is website-only: https://forum.obsidian.md/t/payments-accept-payments-via-the-playstore/77901 [FOUNDER-adjacent community thread; no staff reply on the page]. I could not confirm whether Obsidian sells anything through Play billing today.
- Takeaway: the paid products are the ones that cost the vendor money (storage and bandwidth); the revenue from "support" tiers (Catalyst, Commercial) is pure honour system.

---

## FUTO Voice Input and FUTO Keyboard

**What / platforms.** Android only. FUTO Keyboard has on-device voice input built in (Whisper models); FUTO Voice Input is the standalone app usable with other keyboards. "Designed to work entirely on-device with no data stored." Distribution: Google Play, F-Droid, standalone APK (~70 MB); Voice Input listed as v2.1 (375). [OFFICIAL] https://voiceinput.futo.tech/ (fetched 2026-11-24). Development has largely shifted to FUTO Keyboard. [OFFICIAL] https://raw.githubusercontent.com/futo-org/voice-input/master/README.md.

**Pricing (fetched 2026-11-24).**
- "The FUTO Keyboard costs $6.99 if purchased through FUTO Pay or $11.99 if purchased through the Google Play Store." Also: "Pay for it if you like it." [OFFICIAL] https://docs.keyboard.futo.tech/print
- One-time payment, "No recurring subscriptions"; the licence "is also valid for FUTO Keyboard"; the FUTO payment page frames it as support ("Your contribution ensures FUTO Keyboard remains ad-free and fully functional"). [OFFICIAL] https://keyboard.futo.tech/ and https://voiceinput.futo.tech/. The voiceinput page itself shows no price. The keyboard page lists no dollar amount; the amount comes from the docs page above.
- The price gap ($6.99 vs $11.99) is FUTO's own way of passing on Play's fee and tax; the breakdown is not stated. Interpretation only.
- Not pay-what-you-want in the strict sense (a fixed one-time price, but non-enforced). Earlier descriptions as "PWYW" should be treated as loose. NOT FOUND: any official "pay what you want" wording.

**What is gated.** Nothing functional found. The docs describe a payment notice only. [OFFICIAL] https://docs.keyboard.futo.tech/print: "FUTO Keyboard does not have a license key verification system due to being offline." Payers tap "I already paid"; the payment notice "normally displays 30 days after you install the keyboard"; Developer Settings has a "Show Notice" toggle. This is the clearest precedent for an honour-system, offline, zero-server licence in an Android app.

**Licence.** FUTO Source First License (Voice Input README states 1.0). The licence was designed to let FUTO "demand compensation for commercial use"; 1.0 restricts use/modification to non-commercial purposes; critics say it is not open source. [OFFICIAL] https://futo.org/about/futo-statement-on-opensource (quoted via search summary), https://scancode-licensedb.aboutcode.org/futo-sfl-1.0.html [OFFICIAL/PRESS]. FUTO's "source first" principles: users get source; non-commercial redistribution allowed but modified versions may not strip payment links; large organisations are "obligated to pay"; no ads; telemetry only opt-in; rejects "the user is the product". [OFFICIAL] https://futo.tech/source-first. Exact 1.1 terms: not retrieved.

**Build flavours (how payment coexists with F-Droid).** Voice Input: `dev` flavour has Play Store billing and all payment methods; `playStore` has Play billing only; `standalone` and `fDroid` exclude billing. [OFFICIAL] https://raw.githubusercontent.com/futo-org/voice-input/master/README.md. So the F-Droid build has no billing code at all.

**Payment rail.** FUTO's payments page lists FUTO Keyboard VoiceInput, FUTO Notes licence, Grayjay licence and Immich licences, with checkout links through Polar: https://pay2.futo.org [OFFICIAL]. Polar is a merchant of record, fees 5% + 50c (Starter), 4% + 40c (Early Member, orgs created before 2026-05-27), +1.5% for non-US cards, $15 per dispute: https://polar.sh/docs/merchant-of-record/fees [OFFICIAL] (2026-11-24).

**Funding / team.** FUTO says it "is not reliant on any existing tech company or venture capital firm"; founded 2021 by Eron Wolf (ex-Yahoo Games, WhatsApp seed investor); funded via in-house projects, investments and grants; "Revenue, if it exists, comes from customers paying directly". Team size and total funding: NOT FOUND. [OFFICIAL] https://futo.tech/blog/what-is-futo.

**Numbers.** FUTO publishes no sales figures (NOT FOUND). Play tracker: Voice Input about 63K installs, 753 ratings, 4.33 stars, "Free" with in-app purchases (updated 2026-11-16): https://appgoblin.info/apps/org.futo.voiceinput [ESTIMATE]. FUTO Keyboard install count: NOT FOUND.

---

## Private LLM, PocketPal AI, Enclave AI and other paid local-LLM mobile apps

### Private LLM (Numen Technologies Limited)
- One-time purchase, no subscription, iPhone/iPad/Mac, Family Sharing for up to 6 people; Android not mentioned. [OFFICIAL] https://privatellm.app/en (2026-11-24; the page shows no price).
- PRICE CONFLICT: App Store listing fetched 2026-11-24 shows $4.99 one-time, 4.1 stars from 755 ratings, v1.9.18 (Oct 28, year not shown): https://apps.apple.com/us/app/private-llm-local-ai-chatbot/id6448106860 [OFFICIAL]. A search result for the same app showed $9.99 (US), EUR 9.99 and INR 399; one G2 listing shows "$9.99/mo", which looks like an error: https://apple.co/43n6BsW and https://ai.g2.com/marketplace/tools/personal-gpt [PRESS/ESTIMATE]. Possible explanation: sale price or different SKU (iOS vs macOS). Not resolved.
- Revenue/team: NOT FOUND. One App Store review claims the app connects to the internet when it can (single user review, unverified).

### PocketPal AI (open source, Android + iOS), the closest Android precedent for "free app + optional one-time unlock"
- MIT licence; iOS and Android; 9.8k GitHub stars; Chat, models, voices and tools free with no account; optional one-time "PocketPal Plus" on App Store and Google Play adds hands-free voice conversation and a local API server. Builds from source include all Plus features; so does the GitHub-Releases APK from the release after v1.23.0. GitHub Sponsors link; premium community "Pals" via in-app purchase. [OFFICIAL] https://github.com/a-ghorbani/pocketpal-ai and https://raw.githubusercontent.com/a-ghorbani/pocketpal-ai/main/README.md (2026-11-24). Price of Plus: NOT FOUND (README does not state it; Play page not retrievable).
- Install/monetisation numbers conflict: apppricinglab (data as of 2026-03-10) shows 500K installs, 3.9 stars from 1.8K reviews, "no in-app purchases" (Plus apparently not yet live): https://apppricinglab.com/app/google_play/com.pocketpalai [ESTIMATE]. AppGoblin (updated 2026-11-19) shows 3.3M installs, 3.54 stars from 3.9K ratings, IAP is 100% of monetisation, "$10K+ per month" revenue estimate, 348K MAU: https://appgoblin.info/apps/com.pocketpalai [ESTIMATE]. Treat the revenue number as a loose lower bound from a tracker, not a fact. Developer shown as "LLM Ventures".
- Why it matters: they ship the paid feature set inside the open-source APK on purpose, so payment is "pay to support and get convenience via the store", not DRM.

### Enclave AI (iOS/iPadOS/macOS/visionOS)
- Free with in-app purchases; local models (Llama, Gemma, Qwen etc.) work offline without account; a Pro subscription listed at $9.99 unlocks cloud models (Anthropic, OpenAI, Google, xAI). 4.7 stars from 1.1K ratings; developer Piotr Gorzelany. [OFFICIAL] https://apps.apple.com/us/app/enclave-local-ai-assistant/id6476614556 (2026-11-24). Privacy label lists some analytics/diagnostics (not verified by Apple). Pattern: the subscription is attached to a cloud feature, not to local inference. Android: NOT FOUND.

### Layla (Layla Network Pty Ltd, Australia; iOS + Android)
- $19.99 one-time on App Store and Google Play per a Sept-Oct 2026 review (review updated 2026-10-30, v7.6.0); US App Store in-app tiers Monarch $4.99, Birdwing $19.99, Blue Morpho $29.99 (each with a yearly price); free feature-limited Android APK from developer; 3.8 stars from 33 App Store ratings; Play listing requires a 4 GB model download and says flagship phones (8 GB+ RAM) only. https://www.promptquorum.com/power-local-llm/layla-review [PRESS]. Play installs: NOT FOUND. Play listing: https://play.google.com/store/apps/details?id=com.layla (not retrievable).

### Others seen (iOS only, one-time, on-device Whisper)
Whisper Notes, Viska, AirTranscript ($1.99), WalkWrite (free core + one IAP): https://apps.apple.com/app/id6447090616 and others, listing only, via search [PRESS]. No Android versions found.

---

## MacWhisper and VoiceInk (desktop local transcription, one-time purchase)

### MacWhisper (Jordi Bruin / Good Snooze; macOS)
- Official page (fetched 2026-11-24): Free "forever" and Pro EUR 64 per licence, paid once, includes lifetime updates; all purchases through Gumroad or the App Store. Page warns about scam sites impersonating it. [OFFICIAL] https://macwhisper.com
- Third-party reads (competitor blogs, checked 2026-09-28, article updated 2026-11-07) of the App Store edition, "Whisper Transcription": Pro Monthly $6.99, Yearly $29.99, Lifetime $99.99, plus a cloud "Assistant" at $5.99/wk, $9.99/mo or $89.99/yr; one source also lists $8.99 / $89.99 variants. Gumroad keys do not unlock the App Store version; App Store version lacks system-wide dictation/meeting detection and offers fewer BYO-key providers. https://www.getvoibe.com/resources/macwhisper-pricing/ [ESTIMATE; competitor-run].
- Gumroad price conflict: EUR 59 (~$69) vs EUR 64 across third-party pages; the official page shows EUR 64. https://usevoicy.com/blog/macwhisper-pricing/ [ESTIMATE].
- MacWhisper 14 launched 2026-07-14; existing Pro users get the upgrade "at no additional cost"; a 14% discount for upgrading to Pro was mentioned. https://9to5mac.com/2026/07/14/macwhisper-14-launches-with-a-new-transcript-editor-faster-performance-more/ [PRESS].
- Team/revenue: NOT FOUND. Apple Developer interview exists (https://developer.apple.com/news/?id=77glyihi) and mentions 20+ App Store titles from Good Snooze, no revenue [PRESS, from search summary].
- Gumroad fee: 10% + $0.50 on direct sales, 30% on sales from Gumroad Discover; Gumroad is merchant of record "since January 1, 2025". [OFFICIAL] https://gumroad.com/pricing (2026-11-24).
- Lesson: the same product sold as lifetime on the web and as subscription+lifetime on the App Store, because Apple/Google stores steer toward subscriptions and feature sets diverge.

### VoiceInk (Prakash Joshi / "Pax", macOS, GPL v3)
- Solo $25 (1 Mac), Personal $39 (2 Macs, "Most picked"), Extended $49 (3 Macs); all one-time, lifetime updates, 14-day money-back; free trial button; requires macOS 15+. [OFFICIAL] https://tryvoiceink.com/buy (2026-11-24). Licence-key activation mechanics: NOT FOUND on the page.
- Code is GPL v3 and can be built from source for free; the official build needs a licence. https://www.getvoibe.com/resources/voiceink-pricing/ [ESTIMATE; competitor-run].
- An iOS companion app exists: 1.7K installs, 220 MAU per a tracker, revenue not available: https://appgoblin.info/apps/6751431158 [ESTIMATE].
- Revenue, team size, funding: NOT FOUND. Gumroad vs App Store for VoiceInk: NOT FOUND (the Mac app is sold from its own site).
- Lesson: open-source code + paid convenience build is a viable one-time model, with the price scaled by device count (a cheap proxy for seat licensing).

---

## Hyprnote / Char / Anarlog (open-core local-first meeting notes)

- Hyprnote (YC S25 per YC profile, team of 4, founded 2023) was renamed Char, then split: the meeting notetaker is now **Anarlog**; the name **Char** now belongs to a different product, an AI todo notepad in private alpha that "will become paid SaaS when it ships". Post dated 2026-05-03, with an August 2026 update saying migration is complete. Anarlog relicensed GPL to MIT. [OFFICIAL] https://anarlog.so/blog/char-is-now-anarlog/ . YC profile (via search): https://www.ycombinator.com/companies/char [PRESS/OFFICIAL, not fetched directly].
- Anarlog pricing (fetched 2026-11-24): Free: unlimited on-device transcription, local recordings, notes, chat/exports, local API, CLI, MCP, webhooks, manual speaker labels, bring-your-own keys. Pro $14 per person per month or $140 per person per year: hosted transcription and cloud LLM, scheduled auto-record, custom templates, system-wide dictation, better speaker ID, cloud sync (3 devices), E2E encryption, sharing/workspaces/team features, per-seat billing; 30-day Pro trial. Enterprise custom (SSO, SCIM, audit, customer-hosted data plane). [OFFICIAL] https://anarlog.so/pricing
- Funding amount, revenue: NOT FOUND (no figures in any result).
- Lesson: the open-core split is local = free, cloud/sync/teams = paid. It monetises the server-side parts and the team seat, which is the opposite of Eudemonia's no-network constraint. Also a cautionary tale: the product was renamed twice and the local one is explicitly deprioritised ("daily focus is now Char").

---

## Standard Notes, Joplin, Logseq, Anytype (brief)

### Standard Notes
- Free "Standard" plan ($0/year): E2E encryption, unlimited device sync, plain text, offline access, tags, password-protected notes, full export, 2FA, daily encrypted email backups. Productivity $90/year; Professional $120/year (100 GB encrypted storage, sharing for up to 5 accounts, longer history, hardware keys, 90-day refund). A "50% off annual plans" Black Friday banner was showing at fetch time, so list vs discounted price is ambiguous. [OFFICIAL] https://standardnotes.com/plans (2026-11-24).
- Acquired by Proton in April 2024 (second Proton acquisition after SimpleLogin), promised to remain open source with pricing unchanged: https://proton.me/blog/proton-standard-notes-join-forces and https://techcrunch.com/2024/04/10/proton-standard-notes/ [OFFICIAL/PRESS, via search]. A Dec 12, 2025 post says it "remains a distinct product with its own brand, subscription, roadmap"; commenters say founder Mo Bitar has left and nobody clarified who runs it: https://discuss.privacyguides.net/t/standard-notes-2025-update-what-s-new-and-whats-next/33774 [PRESS/community, 2025-12-12]. No sunset found.

### Joplin
- Free open-source app. Paid: Joplin Cloud Basic EUR 2.99/mo (EUR 28.69/yr), Pro 30 GB EUR 5.99/mo (EUR 57.48/yr), Pro 100 GB EUR 9.99/mo (EUR 95.88/yr), Teams EUR 7.99/user/mo (min 2 users); Joplin Server Business self-hosted EUR 40/35/30 per user per year by seat band. [OFFICIAL] https://joplinapp.org/plans/ (2026-11-24). Also funded by PayPal, GitHub Sponsors and Patreon donations: https://joplinapp.org/donate/ [OFFICIAL]. Sponsor numbers snapshot (107 current, 509 past, $1 minimum) is a third-party aggregator, possibly stale: https://sponsors.ecosyste.ms/accounts/laurent22 [ESTIMATE]. Revenue and team: NOT FOUND; no VC per third-party review (unverified).

### Logseq
- $4.1M seed (2022) with angels incl. Patrick Collison, Tobi Lutke, Nat Friedman; investors in TechCrunch also list a16z, Matrix, Craft, Day One. Premium features were the stated planned revenue. https://venturebeat.com/business/meet-logseq-an-open-source-knowledge-management-system-that-stores-data-like-a-brain and https://techcrunch.com/2022/05/05/this-open-source-tool-used-by-google-meta-and-mit-is-helping-rethink-knowledge-management/ [PRESS].
- Today it is largely funded via Open Collective: balance $35,939.53, estimated annual budget $232,011.24, $774,231.98 raised in total, 12,248 contributors (fetched 2026-11-24): https://opencollective.com/logseq [OFFICIAL]. A 2026-07-13 update says the DB-version beta and real-time sync are in testing for monthly backers: https://opencollective.com/logseq/updates [OFFICIAL, via search]. No public paid Sync launch found. A 2026 roundup claiming Logseq Sync $4/mo and Publish $8/mo matches Obsidian's numbers exactly and is not confirmed [ESTIMATE; ignore].

### Anytype
- $13.4M round led by Balderton, 2023-08-23 (dollars, not euros): https://blog.anytype.io/anytype-raises-13-4million-usd-funding/ and https://balderton.com/?p=9192 [OFFICIAL/PRESS]. Total raised $29.12M per CB Insights [ESTIMATE]. 80,000 monthly users in 2025 per a community post [FOUNDER-ish, unverified].
- Model: free when you run it on your own resources ("will always be free when used with your own resources"); paid membership unlocks network sync, remote storage, shared spaces, unique name. https://blog.anytype.io/our-memberships-philosophy/ [OFFICIAL, 2024-03-18]. Docs say desktop purchases are charged in USD via Stripe; iOS/Android purchases go through the App Store/Play Store: https://doc.anytype.io/anytype/resources/memberships.md [OFFICIAL]. Current tier prices: NOT FOUND on official pages (they render client-side); docs have said Builder $96/year or $10/month and Co-Creator $299 for three years (search snippet), while one tracker reports Plus $4 / Pro $8 / Ultra $16 as of 2026-11-17. UNVERIFIED, treat both as unconfirmed.

---

## Android apps that sell on-device AI transcription/notes (searched specifically)

- **Offscript** (Richfield Labs; Android + iOS): AI voice notes, transcribes locally with Whisper, SQLCipher/AES-256-GCM encryption, biometric lock; free tier limited; premium (AI summaries, action items, tags, PDF/MD/CSV export, calendar integration, encrypted backup). One-time $60 and/or subscription $3 to $20 per month listed by an aggregator. https://alternativeto.net/software/offscript/about [ESTIMATE; aggregator, not the Play listing]. Installs and revenue: NOT FOUND. This is the only Android on-device-transcription app with a stated one-time price I could find; most comparable one-time Whisper note apps are iOS-only.
- **FUTO Keyboard / Voice Input**: see above (about 63K Play installs for Voice Input per tracker).
- **Layla** and **PocketPal Plus**: on-device LLM, not transcription: see above.
- No Android on-device-transcription app with public revenue or user numbers was found. NOT FOUND.

---

## Subscription Benchmarks (Conversion, Retention, Android vs iOS)

Sources: RevenueCat "State of Subscription Apps 2026" (data from 115,000+ apps, $16B+ revenue) https://www.revenuecat.com/state-of-subscription-apps-2026/ [OFFICIAL, fetched 2026-11-24; the report page is ~200K chars and was read in two chunks by a summariser, so some figures conflict inside the report itself]; RevenueCat blog summary published 2026-03-19 https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026.md [OFFICIAL]; Adapty "State of in-app subscriptions 2026" updated 2026-03-13 https://adapty.io/blog/mobile-app-monetization-2026/ [OFFICIAL].

**Conversion**
- Download-to-paid at Day 35, all apps median: 2.0%; by region North America 2.8%, Asia-Pacific 2.4%, India/SE Asia 0.7%. The report intro gives North America as 2.6%; internal inconsistency. [OFFICIAL] RevenueCat 2026 report. By price tier: high 2.8%, mid 2.0%, low 1.4%. By category: Health & Fitness 2.9%, Business 2.6%, Shopping 1.3%, Gaming 1.0%. Productivity-specific download-to-paid: NOT FOUND in the retrievable portion. Utilities: not given.
- Hard paywall vs freemium, Day 35: 10.7% vs 2.1% (the 2026 blog calls this "trial-to-paid", the report calls it "download-to-paid"; labels are inconsistent). Revenue per install: Day 14 $2.32 vs $0.27; Day 60 $3.09 vs $0.38. Hard-paywall figure fell from 12.1% in 2025. "Apps whose features are exclusive to paid users convert 5x better than those with free options." [OFFICIAL] RevenueCat 2026 (blog 2026-03-19).
- Trial-to-paid by trial length: 17-32 days 42.5%, 5-9 days 37.4%, 4 days or less 25.5%. By region: North America 34.2%, Western Europe 29.7%, Asia-Pacific 31.9%, India/SE Asia 15.2%. [OFFICIAL] RevenueCat 2026.
- AI apps: download-to-paid 2.4% vs 2.0% non-AI (per search summary of report, [PRESS] https://ppc.land/ai-apps-earn-41-more-per-user-but-churn-30-faster-revenuecat-finds/); 41% more revenue per payer (Y1 realised LTV median $30.16 vs $21.37); churn faster: 12-month retention yearly 21.1% vs 30.7%, monthly 6.1% vs 9.5%. [OFFICIAL] RevenueCat 2026 report/blog.
- Productivity category: 78% of trials start on Day 0 (lowest of any category); ~72% of paid conversions happen on Day 0 (highest); Y1 realised LTV per payer after year 1 median $24.95; highest refund rate of any category, 4.7%; annual renewal 85.6%; monthly retention 28.2% (about 11 pp below the 39.2% overall); 44% of cancellations on Google Play are "cost related"; AI penetration 41.1%. [OFFICIAL] https://www.revenuecat.com/state-of-subscription-apps-2026-productivity . The category's plan mix is internally contradictory (monthly 77% in one place, yearly 77% in another, monthly 91% of revenue in a third); do not use. The Productivity bucket includes Graphics & Design and Developer tools.

**Retention at 12 months** [OFFICIAL] RevenueCat 2026: yearly plans median fell 31% to 28% (freemium 28%, hard paywall 27%); monthly 10% to 8%; weekly 1.7% to 1.2%. The 2026 blog also says about 72% of annual subscribers cancelled in Year 1 (2026) vs about 56% in 2025. Low-priced apps have 36% one-year subscriber retention vs 23% for high-priced apps.

**Median prices** [OFFICIAL] RevenueCat 2026: weekly $5.99, monthly $10 (one category section says $7 to $8), yearly $34.80 (up from $31.60). Adapty: monthly in Europe $15.25 vs North America $10.95 in 2025.

**Android vs iOS**
- Revenue share: iOS 84.75% of global subscription revenue vs Android 15.25%, though Android has about 70% of users; per-subscriber revenue gap about 5.5x. [OFFICIAL] Adapty, 2026-03-13. Adapty also says (blog summary via search, [PRESS] https://adapty.io/blog/how-much-does-a-subscription-app-make/) iOS converts about 3x better than Android; once an Android user starts a trial, conversion and retention are close to iOS.
- RevenueCat: Day 60 revenue per install global median $0.42 App Store vs $0.16 Google Play (one summary section says $0.23 for Google Play; conflict). Year-1 realised LTV per payer: $23.38 App Store vs $21.62 Google Play (about 8% gap); Western Europe $26.47 iOS vs $27.08 Google Play. Google Play leads at first renewal (monthly +3.5 pp, annual +7.6 pp). Billing errors cause 31% of Google Play cancellations vs 14% on the App Store. [OFFICIAL] RevenueCat 2026.
- Implication: Android payers are about as valuable as iOS payers; Android's gap is in getting anyone to pay. This is evidence against assuming a low conversion on Android is price-driven.

**Lifetime / one-time share** [OFFICIAL] RevenueCat 2026: subscriptions only 63.5% of apps; subscriptions plus lifetime 23.2%; subscriptions plus consumables 10.7%; all three 2.5%. Lifetime appears on 5% to 18% of paywalls (Gaming highest at 18%). Non-AI apps combine lifetime more than AI apps (25.3% vs 17.9%). Lifetime-dominant apps: Day 14 revenue per install $0.19, Day 60 $0.24 (vs hard paywall $2.32/$3.09; this is subscription-centric data and says nothing about apps with no recurring component). Refunds: Productivity highest at 4.7%; hard paywall 2.5%, freemium 2.9%; AI 4.2% vs non-AI 3.5%; low-price tier 2.7%, high 4.5%.
- RevenueCat's lifetime guide (2025-11-12): lifetime is usually priced at 5-12x annual (range about 2x to nearly 12x; Calm $79 vs $399, Waking Up $129.99 vs $1,500); lifetime purchases are non-consumables, so free trials do not apply; risks: "life of the product", cannibalising loyal subscribers, investor preference for recurring revenue. https://revenuecat.com/blog/growth/lifetime-subscriptions [OFFICIAL].
- Adapty-cited growth of one-time/lifetime from 6.4% to 10.3% of monetisation models between 2023 and 2025 is a secondary citation: https://www.airbridge.io/en/blog/should-you-offer-a-lifetime-subscription [ESTIMATE].

**Not found:** an Android-specific one-time-purchase conversion benchmark; any benchmark for paid-upfront or one-time-only apps (RevenueCat/Adapty data are subscription-centric, so they under-describe Eudemonia's likely model); a Productivity download-to-paid number.

---

## One-Time vs Subscription vs Pay-What-You-Want Evidence

**Two-sided market for local apps (what practitioners actually do)**

| Model | Precedent | Source |
|---|---|---|
| Free app + paid server service (sync/publish) | Obsidian ($4-$8/mo Sync, $8 Publish), Joplin Cloud, Standard Notes, Anytype memberships | pages above [OFFICIAL] |
| Free app + optional "support" licence, nothing gated | Obsidian Catalyst $25 and Commercial $50/yr; Logseq via Open Collective | https://obsidian.md/pricing [OFFICIAL] |
| Fixed one-time, honour-system, no keys | FUTO Keyboard ($6.99 direct / $11.99 Play) | https://docs.keyboard.futo.tech/print [OFFICIAL] |
| One-time with device-count tiers, paid binary + open source | VoiceInk $25/$39/$49 | https://tryvoiceink.com/buy [OFFICIAL] |
| One-time Pro + free tier, lifetime updates | MacWhisper EUR 64 | https://macwhisper.com [OFFICIAL] |
| Free + one-time feature unlock, source build includes unlock | PocketPal Plus | https://github.com/a-ghorbani/pocketpal-ai [OFFICIAL] |
| Paid upfront on store, one-time | Private LLM ($4.99 or $9.99), Layla $19.99 | above [OFFICIAL/PRESS] |
| Hybrid: local free + cloud subscription | Enclave Pro $9.99, Anarlog Pro $14/mo | above [OFFICIAL] |
| Time-boxed perpetual (updates for N years) | Sublime Text personal licence "once off purchase, 3 years of updates" | https://sublimehq.com/store/text [OFFICIAL] |
| Donation-funded | Joplin (PayPal, Sponsors, Patreon), Logseq (Open Collective, balance $35.9K, ~$232K annual budget) | above [OFFICIAL] |

**Pay-what-you-want evidence (thin).**
- No credible software-specific PWYW dataset found. FUTO is the closest Android case but uses fixed-price honour-system, not true PWYW; its sales figures are not public. NOT FOUND.
- itch.io's own 2015 analysis: 30% of money spent on itch.io was "extra" above the minimum price; average purchase about $1.50 above minimum; free-content donations averaged $3.68. https://itch.io/blog/2/running-an-indie-game-store-2015 [OFFICIAL, 2015, games not utilities, stale]. A single creator reported 1,072 payments averaging about $4.98 ($7,276.70 gross): https://itch.io/post/259669/view-in-topic [FOUNDER, anecdote].
- Academic/behavioural work: a café experiment averaged $0.89 per cookie from a 0-$2 range, framing with social values lifted payments about 21%: https://www.library.hbs.edu/working-knowledge/name-your-price-really [PRESS]; payment after receiving a valued product is higher (Cambridge Judge): https://www.jbs.cam.ac.uk/2023/why-timing-affects-pay-what-you-want-amounts/ [PRESS]. Overall: average payments often below list price; results vary by context. Paying late, after value is delivered, helps. FUTO's 30-day notice is built on that insight (inference).

**One-time purchase sustainability problems (cases).**
- Screen Studio (bootstrapped team of five): removed its $229 lifetime licence for new customers on 2025-10-01; founder said the tier was "a mistake with low adoption" and the price "wasn't justified"; existing holders get updates through 2027-09-25 then can renew. https://alternativeto.net/news/2025/10/screen-studio-has-removed-their-non-subscription-licensing-options-for-new-customers [PRESS, 2025-10-01]. Reaction: some called it "misleading".
- Practitioner posts argue paid upgrades are hard to sustain (existing customers expect 15-50% discounts) and that a "paid lifetime updates" hybrid nearly doubled LTV of one-time buyers: https://www.indiehackers.com/post/subscriptions-vs-one-time-payments-a-developers-honest-take-f153e48960 and https://dev.to/godnick/why-i-chose-lifetime-pricing-for-my-dev-tools-and-would-do-it-again-25mb [FOUNDER, anecdotal, undated in extracts].
- Time-boxed updates (Sublime Text 3 years) and bundled minor updates (VoiceInk/MacWhisper "lifetime updates" while MacWhisper 14 was free for existing Pro) are the two workable patterns seen. Hybrid evidence: MacWhisper 14 shipped free to existing Pro users (2026-07-14) https://9to5mac.com/2026/07/14/macwhisper-14-launches-with-a-new-transcript-editor-faster-performance-more/ [PRESS].
- Google Play has no official paid-upgrade mechanism I could find for a one-time app: updates must keep the same package name and signing key; NOT FOUND any Google statement about charging for a major version. A developer-forum thread says that control "is not available in either store" [community, anecdote] https://www.b4x.com/android/forum/threads/upgrading-a-paid-application-to-an-expanded-version.63424/. So a "pay for v2" model on Play would require a new app listing or a new IAP, which sacrifices existing reviews/installs (inference).

**Backlash cases when a local/paid app moved to subscriptions.**
- Notability, 2021-11-01/02: moved to subscription; previously bought features were to stop working after a year; developer reversed within two days and gave prior buyers lifetime access; apology: "We heard the disappointment... and we want to correct our course." https://www.macrumors.com/2021/11/03/notability-changes-subscription-strategy-outcry/ [PRESS, 2021-11-03].
- Voice Dream Reader, April 2024: new owner Applause Group added a $79/yr subscription ($59 introductory) that would make the old version unusable; community learned of it from a developer reading a new build; reversed; promised one-time buyers keep existing features. https://mjtsai.com/blog/2024/04/08/voice-dream-reader-switches-to-subscriptions/ [PRESS, 2024-04-08].
- Screen Studio 2025 (above): criticism, no reversal.
- Pocket Casts: reported a switch of lifetime purchases to three-year plans followed by a reversal giving paid customers lifetime access (headlines only; article dates and details were not retrievable): https://windowscentral.com/pocket-casts-backtracks-will-now-give-paid-customers-lifetime-access-pocket-casts-plus [PRESS, date NOT FOUND].
- Obsidian Sync price rise (June 2026): UNVERIFIED, from competitor blog only (see Obsidian section).
- Pattern: reversals happen when existing buyers lose features they already paid for. Charging new buyers differently did not produce a reversal in these cases. Apple's guideline (3.1.2(a)) bars removing paid functionality; Google's equivalent: NOT FOUND.

**Platform fees that shape the one-time-vs-subscription choice (Google Play).**
- Google's fee page (fetched 2026-11-24, [OFFICIAL] https://support.google.com/googleplay/android-developer/answer/112622) shows, for the markets in the new table (EEA, UK, US, Australia, Japan): auto-renewing subscriptions 10% + 5% billing fee; other transactions on new installs 20% + 5%; existing installs 25% + 5% (20% for external web links). The 2026 rollout dates in that page: 2026-06-30 for EEA/UK/US, 2026-09-30 for Australia and Japan; remaining markets "once announced". For the rest of the world, the older 15% on the first $1M per year, 30% above, and 15% for subscriptions remains. TechCrunch (2026-03-04) reports 20% standard (from 30%), 10% subscriptions (from 15%), +5% if using Google billing, rolling out US/UK/EEA 2026-06-30, Australia 2026-09-30, Korea/Japan 2026-12-31, global 2027-09-30: https://techcrunch.com/2026/03/04/google-settles-with-epic-games-drops-its-play-store-commissions-to-20/ [PRESS]. The two sources do not match on the market list (Japan 2026-09-30 vs 2026-12-31); take the exact schedule from Play Console.
- Google's page on the Epic-related US programmes says external-content-links/alternative-billing developers in the US must report transactions and pay fees from 2026-10-01 (downloads fees reporting deadline 2027-02-01): https://support.google.com/googleplay/android-developer/answer/15582165 [OFFICIAL]. Fee percentages for those programmes: NOT FOUND on that page. Court-approval status of the settlement: unclear in my sources.
- Rule of thumb for the decision: a $10 one-time purchase on Play nets about $7.50-$8 after fees plus tax handling, vs about $9 on Polar/Gumroad-style merchant-of-record sale after the 5% + $0.50 (Polar) / 10% + $0.50 (Gumroad) fees. Arithmetic from the fee tables above [ESTIMATE].

---

## Licensing & Distribution Without Accounts or Cloud

**Google Play Billing with zero server.**
- Official guidance assumes a backend: "verify the purchase on your server"; send purchaseToken to your backend and check with the Play Developer API; "move sensitive logic to your backend". [OFFICIAL] https://developer.android.com/google/play/billing/integrate and https://developer.android.com/google/play/billing/security . A purely local app cannot follow this recommendation; the security page admits client-side logic is more tamper-prone.
- Acknowledgement is mandatory: purchases not acknowledged within 3 days are automatically refunded and entitlement revoked. Client-side acknowledgement is allowed (server-side recommended for poor connectivity). [OFFICIAL] same pages. For a no-account app this is a hard requirement to implement even offline.
- The app should call `queryPurchasesAsync` on launch and foreground to recover purchases across reinstall/other devices ("Multiple devices", "Network issues during the purchase"). [OFFICIAL] https://developer.android.com/google/play/billing/integrate . Whether this works fully offline: NOT CONFIRMED in the docs I fetched (the reference page says it returns owned items and does not document cache behaviour). It has to be tested on a device in airplane mode.
- Restore-on-new-device works through the user's Google account, so no Eudemonia account is needed. This is a property of Play (inference from the "multiple devices" note).
- Network traffic: Play Billing talks to the Play Store app, which makes the network calls; the app's own process need not open sockets. This is an architectural inference; I did not find an official statement. If "zero outbound bytes" is meant as a hard invariant (as in Eudemonia's own product principles), check whether the Billing library's manifest merges permissions such as INTERNET or ACCESS_NETWORK_STATE; this was not verified here.
- Legacy Play Licensing (LVL) is "primarily intended for paid applications", server-signed response, "much safer to verify... on a server"; deprecation status NOT CONFIRMED. https://developer.android.com/google/play/licensing [OFFICIAL].

**Honour system (no verification).**
- FUTO Keyboard: no licence key; "I already paid" button; payment notice after 30 days; developer-visible toggle. [OFFICIAL] https://docs.keyboard.futo.tech/print . Obsidian Commercial/Catalyst: the key unlocks nothing. [OFFICIAL] https://obsidian.md/help/teams/license . PocketPal: paid unlock is also in the free GitHub APK/source. [OFFICIAL] https://github.com/a-ghorbani/pocketpal-ai . All three treat payment as support plus convenience, not as a DRM gate.
- No data on honour-system payment rates (what share of users pay): NOT FOUND for FUTO, Obsidian, PocketPal.

**Licence keys, direct sale.**
- Tasker (Android) direct-purchase build: its own licensing server, independent of Google Play; $4 per licence via Patreon (one licence per $4 of lifetime support) or bulk orders of 25+; one device at a time; validation requires the device online with order code, device ID, Tasker version and Android version sent; offline activation not possible; licences cannot switch between the Play and direct versions. [OFFICIAL] https://tasker.joaoapps.com/userguide/en/faqs/faq-direct-purchase.html (2026-11-24). Note this breaks a "zero outbound bytes" promise at activation time.
- MacWhisper (Gumroad key, portable across Macs, EUR 64) and VoiceInk (licence key on site-sold build) are desktop examples; offline-activation behaviour for both: NOT FOUND. Sublime Text: key covers all computers/OSes; offline behaviour not stated. [OFFICIAL] https://sublimehq.com/store/text .
- Merchant-of-record rails with fees: Polar (5% + 50c Starter; 4% + 40c Early Member for orgs created before 2026-05-27; +1.5% non-US cards; $15 per dispute) https://polar.sh/docs/merchant-of-record/fees ; Gumroad (10% + $0.50 direct, 30% via Discover, handles all tax since 2025-01-01) https://gumroad.com/pricing [OFFICIAL, 2026-11-24].
- Cryptographically signed offline licence tokens (public key shipped in APK, no server call) are the standard way to verify without a server. I found no Android-app-specific source documenting this pattern; it is an engineering inference, not a researched precedent.

**Outside Google Play.**
- F-Droid: main repo is FLOSS only; proprietary tracking, advertising and analytics libraries, including Google Play Services, are "strictly forbidden"; apps failing to rebuild or with undisclosed anti-features are rejected; donation links must be verified by upstream developers (funding.json, FUNDING.yml, README, or the app's own website). Apps not meeting the criteria can use a separate repo. Paid apps / billing libraries: NOT FOUND in the policy, so the policy does not address them. [OFFICIAL] https://f-droid.org/docs/Inclusion_Policy . FUTO's approach: ship a separate `fDroid` flavour with no billing code, and a `standalone` flavour likewise. [OFFICIAL] https://raw.githubusercontent.com/futo-org/voice-input/master/README.md .
- Direct APK + own licensing: Tasker above; PocketPal APK on GitHub Releases; FUTO standalone APK (70 MB).
- Google's developer verification (Android Developer Console): requirement live for Brazil, Indonesia, Singapore and Thailand from 2026-09-30, global rollout planned 2027; applies to certified Android devices regardless of download source. Distributing only outside Play requires an Android Developer Console account, identity verification and package-name registration with the signing key. "Limited distribution" (students/hobbyists): no ID, no fee, up to 20 devices. "Sideloading unregistered apps" remains possible through an "advanced flow" with extra safeguards (24-hour wait per a press report) and adb. [OFFICIAL] https://developer.android.com/developer-verification/guides ; [PRESS] https://www.helpnetsecurity.com/2026/06/19/android-developer-verification-rollout-markets/ (2026-06-19). Registration fee for standard accounts: NOT FOUND. Consequence: a direct-APK-only distribution from 2027 would likely need identity verification, which removes the "no-friction anonymous sideload" path (inference).
- Google Play's own 2026 changes (Epic settlement): Play will not require Play Billing in the US and allows external links; fees on the new programmes start 2026-10-01 for US enrolled developers. [OFFICIAL] https://support.google.com/googleplay/android-developer/answer/15582165 . A "Third-party App Store on Play Program" took effect 2026-07-22 per the same page.
- Other stores (Galaxy Store, Amazon, Accrescent, Obtainium, IzzyOnDroid): not researched; NOT FOUND.

---

## Decision-Relevant Synthesis (for Eudemonia; evidence only, not a recommendation)

1. Every local-first precedent that earns real money charges for something with a marginal cost (Obsidian Sync/Publish, Joplin Cloud, Standard Notes, Anytype storage, Anarlog hosted AI and sync, Enclave cloud models). The pure-local precedents (FUTO, VoiceInk, MacWhisper, PocketPal Plus, Private LLM, Layla) use one-time or honour-system payment. Nobody found sells a recurring subscription for purely local inference without server features, except one-off hybrids.
2. FUTO is the only Android precedent with a no-server, no-key licence: fixed one-time price, a payment notice at 30 days, and an "I already paid" button; different prices by channel ($6.99 direct, $11.99 Play). Conversion rate: NOT FOUND.
3. Android's monetisation gap is conversion, not payer value (Adapty: 15% of subscription revenue vs about 70% of users; RevenueCat: Y1 realised LTV per payer $21.62 Google Play vs $23.38 App Store).
4. Backlash and reversals cluster around removing features from existing buyers (Notability, Voice Dream). The Screen Studio removal affected only new buyers and drew criticism without a reversal.
5. Technical constraint: Google's own billing documentation assumes a backend; zero-server operation relies on client-side acknowledgement within 3 days and `queryPurchasesAsync`; offline behaviour and the INTERNET-permission question are unverified.
6. Distribution outside Play is getting harder from 2026-09-30/2027 (developer verification), and F-Droid cannot carry Play Billing (FUTO's solution: a separate billing-free flavour).

## Items Not Verified

- Current Anytype and Logseq tier prices; Obsidian's June 2026 Sync hike; Private LLM's true price ($4.99 vs $9.99); PocketPal Plus price; Offscript Play price; Layla installs.
- Any revenue or sales numbers for FUTO, VoiceInk, MacWhisper, Offscript, Anarlog, Joplin, Obsidian (only third-party estimates).
- Whether Play Billing one-time purchase restore works fully offline, and the exact manifest permissions the Billing library adds.
- Honour-system payment rates.
- The Google Play fee schedule differs between sources for Japan/Korea; Play Console is authoritative.
