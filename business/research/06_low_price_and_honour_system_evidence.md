# Brief 06: Evidence on ultra-low subscription prices, honour-system payment and India pricing

Prepared 2026-11-25. All pages marked "fetched" were opened during this task on that date. Facts only; no strategy.

Labels: [OFFICIAL] company or Google/RBI page. [PRESS] news. [FOUNDER] founder's own post or interview. [ESTIMATE] third-party estimate, vendor blog or aggregator. [DERIVED] my own arithmetic from sourced numbers (shown so it can be checked). "Snippet only" means the figure came from a search-result summary and the page itself could not be fetched (403/blocked), so treat as lower confidence.

Prices being considered, for reference in the arithmetic: US $0.59 or $0.99 per month; India Rs 19 or Rs 29 per month.

---

## 0. Key reference numbers (quick view)

| Fact | Value | Source / label / date |
|---|---|---|
| RevenueCat 2026: median download-to-paid at day 35, low / mid / high-priced apps | 1.4% / 2.0% / 2.8% | https://www.revenuecat.com/state-of-subscription-apps [OFFICIAL], data year 2025, fetched 2026-11-25 |
| RevenueCat 2026: median revenue per install at day 60, low vs high-priced | $0.11 vs $0.94 | same page [OFFICIAL] |
| RevenueCat 2026: yearly-plan retention after 1 year, low / mid / high | 36% / 26% / 23% | same page [OFFICIAL] |
| RevenueCat 2025 edition: trial-to-paid, low vs high price | 47.8% vs 28.4% | https://www.revenuecat.com/state-of-subscription-apps-2025 [OFFICIAL], fetched 2026-11-25 |
| Bottom-quartile monthly price in RevenueCat 2025 data | $3.26 (median $6.68) | via https://www.airbridge.io/en/blog/subscription-app-pricing-by-category-2026-benchmark [ESTIMATE, citing RevenueCat], published 2026-05-13 |
| Google Play price floor | "as low as the equivalent of 5 US cents in any market" (May 2022) | https://android-developers.googleblog.com/2022/05/whats-new-in-google-play.html [OFFICIAL], dated 2022-05-11 |
| Google Play service fee on auto-renewing subscriptions | 15% | https://support.google.com/googleplay/android-developer/answer/112622?hl=en [OFFICIAL], fetched 2026-11-25 |
| Subscription price change: new vs existing subscribers | New price applies to new purchases within hours; existing subscribers stay on old price (legacy cohort) unless developer ends the cohort | https://developer.android.com/google/play/billing/price-changes [OFFICIAL], fetched 2026-11-25 |
| Play Console price experiments | Documented for one-time products only | https://support.google.com/googleplay/android-developer/answer/13343030?hl=en [OFFICIAL], fetched 2026-11-25 |

---

## 1. Price versus conversion in consumer subscription apps

### 1.1 RevenueCat State of Subscription Apps 2026 edition (data year 2025)

Source: https://www.revenuecat.com/state-of-subscription-apps [OFFICIAL], fetched 2026-11-25. No publication date shown on the page; methodology says "target time frame for metrics in this report is 2025"; launch data to February 2026.

