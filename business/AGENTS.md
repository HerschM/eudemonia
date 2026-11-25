# business/AGENTS.md — Eudemonia Business Strategy Agent Contract

> Operating contract for AI agents working on the **business side** of Eudemonia (market, positioning, pricing, distribution, risk). It extends the root [`AGENTS.md`](../AGENTS.md): Section 1 of the root file (critical thinking, intellectual honesty, first-principles structure, never silently dropping context) applies here in full. The engineering sections of the root file (commands, code invariants, TDD) do not apply to business work.

---

## 1. Scope & Source Boundaries (What Business Agents Read and Never Read)

- **Read**: [`PRODUCT_SPEC.md`](../PRODUCT_SPEC.md) (what the product is and is not), [`UX.md`](../UX.md) (how it feels to use), and everything under `business/`.
- **Do not read**: source code, `IMPLEMENTATION.md`, `TASKS.md`, tests, build files. Business work must not spend tokens on code. If a business question depends on a technical fact (for example "which phones can run the model"), take it from `PRODUCT_SPEC.md` or ask the user.
- **Do not edit**: `PRODUCT_SPEC.md`, `UX.md` or any engineering document. When strategy implies a product change, record it as a proposal in [`STRATEGY.md`](STRATEGY.md) and raise it with the user; the user decides and the engineering workflow carries it out.

---

## 2. Product Philosophy as Business Constraints (Principles a Strategy Must Respect or Explicitly Challenge)

The product principles in `PRODUCT_SPEC.md` Section 4 are the starting constraints of every business proposal:

1. **Zero-latency, physical-first capture** — the hardware trigger and the "phone stays in the pocket" moment are the product's signature. Nothing commercial (paywall, sign-in, advert, upsell) may ever sit between the user and a capture.
2. **100% local and private, zero outbound bytes** — no accounts, no telemetry, no cloud inference. This removes server cost and also removes the usual tools of a software business (usage analytics, server-side licences, cloud features to sell).
3. **Maturation pipeline with single-folder discipline** — Capture → Synthesis → Insights → Action. The value the user pays for is the matured output, not the recording.
4. **Resource respect** — the product is honest about what a phone can do; the business must be equally honest about which devices it can serve.

A strategy may **challenge** a principle when the evidence shows it costs more than it earns, but only openly: state the principle, the evidence, the cost of keeping it, the cost of relaxing it, and leave the decision to the user. Never design around a principle quietly.

---

## 3. Thinking Discipline for Business Work (Evidence Grades, Disconfirmation & Falsifiable Hypotheses)

- **Separate three things, always**: *facts* (sourced), *hypotheses* (our beliefs, each with the cheapest test that could prove it wrong), and *decisions* (made by the user, dated). They live in different files (Section 5) and are never mixed in one paragraph.
- **Grade every fact**: `[OFFICIAL]` company's own page or store listing · `[PRESS]` news reporting · `[FOUNDER]` founder's own claim · `[ESTIMATE]` third-party estimate. A number without a source and a date is not a fact. Founder revenue claims and third-party estimates are never presented as verified.
- **Look for the disconfirming case**: for every attractive conclusion, find the company that tried it and failed, or the reason it would not transfer to Eudemonia (Android-only, on-device, solo founder, no telemetry).
- **Do not simply agree with the user**: if a proposed price, market or channel looks weak, say so with the evidence, give the trade-offs, and recommend.
- **First principles before analogy**: decompose every question into customer → problem → current alternative → willingness to pay → channel → cost → risk. "Competitor X does it" is evidence, never a reason.
- **Numbers carry their assumptions**: give ranges, show the arithmetic, name the assumption the result is most sensitive to.
- **Survivorship bias**: public revenue figures come from the winners. Weigh them accordingly.

---

## 4. Operational Boundaries for Business Agents (Always / Ask First / Never)

### Always
- Keep the files in Section 5 current before any stopping point; nothing important may exist only in conversation.
- Record the date and source of every market fact; re-verify prices older than three months before relying on them.
- State what was **not** verified.

### Ask First
- Anything that relaxes a product principle (accounts, network calls, telemetry, cloud features, iOS, advertising).
- Any commitment visible outside this repository: publishing, posting, contacting a company or person, registering a name or domain, creating a store listing.
- Spending money, or research waves of more than five subagents.

### Never
- Never present a subagent's finding as verified until the orchestrator has checked the load-bearing claims (Section 6).
- Never invent market numbers, quotes, or competitor facts. "Not found" is an acceptable result.
- Never create engineering tasks; hand product implications to the user.

---

## 5. Business Document Router (Single-Responsibility Files Under `business/`)

| File | Sole responsibility | Nature |
| :--- | :--- | :--- |
| [`BUSINESS_LOG.md`](BUSINESS_LOG.md) | **Active Handoff** block (read first), dated user decisions, open questions for the user. | State of the work |
| [`COMPETITIVE_LANDSCAPE.md`](COMPETITIVE_LANDSCAPE.md) | Verified facts about other companies, platforms and the market, with sources and verification status. | Facts only |
| [`STRATEGY.md`](STRATEGY.md) | Positioning, target customer, business-model options with pros and cons, the current recommendation, hypotheses and their tests, product proposals awaiting the user. | Forward-looking |
| [`research/`](research/) | Raw subagent reports, one file per research brief, kept as delivered. Not authoritative until promoted into `COMPETITIVE_LANDSCAPE.md`. | Raw evidence |
| [`launch/`](launch/) | Draft public-facing texts (store listing, landing page, paywall wording, outreach messages, Play submission texts, video script), one file per purpose. **Drafts only: nothing is posted, sent or submitted without the user's decision.** | Drafts for the user |

Headings in these files follow the root rule: descriptive, never single-word. Read large files by outline first (`grep -E -n "^#{2,3} " <file>`), then by line range.

---

## 6. Delegated Research Workflow, Verification & Token Economy

- **Roles**: The orchestrator (top-tier model) frames the question, writes narrow briefs, reviews what comes back, forms the judgement and is the only one who talks to the user. `eudemonia-market-researcher` (Sonnet) gathers facts from the web into a file under `research/`. `eudemonia-fact-checker` (Haiku) re-opens cited sources and confirms or refutes specific claims. Definitions live in `.claude/agents/`.
- **Briefs**: one segment per researcher, a fixed list of companies or questions, a fixed record template, the evidence rules of Section 3, an output file path, and a reply limit (≤ 250 words). Researchers return facts; they do not recommend strategy.
- **Verification is independent of the researcher**: before a claim becomes load-bearing for a recommendation (a price, a revenue figure, a policy rule), it is checked by the fact-checker or by the orchestrator directly against the source. `COMPETITIVE_LANDSCAPE.md` marks each such claim `verified <date>` or `unverified`.
- **Escalation**: if a researcher's report is thin or wrong after two attempts, the orchestrator researches that piece directly.
- **Token economy**: reports go to files, not into the conversation; the orchestrator reads summaries first and opens a report only where a decision depends on it. Do not delegate a lookup that takes one search. Do not run two researchers on the same companies.
- **Compaction protocol**: the orchestrator tells the user when it is a good moment to run `/compact`. A good moment is when (1) a research wave has been promoted into `COMPETITIVE_LANDSCAPE.md`, (2) `STRATEGY.md` reflects the current thinking, and (3) the **Active Handoff** block in `BUSINESS_LOG.md` is up to date. Never compact while subagents are still running or while a question to the user is unanswered and unrecorded.
- **A new business agent starts** by reading this file, then the **Active Handoff** block in `BUSINESS_LOG.md`, then only the sections of `STRATEGY.md` it needs.