Tier definition (verbatim from the page's Segments section): pricepoint is "how an app's average pricepoint compares to the rest of the measured apps (below average, average, above average)". No dollar thresholds are given. Tiers are relative, across different apps, not an experiment on one app.

| Metric (medians) | Low-priced | Mid-priced | High-priced |
|---|---|---|---|
| Download-to-trial (D30) | 4.4% | 5.4% | 8.9% |
| Download-to-paid (D35, "share of installs that result in at least one paid subscription within 35 days") | 1.4% | 2.0% | 2.8% |
| Top quartile download-to-paid | above 3.7% | above 4.4% | above 6.1% |
| Revenue per install, day 14 | $0.08 | not in fetched text | $0.61 |
| Revenue per install, day 60 | $0.11 | not in fetched text | $0.94 |
| Realized LTV per payer, 1-month plans | $6.67 | $15.78 | $35.89 |
| Realized LTV per payer, 1-year | $10.69 | $28.75 | $62.19 |
| Yearly-plan retention after year 1 | 36% | 26% | 23% |
| Top-quartile yearly retention | 53% | 41% | 34% |
| Refund rate | 2.7% | 3.9% | 4.5% |

Verbatim: "Median high-priced apps convert downloads 2x better than low-priced apps." "Low-priced apps retain better on yearly plans: 36% (low) vs. 26% (mid) and 23% (high)." "Price increases do clearly correlate to higher refund rates." Weekly retention "barely affected by price (under 3% median in every tier)". Trial-to-paid by price tier: not found in the 2026 page text (the pricepoint chart is download-to-trial; the page summary labels the same numbers "trial conversion", which conflicts with the chart title). A second RevenueCat summary (https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026, fetched) has no price-tier data; it points to https://www.revenuecat.com/sosa-26-insights/ for the full PDF (not fetched).

India / Southeast Asia (IN/SEA) rows in the same report (fetched):
- Download-to-paid D35 "IN/SEA median: 0.7% (lowest; top quartile above 1.9%)"; a separate developer-HQ view gives "IN/SEA median: at 1.4%".
- Trial-to-paid "IN/SEA median: 15.2% (lowest; top quartile above 25.0%)".
- Revenue per install D14 $0.08, D60 $0.11 ("reflects lower pricepoints").
- "IN/SEA prices at 46-54% of top-tier markets across all durations"; lowest monthly median on Play, $3.12.
- Median refund rate in IN/SEA 7.7% (highest).
- First-renewal rates in IN/SEA: 37% weekly, 46% monthly, 22% yearly.
- Google Play cancellations: 66.3% unsubscribes and 32.2% billing errors (App Store: 82.9% and 15.2%).
- Hard paywall vs freemium (not price-tier): download-to-paid 10.7% vs 2.1% (median, per the 2026 benchmarks blog, fetched).

### 1.2 RevenueCat State of Subscription Apps 2025 edition (data year 2024 per Airbridge)

Source: https://www.revenuecat.com/state-of-subscription-apps-2025 [OFFICIAL], fetched 2026-11-25. Tier thresholds not defined on the page text.
- Download-to-trial: "A median conversion rate of 9.8% for high-priced apps, compared to 4.3% for low-priced apps".
- Download-to-paid D35: "median of 2.7% compared to 1.5% for low-priced apps".
- Trial-to-paid (Aperture commentary on the page): "lower price points are actually showing stronger trial-to-paid conversion (47.8% versus 28.4% for high-priced)".
- 1-year retention, yearly: "low-priced plans retaining up to 53.7% of users and high-priced plans still maintaining 48.3%". Monthly: "22.5% retention for low-priced plans, 16.4% for mid-priced, and only 12.2% for high-priced". Weekly: "3-6%". "Low-priced subscriptions retain best over time, with third renewal rates exceeding 79%."
- Realized LTV per payer at 1 year: high-priced $55.21, low-priced $8.08 ("nearly 7x"); low-price P90 "just $22.43".
- "Low-priced plans have the lowest refund rate (2.2%)"; "Low-priced plans see the lowest reactivation rates".
- "While lower-priced apps attract more downloads, they convert a smaller share into trials."
- Price distribution, as cited by Airbridge (https://www.airbridge.io/en/blog/subscription-app-pricing-by-category-2026-benchmark, fetched, published 2026-05-13, updated 2026-11-05) [ESTIMATE citing RevenueCat]: monthly plans bottom 25% $3.26, median $6.68, most common $9.99, top 25% $11.99; annual bottom 25% $17.59, median $29.99. A $0.59 or $0.99 monthly price is below the bottom-quartile monthly price in this dataset.

Note: the two RevenueCat editions point the same way on download-to-paid (higher-priced apps convert more installs) but the 2025 edition shows low-priced apps with higher trial-to-paid and better retention. Both compare different apps, so they do not isolate the effect of price.

### 1.3 Adapty State of In-App Subscriptions 2026

Source: https://adapty.io/state-of-in-app-subscriptions-report/ [OFFICIAL], fetched 2026-11-25 (full bucket values are in interactive charts, not in page text).
- Tier definition (verbatim from page): four buckets: "Low: bottom 25% of prices; Lower mid: 25-50%; Upper mid: 50-75%; High: top 25%", bucketed within each category.
- "Monthly conversion drops ~53% as prices move from low to mid range." "For weekly plans, higher-priced apps convert into purchase better." Weekly plans convert 2-7x better than annual.
- Retention: "Higher-priced weekly tiers retain 12% better at first renewal"; entertainment monthly: low-priced apps retain 2x better than high-priced; European monthly: low-priced apps see 40% higher first-renewal rates.
- India pricing index 0.6, the lowest of 22 countries listed (baseline country = 1.0).
- Price tests: "Price experiments improve LTV in 46% of tests, but conversion in only 28%." (as cited by Airbridge, above; RocketShip HQ gives 45.5% and 28.3%: https://www.rocketshiphq.com/subscription-app-conversion-rate-price-increase/, fetched, dated 2026-03-29). Those tests do not isolate price cuts from price increases.
- Install-to-paid by price tier from Adapty: NOT FOUND.

### 1.4 Other aggregate sources
- Liftoff: "mid-price subscription apps converted at about five times the rate of low-cost ones"; very expensive apps averaged 0.73% (snippet only; https://www.mobileworldlive.com/news-apps/mid-price-subscription-apps-easiest-to-convert/ returned 403; date and definitions not verified) [ESTIMATE].
- Frisbii: median annualized churn highest for subscriptions priced 0-9.99 EUR (snippet only; https://frisbii.com/blog/report-subscription-pricing-churn-rate/ not fetched; B2C/B2B mix unknown) [ESTIMATE].
- Superwall aggregate price-tier report: NOT FOUND (only individual case studies, below).

### 1.5 Published price tests (cases; vendor-published cases may be selected for success)

| Case | Change | Result | Source, date, label |
|---|---|---|---|
| BuyBye (Superwall case study) | Yearly plan price +50% (dollar amounts not stated) | Conversions "dropped by 19%"; proceeds per user +25%; sample size not reported | https://superwall.com/case-studies/buybye , dated 2026-04-07 [OFFICIAL, vendor] |
| SellRaze (Superwall) | Annual $59.99 cut to $44.99 | ARPU +10%; conversion change not reported | https://superwall.com/case-studies/sellraze , dated 2025-12-19 [OFFICIAL, vendor] |
| PropGPT (Superwall) | Weekly $6.99 to $9.99 (+43%) | Proceeds per user +47.5%; "Conversion rate erosion at the higher price was minimal" (not quantified) | https://superwall.com/case-studies/propgpt , dated 2026-01-17 [OFFICIAL, vendor] |
| Planner 5D (Superwall) | Three price tiers A/B/C (prices not stated) | Highest tier +83% ARPU vs control; conversion not reported | https://superwall.com/case-studies/planner-5d , dated 2026-01-30 [OFFICIAL, vendor] |
| Mojo (RevenueCat blog) | Yearly price for new users +50% in USA, Germany and others | "minimal adverse effects on the free-to-paid conversion rate"; no figures | https://revenuecat.com/blog/growth/mojo-60-percent-arpu-growth-five-months/ , 2023-10-12 [OFFICIAL, vendor] |
| Stardust (Superwall) | Higher-priced variants, no trial | "lower conversion rate and similar proceeds per user" (search summary only, page not fetched) | https://superwall.com/blog/how-stardust-increased-ios-app-revenue-by-4x-in-six-weeks [OFFICIAL, vendor], snippet only |
| Travel app (Adapty case) | Price +30% | Conversion fell about 5% (search summary; part of a bundle of changes) | https://adapty.io/case-studies/travel-app/ , snippet only |
| Windows flight-sim utility (David Barnard) | $4 to $20 | Downloads stayed flat (recounted on a Sub Club summary page) | https://www.betterlaunch.co/playbooks/episodes/sebastian-rohl-habitkit , fetched; secondhand [PRESS/FOUNDER recounted] |
| One developer, 4 price tiers ($3.99, $9.99, $29.99, $99.99), 90 days | Cheapest tier produced least revenue, most expensive most | Search summary only; the Medium page returned 403 | https://medium.com/@andy.a.g/3-99-vs-9-99-9584d3960c84 [FOUNDER], snippet only; not verified |
| HabitKit (see 2.1) | Monthly $0.99 raised to $2 on iOS; Android price test "failed" | No numbers published | see 2.1 |

A published test where an app cut its price to about $1/month or less and reported conversion and revenue before/after: NOT FOUND. A published break-even model for price increases exists (RocketShip HQ, 2026-03-29, "there is no reliable universal conversion drop to plan around"; example: a 30% price rise breaks even if conversion falls less than 23.1%). It has no price-decrease data.

[DERIVED] Break-even arithmetic for a cut: revenue per converting user scales with price, so holding revenue per install equal when the price falls from P to P' requires conversion to rise by factor P/P'. $3.26 (bottom-quartile monthly) to $0.99 needs about 3.3x; $6.68 (median) to $0.99 needs about 6.7x; $0.99 to $0.59 needs 1.7x. This ignores retention, refunds and store fees.

---

## 2. Named consumer apps at about $1/month or less (or $12/year or less)

### 2.1 HabitKit (Android and iOS habit tracker, solo founder Sebastian Rohl)
- Current App Store listings (fetched 2026-11-25): US monthly tiers listed as $0.99, $1.99 and $4.99; yearly $5.99, $11.99, $24.99; lifetime $14.99, $29.99 (https://apps.apple.com/us/app/id6443918070?l=en-us) [OFFICIAL]. India listing: monthly Rs 89, Rs 199, Rs 499; yearly Rs 519, Rs 1,199, Rs 2,499; lifetime Rs 1,499, Rs 2,999 (https://apps.apple.com/in/app/id6443918070) [OFFICIAL]. The listing does not say which price a given user sees. The Google Play listing could not be fetched.
- Pricing history: "$0.99/month or $6/year" originally; the RevenueCat CEO advised "Just double it $2 a month that's still really low and nobody's gonna get mad"; a Google Play reviewer called the price too high even at $1/month (https://www.betterlaunch.co/playbooks/episodes/sebastian-rohl-habitkit , fetched, secondhand summary of a Sub Club podcast) [PRESS].
- "$2/month on iOS, $1/month on Android, or a $32 lifetime deal"; "the higher iOS pricing works well, while a price test on Android failed" (no detail on what was tested): https://happybootstrapping.com/p/30000-per-month-sebastian-ruhls-journey , published 2025-10-22 [PRESS/interview]. Also https://www.buildmvpfast.com/blog/602k-revenue-solo-indie-hacker-app-portfolio-breakdown-2026 [ESTIMATE; no primary source cited]. Starter Story page lists "$0.99/month, $6/year, or a lifetime license for $15" (older; https://www.starterstory.com/habit-kit-breakdown) [ESTIMATE].
- Disclosed results for 2025 from the founder's own year-in-review: total revenue $602,000, MRR $28,000, active subscribers 25,100; downloads App Store 272,000 and Google Play 290,000 (period not stated; the post says figures exclude Dec 31): https://sebastianroehl.substack.com/p/2025-the-year-that-changed-everything [FOUNDER], fetched. The post does not mention pricing, conversion or refunds. The same post says monthly revenue "stabilized above $40k" while stating MRR $28,000; the discrepancy is unexplained.
- [DERIVED] $28,000 MRR / 25,100 subscribers is about $1.12 per active subscriber per month (MRR may include annual and lifetime accounting; not stated). Download-to-subscriber conversion: NOT FOUND (downloads period unclear).
- The founder's 2024 review says: "I think I still haven't found the best pricing point" (https://sebastianroehl.substack.com/p/2024-my-indie-app-business-year-in) [FOUNDER].

### 2.2 WhatsApp ($0.99 per year, ended)
- Fee: 99 cents per year, first year free. Dropped 2016-01-18 (Jan Koum, DLD conference). Koum: "It really doesn't work that well," and "We just don't want people to think at some point their communication to the world will be cut off." https://fortune.com/2016/01/19/whatsapp-free (fetched) [PRESS]. TNW (fetched) adds that users "need a payment card on file, which might be tough for some people in developing markets" (author's framing, not a Koum quote): https://thenextweb.com/news/whatsapp-is-dropping-its-annual-99-cent-fee [PRESS]. Share of users who paid: NOT FOUND.

### 2.3 India and other low-price subscriptions with disclosed prices (no payer share disclosed)
- Telegram Premium India cut from Rs 469 to Rs 179 per month in October 2022 (reported reason: win share against WhatsApp): https://inc42.com/buzz/telegram-premium-subscription-price-62-indian-users , https://techcrunch.com/2022/10/01/telegram-premium-india-price-change/amp/ [PRESS] (snippets; current price not verified). Payer counts: NOT FOUND.
- Truecaller Premium reported "starts at Rs 79 ($0.95) per month or Rs 529 per year" in Feb 2024 (https://techcrunch.com/2024/02/25/truecaller-brings-call-recording-and-transcription-to-india , snippet) [PRESS]; App Store India listing today: Monthly Rs 99, Yearly Rs 899 (https://apps.apple.com/in/app/truecaller/id448142450 , fetched) [OFFICIAL]. Payer share: NOT FOUND.
- Bitwarden Premium: $10 per year, raised to $19.80 per year ($1.65/month billed annually) on 2026-01-21; existing Premium customers get a one-time 25% loyalty discount then renew at the standard rate. Stated reason: "To reflect expanded security capabilities and ongoing innovation... The price reflects enhanced value while remaining the most cost effective leading password manager for individuals." https://bitwarden.com/blog/bitwarden-launches-enhanced-premium-plan/ (fetched) [OFFICIAL]; the old $10 price comes from a forum user (https://community.bitwarden.com/t/bitwarden-launches-enhanced-premium-plan/93006 , "Was $10, is now $19.80 (increased by 98 %)") [ESTIMATE]. Effect on conversion: NOT FOUND.

### 2.4 Failures or reversals at very low prices
- WhatsApp (2.2) is the clearest named reversal of a sub-$1 fee. Reason stated by the founder: "doesn't work that well" in many countries.
- HabitKit raised from $0.99 to $2 (iOS) after advice that "nobody's gonna get mad" (2.1); no before/after numbers.
- Any other named consumer app that charged at or below $1/month and later changed price with a disclosed reason and numbers: NOT FOUND (searches for $0.99/month indie post-mortems returned only generic advice blogs). Apollo (Reddit client) was checked; sources give Ultra at about $1.49/month, no subscriber count, and the shutdown cause was Reddit API pricing, so it is excluded.

---

## 3. Voluntary payment: honour system, pay-what-you-want, donations, nagware

| Project | Mechanism | Disclosed payer share / amount | Source, date, label |
|---|---|---|---|
| FUTO Keyboard (Android) | One-time licence, no subscription. "The FUTO Keyboard costs $6.99 if purchased through FUTO Pay or $11.99 if purchased through the Google Play Store. Pay for it if you like it." No licence-key verification ("does not have a license key verification system due to being offline"; tap "I already paid"); payment notice appears 30 days after install | Number or share of payers: NOT FOUND | https://docs.keyboard.futo.tech/print , https://docs.keyboard.futo.tech/troubleshooting/faq (both fetched 2026-11-25) [OFFICIAL]; https://keyboard.futo.tech/ : "Purchase a FUTO Keyboard licence for a one-time payment... No recurring subscriptions" [OFFICIAL]. FUTO's licence text (per Hacker News quotes) forbids removing the payment functionality: https://news.ycombinator.com/item?id=40831489 [ESTIMATE, commenters quoting licence] |
| Thunderbird | Donations in-app and on web | Appeal page title: "Only 3% of users Support Thunderbird" (appeal campaign tag apr25; no method given). Mozilla 2024 annual report: donations "on track" for $10M+ in 2024 vs $9M in 2023 (snippet only). | https://updates.thunderbird.net/en-US/thunderbird/128.0/apr25/donate (fetched) [OFFICIAL]; https://www.mozilla.org/en-US/foundation/annualreport/2024/article/success-through-two-way-conversations-with-our-community/ (snippet) [OFFICIAL]; https://www.thunderbird.net/en-US/donate/ : "nearly 100% of Thunderbird's operating revenue comes from the generous gifts of Thunderbird users" [OFFICIAL] |
| Wikipedia / Wikimedia | Banner donation appeals | FY2024-25: 7.7M donors (down 2.4% from 7.9M), US$184.5M from over 18M donations, average donation US$10.15, recurring gifts 23% of revenue. Share of readers who donate: not stated in report. Old survey (Feb 2012): 3% of regular readers vs 26% of editors had donated | https://meta.wikimedia.org/wiki/Fundraising/2024-25_Report (fetched) [OFFICIAL]; https://nonprofitquarterly.org/wikimedias-study-reveals-big-tip-about-online-donors-2/ , 2012-02-10 [PRESS] |
| Signal | Donations, in-app, monthly donor badge | Signal infrastructure about $14M/yr, staff about $19M/yr, $50M/yr projected by 2025 (blog, 2023-11-16). Reported (Wired, Nov 2023): small donors cover 25% of operating costs, up from 18%; this figure was seen in a search snippet only (Wired page blocked) | https://signal.org/blog/signal-is-expensive/ (fetched) [OFFICIAL]; Wired "Running Signal Will Soon Cost $50 Million a Year" [PRESS], snippet only. Share of users who donate: NOT FOUND |
| Organic Maps | Donations (bank, crypto, Open Collective) | Open Collective page snippet shows 36 contributors; third-party aggregator showed 19 donors / $132 at an unstated date. Not established | https://opencollective.com/organicmaps , https://organicmaps.app/donate [OFFICIAL, snippet only] |
| NewPipe | Donations | NOT FOUND | |
| Humble Bundle | Pay-what-you-want with tiers | 2010 first bundle average $9.17 per buyer (snippet); 2011 platform averages Linux $10.40, Mac $7.56, Windows $5.36 (snippet); one 2026 bundle showed average $15.09 on 2026-09-22 (snippet from a third-party site). Humble does not publish a platform-wide average | https://techdirt.com/blog/entrepreneurs/articles/20100518/0844299463.shtml (403, snippet only) [PRESS]; https://levvvel.pages.dev/humble-bundle-statistics/ [ESTIMATE] |
| WinRAR | Unlimited "trial" nagware; licence $29 per user (excl. VAT) per search snippet | Share of users who pay: NOT FOUND. WinRAR posted on X on 2026-06-30: "Thanks to all of your recent payments, we've been able to develop a new version!" (WinRAR 7.23) | https://www.dexerto.com/entertainment/winrar-releases-new-update-and-says-its-thanks-to-people-finally-paying-3381350/ (fetched) [PRESS]; https://rarlab.com/buysharewarecd.php [OFFICIAL, snippet only] |
| Sublime Text | Unlimited evaluation, optional licence | NOT FOUND | |
| Alex Cabal ebook (Standard Ebooks founder), pay-what-you-want, first week | Suggested price $5 | "45% of buyers paid more than $0"; average paid by payers $8.65; lowest paid amount offered $4 (two sales); highest $50; "we actually made more money than we would have had we offered it at a fixed price" | https://alexcabal.com/the-results-from-our-pay-what-you-want-ebook-pricing-experiment-are-in , 2013-05-17 (fetched) [FOUNDER] |
| Radiohead In Rainbows album | Pay-what-you-want | About 38% of downloads paid, average near $6.00 (summary via academic paper aggregator) | https://www.academia.edu/17922691/_Pay_what_you_want_as_a_profitable_pricing_strategy_Theory_and_experimental_evidence [ESTIMATE], snippet only |
| Pay-what-you-want literature | Zero-payment shares of 19.3%-43.0% across studies; average payments usually below 10 and often below 1 | Vendor guide, citations not verifiable | https://www.creem.io/blog/pay-as-you-want-pricing-a-practical-guide-for-sellers [ESTIMATE] |
| Small open-source projects | Donations | A Damn Small Linux maintainer estimated "fewer than one percent" of users contribute (one project, not a survey). CMU study: 1,145 of 537,640 npm repositories (0.2%) ask for donations | https://damnsmalllinux.org/income-guide/donations.html ; https://www.cs.cmu.edu/~ckaestne/pdf/icse20-donations.pdf [ESTIMATE], snippets only |

In-app tip-jar results (share of users who tip; average tip) for any named indie app: NOT FOUND.

Google Play policy relevance (https://support.google.com/googleplay/android-developer/answer/9858738?hl=en , fetched): Play billing is required for digital goods and subscriptions "unless Section 3, 8, or 9 applies"; section 3 lists "peer-to-peer payments, online auctions, and tax exempt donations" as not requiring Play billing. The page does not mention tipping.

---

## 4. India

### 4.1 Monthly price points of named consumer subscriptions (INR)
Google Play India listings could not be fetched (Play pages return only navigation to the fetch tool). The figures below come from official company pricing pages and official Apple App Store India listings (iOS prices can differ from Android), all fetched 2026-11-25 unless stated.

| App / service | Monthly price (INR) | Source, label |
|---|---|---|
| Spotify Premium Standard | Rs 99 for 3 months, then Rs 139/month; Platinum Rs 299/month; Student Rs 69/month; prepaid Rs 1,390/year | https://www.spotify.com/in-en/premium/ [OFFICIAL]. Search results show other snapshots: Mini Rs 25 or Rs 29 per week, Rs 7 per day; Individual Rs 119 (conflict, time-limited offers): https://www.spotify.com/in-en/promo/mini-india/ [OFFICIAL, snippet] |
| Netflix | Mobile Rs 149, Basic Rs 199, Standard Rs 499, Premium Rs 649 | https://help.netflix.com/en/node/24926 [OFFICIAL] |
| Google One | Lite (30 GB) Rs 59; Basic (100 GB) Rs 130; Google AI Pro (5 TB) Rs 1,950 | https://one.google.com/about/plans?hl=en&gl=in [OFFICIAL] |
| ChatGPT Go | Rs 399/month, UPI accepted; launched 2025-08-18 | https://techcrunch.com/2025/08/18/openai-launches-a-sub-5-chatgpt-plan-in-india [PRESS]. Reported 12-month free promotion for Indian users (snippet only) |
| Google AI Plus | Rs 399/month, intro Rs 199 for 6 months; launched Dec 2025 | https://techcrunch.com/2025/12/10/google-launches-sub-5-ai-plus-plan-in-india-to-compete-with-chatgpt-go [PRESS, snippet] |
| Telegram Premium | Rs 179 (cut from Rs 469 in Oct 2022; may have changed) | https://inc42.com/buzz/telegram-premium-subscription-price-62-indian-users [PRESS] |
| Truecaller | Premium Monthly Rs 99, Yearly Rs 899; Family Monthly Rs 249 | https://apps.apple.com/in/app/truecaller/id448142450 [OFFICIAL, iOS] |
| Todoist Pro (productivity) | Monthly Rs 330; yearly Rs 3,149 | https://apps.apple.com/in/app/todoist-to-do-list-calendar/id572688855 [OFFICIAL, iOS] |
| Notion Plus (notes) | Monthly Rs 1,199; yearly Rs 11,900 | https://apps.apple.com/in/app/notion-notes-tasks-ai/id1232780281 [OFFICIAL, iOS] |
| Otter Pro (voice notes/transcription) | Monthly Rs 1,549 to Rs 1,799 (several listed); yearly Rs 9,900 | https://apps.apple.com/in/app/otter-transcribe-voice-notes/id1276437113 [OFFICIAL, iOS] |
| Duolingo Super | Entries from Rs 199 to Rs 1,749 (durations not labelled) | https://apps.apple.com/in/app/duolingo-language-lessons/id570060128 [OFFICIAL, iOS] |
| HabitKit Pro | Monthly Rs 89 / Rs 199 / Rs 499 | https://apps.apple.com/in/app/id6443918070 [OFFICIAL, iOS] |

Aggregate India prices: RevenueCat 2026 IN/SEA Play Store annual median $14.64; lowest monthly median $3.12 (see 1.1). Adapty index: India 0.6 of baseline (1.3). No named Indian consumer app listed at or below Rs 29/month on a monthly auto-renewing plan was found in this search, other than Spotify Mini prepaid short-term passes (Rs 7/day, Rs 25-29/week; snippets from spotify.com Mini pages).

### 4.2 Share of Indian app users who pay
- No source found for share of Indian app users who pay for subscriptions in general. NOT FOUND.
- Music only: EY-IMI report, 2026-07-24, survey of 15,373 smartphone users (March-April 2026): "approximately 14 million paid music subscriptions in 2025"; "only 38% said they had ever paid for a music streaming service, including where bundled"; "61% of respondents were willing to pay for streaming music if free alternatives disappeared": https://www.ey.com/en_in/newsroom/2026/07/india-s-paid-music-subscriptions-could-reach-28-30-million-by-2028-as-industry-focuses-on-monetization-and-premium-experiences (fetched) [OFFICIAL]. An Interspace blog derives about 8% of 178M streamers paying (14.4M/178M); other sources say about 6% or just above 10% (IFPI): https://interspacemusic.com/blog/india-added-4-million-paid-music-subscribers-2025-still-just-8-percent-of-178-million-streamers/ [ESTIMATE, snippet only].
- Market scale (Sensor Tower via TechCrunch, 2026-04-22): India downloads about 25 billion/yr; revenue per download about $0.03 vs more than $0.20 in Southeast Asia and Latin America; Q1 2026 in-app purchase revenue over $300M, up 33% year over year: https://techcrunch.com/2026/04/22/indias-app-market-is-booming-but-global-platforms-are-capturing-most-of-the-gains/ (fetched) [PRESS/ESTIMATE].

### 4.3 UPI Autopay and RBI e-mandate rules
- Google Play added UPI Autopay for subscriptions in India on 2022-11-15: "We're introducing UPI Autopay as a payment option for subscription-based purchases on Google Play in India." https://blog.google/intl/en-in/products/platforms/now-pay-for-subscriptions-via-upi-on-google-play/ (fetched) [OFFICIAL].
- RBI circular RBI/2022-23/73 dated 2022-06-16 raised the additional-factor-authentication limit for e-mandates "from Rs 5,000/- to Rs 15,000/- per transaction", effective immediately; covers cards, prepaid instruments and UPI: https://www.rbi.org.in/scripts/NotificationUser.aspx?Id=12341 (fetched) [OFFICIAL]. The 24-hour pre-debit notice is not on that page.
- RBI "Digital Payments - E-mandate Framework, 2026" (reported 2026-04-21): recurring debits up to Rs 15,000 without fresh authentication after a one-time e-mandate registration; "pre-debit notifications at least 24 hours before a transaction" with merchant name, amount and debit date; customers can opt out before processing; higher limits (Rs 1 lakh) for insurance, mutual funds, card bills: https://www.businesstoday.in/personal-finance/news/story/rbi-caps-recurring-payments-at-rs15000-without-otp-under-new-e-mandate-framework-526759-2026-04-21 (fetched) [PRESS]. I could not open the RBI document itself (bot check), so this is not verified against RBI. No minimum or small-amount exemption from the notification requirement was found.
- Google's own note: payment authorization may be placed up to 5 days before renewal for users in India (vs 48 hours elsewhere): https://developer.android.com/google/play/billing/price-changes (fetched) [OFFICIAL].
- Google Play 2021 India subscription rule: auto-renewing subscriptions capped below Rs 5,000: https://www.revenuecat.com/blog/engineering/indias-new-subscription-rules [OFFICIAL/vendor, fetched, 2021].
- UPI Autopay failure rate: Mint, reprinted 2025-10-11: "55-90% of automated payments across public and private banks on UPI AutoPay didn't go through during the month of August 2025" per NPCI data, attributed to insufficient balance and incorrect beneficiary details: https://www.magzter.com/en/stories/newspaper/Mint-Mumbai/UPI-AUTOPAYS-ENDLESS-WOES-FORCING-AN-INDUSTRY-RETHINK [PRESS], snippet only (page blocked); NPCI's own figure not found. Gateway-vendor blogs (Razorpay, Cashfree) put involuntary churn at 20-40% of churn and recovery by retries at 40-70%: https://www.cashfree.com/blog/saas-payment-failures-india/ [ESTIMATE, vendor].

### 4.4 GST and Google's fee in India
- Google as marketplace service provider handles GST: "Google as a marketplace service provider, is responsible for determining, charging, and remitting GST on your behalf." India is on Google's tax-inclusive pricing list: "all taxes (including VAT) must be included in the price." https://support.google.com/googleplay/android-developer/answer/138000 (fetched) [OFFICIAL]. How the 15% fee interacts with the GST-inclusive price (fee on gross or on net of tax): NOT FOUND. GST rate on app subscriptions: not verified.
- Service fee: "15% for automatically renewing subscription products" regardless of annual revenue (page covers markets outside Australia, EEA, Japan, UK and US for developers in the 15% tier; first $1M revenue per year 15%, above $1M 30% for non-subscription items). Developers offering alternative billing to users in India pay a fee "reduced by 4%": https://support.google.com/googleplay/android-developer/answer/112622?hl=en (fetched) [OFFICIAL]. The fee schedule applicable to US users was not read on this page.
- [DERIVED] A flat 15% of listed price would leave $0.50 of $0.59, $0.84 of $0.99, Rs 16.15 of Rs 19, Rs 24.65 of Rs 29, before any sales tax or GST treatment.

---

## 5. Google Play mechanics

### 5.1 Minimum price
- May 2022 (Google I/O): "We also expanded pricing options with ultra-low price points to help you increase conversions and grow your revenue. Now you can price your products as low as the equivalent of 5 US cents in any market." The post does not say whether this covers subscriptions. https://android-developers.googleblog.com/2022/05/whats-new-in-google-play.html , dated 2022-05-11 [OFFICIAL] (the exact first sentence was seen in a search summary; the "5 US cents" sentence was verified on the fetched page).
- March 2021: floors lowered in 20 more markets to "10-30 cents US equivalent"; India listed as a sub-dollar market for "paid apps, in-app products, and subscriptions": https://android-developers.googleblog.com/2021/03/sub-dollar-pricing-expansion-in-20.html , dated 2021-03-04 [OFFICIAL].
- 2015: India minimum lowered to Rs 10 for premium titles and in-app products (pilot): https://india.googleblog.com/2015/07/minimum-purchase-price-for-apps-on.html [OFFICIAL, snippet]; Nov 2015 post lists other countries but not India: https://android-developers.googleblog.com/2015/11/minimum-purchase-price-for-apps-and-in.html (fetched).
- Current exact minimum for US and India subscriptions and one-time products: NOT FOUND. The official table is at https://play.google.com/supported-locations and https://support.google.com/googleplay/android-developer/answer/10532353 but the table content was not returned to the fetch tool (checked several variants). Subscription help says only: "All prices are subject to Google Play minimum and maximum pricing in the region the price is available" (https://support.google.com/googleplay/android-developer/answer/12154973?hl=en , fetched). Maximum prices (not asked): US$10,000 limit per https://support.google.com/googleplay/android-developer/answer/16247119?hl=en (fetched; that page copyright 2026). US$0.59/0.99 and Rs 19/29 are above every floor figure stated above (5 US cents equivalent; 10-30 cents; Rs 10 in 2015), but the current table values are unconfirmed.

### 5.2 Price experiments
- Console price experiments are documented for one-time products only: "As this feature is based on one-time product pricing and sales, you must be a merchant developer to use it." Limits: app level; up to 1,000 purchase options; two variants plus a control; one experiment per country at a time; maximum six months; variant increases 1-999%, decreases 1-99%; confidence level 70-99% (default 90%); MDE 5-50% (default 30%). https://support.google.com/googleplay/android-developer/answer/13343030?hl=en (fetched) [OFFICIAL]. The May 2023 launch post says "price experiments for in-app products": https://android-developers.googleblog.com/2023/05/price-experiments-in-play-console.html , dated 2023-05-10 [OFFICIAL].
- Subscription price experiments in Play Console: NOT FOUND in any official page (search 2025-2026 found none). Third-party A/B tools (RevenueCat, Superwall, Adapty) exist for subscriptions but are outside Google's console.

### 5.3 Raising price for new subscribers while existing keep the old price
- Yes, by default. "When you change the price of a base plan or offer, the new price takes effect within a few hours for all new purchases." "When you change subscription prices, existing subscribers are unaffected by default; they are placed into a legacy price cohort where they continue to pay their original base plan price when they renew." https://developer.android.com/google/play/billing/price-changes (fetched 2026-11-25) [OFFICIAL]; same in https://support.google.com/googleplay/android-developer/answer/12154973?hl=en: "Users in a legacy price cohort continue paying their current price until they change subscription plans."
- Moving existing subscribers later: developer ends the legacy cohort (per region). Increases are opt-in by default: users must accept or the subscription is cancelled; advance notice 37 days, Play notifies from 30 days before; no Play notice during the first 7 days after migration starts. Opt-out increases (advance notice 30 or 60 days by country) exist only in some locations with limits on amount and frequency; "Each subscription base plan can only have a single opt-out price increase per country/region in the last 365 days." Price decreases are automatic at next renewal. Changes to offer pricing phases cannot be applied to existing subscribers.

---

## 6. Regional (purchasing-power) pricing results

- RevenueCat blog (Demian Voorhagen, 2025-08-29): "I've personally used a 70% cut in India and 60% in the Philippines with great results." No conversion or revenue figures. Same post cites a meditation app doubling Latin American subscriptions in 14 days, a wellness tracker with 38% conversion lift in Southeast Asia, and an unnamed app that cut prices 60% and gained 3x paying users. https://www.revenuecat.com/blog/growth/5-quick-fixes-for-bad-default-global-pricing-on-app-stores (fetched) [OFFICIAL, vendor/founder anecdote].
- Adapty 2026: localization tests had the highest LTV win rate, 62.3% (secondhand via search summary of Adapty and PricePush; not fetched from primary) [ESTIMATE].
- Roblox developer: 70% discount in India and Indonesia, total revenue +28% after adjusting ad rewards regionally (search summary only; https://rolearn.dev/guidance/regional-pricing-international-markets/) [ESTIMATE].
- Duolingo "400% increase in paid subscriptions from emerging markets" and Headspace Latin America "310% growth": appear only on a calculator vendor's blog with no sources (https://regionalpricecalculator.com/blog/google-play-pricing-strategy.html , 2026-01-12, fetched) [ESTIMATE, unverified]. Mirava vendor posts claim "Rs 749 to Rs 199" gave "800% increase in downloads" for an unnamed app, no data [ESTIMATE, unverified].
- Mojo (above): raising US/German yearly price 50% for new users, "minimal adverse effects" on conversion.
- Controlled before/after published data from a named developer lowering India prices (conversion, revenue, refunds, retention): NOT FOUND.
- RevenueCat cross-section: IN/SEA download-to-paid 0.7%, trial-to-paid 15.2%, RPI D60 $0.11, refund 7.7% (1.1), i.e. lower prices exist there alongside lowest conversion; direction of cause not established.

---

## 7. What I could not establish

1. Current exact Google Play minimum prices (US and India) for subscriptions and for one-time products; the official table did not load. Only the 2022 "5 US cents equivalent" statement, which does not say it applies to subscriptions.
2. Whether Play Console price experiments cover subscriptions (official docs describe one-time products only; no 2025-26 announcement found).
3. RevenueCat tier definitions in dollars (they are relative to other apps); RevenueCat 2026 mid-tier revenue per install; RevenueCat 2026 trial-to-paid by price tier. The full 2026 PDF (https://www.revenuecat.com/sosa-26-insights/) was not opened.
4. Adapty install-to-paid by price tier (charts not in page text); any Superwall aggregate report by price tier.
5. Any published test where an app cut price to about $1/month or less and reported before/after conversion and revenue. HabitKit's "Android price test failed" has no numbers.
6. Share of payers for FUTO Keyboard, NewPipe, Organic Maps, Sublime Text, WinRAR, Signal users; any tip-jar uptake rate for an indie app.
7. Wikimedia current share of readers who donate (report does not state it); Signal's 25% small-donor share is from a blocked Wired page (snippet only).
8. Share of Indian app users who pay for subscriptions (only music-streaming estimates of about 6-10% paying and 38% ever paid).
9. Google Play India live listing prices for the named apps (Play pages not fetchable); iOS India prices are shown instead.
10. RBI 2026 e-mandate framework text from RBI itself (only Business Today); NPCI's own UPI Autopay failure rates; whether any small-amount exemption exists from the 24-hour pre-debit notice.
11. How Google's 15% fee and GST interact on a GST-inclusive Indian price, and the GST rate applied to app subscriptions.
12. Unverified snippet-only items: Liftoff 5x claim, Frisbii churn claim, Stardust and Adapty travel-app cases, Humble Bundle historic averages, Mozilla donation total, Radiohead PWYW, Roblox case, ChatGPT Go free-for-12-months promotion.
