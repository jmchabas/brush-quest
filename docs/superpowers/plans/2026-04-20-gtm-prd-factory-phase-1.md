# GTM PRD Factory — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase 1 MVP of the GTM PRD Factory — a project-local Claude Code slash command at `.claude/commands/gtm-factory.md` that runs one complete loop (5 lens research → Synth-1 → 3 evaluators → Synth-2 → termination gate → PRDs) for a given question, validated end-to-end by running the Instagram Reels validation pass.

**Architecture:** Prose-driven slash command (follows the `/cyclepro` pattern: plain markdown at `.claude/commands/*.md`, no frontmatter, parses `$ARGUMENTS` for subcommands, orchestrates Agent-tool dispatches via prose instructions). Template library at `docs/gtm-v4/01-templates/`. Per-loop artifacts at `docs/gtm-v4/<node-path>/`. Context cascade by concatenating ancestor `_synth-final.md` files before dispatching any loop.

**Tech Stack:** Markdown + YAML front-matter, Bash helpers for file operations, Claude Code `Agent` tool for parallel agent dispatch, git for version control. No new dependencies.

**Spec reference:** [`docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`](../specs/2026-04-20-gtm-prd-factory-design.md)

**Explicitly out of scope for Phase 1 (deferred to follow-on plans):**
- Loop A (weekly pulse agent) — follow-on plan after Phase 1 validates
- Loop B (portfolio re-rank triggers) — follow-on
- Loop C (template meta-eval) — follow-on, only useful after ≥5 loops exist
- Experiments **execution** (experiment template lands now so PRDs can reference it, but no experiment-executor agent in Phase 1)
- Railway trigger registration (only needed once pulse exists)
- Dashboard at `brushquest.app/GTM-dashboard`
- Generic-layer extraction for other apps
- Full trunk loop (question B). Phase 1 ships with the validation loop only; trunk loop runs after Phase 1 ships, as the first real use of the machine.

---

## Phase 1 deliverable: Instagram Reels validation loop completes end-to-end

Success criterion for the whole plan:
- `/gtm-factory new-loop trunk/marketing/ugc/instagram-reels "Produce a complete set of agent-executable PRDs to get 50 qualified parent installs to Play Store internal testing in 14 days via organic Instagram Reels"` runs to completion.
- Output tree contains 5 distinct lens outputs, 1 Synth-1, 3 distinct evaluator outputs, 1 Synth-2, at least 1 PRD that passes the termination-gate §4 criteria, and a `_status.yaml`.
- At least one PRD is readable by a stub `instagram-executor-agent` that can identify the goal, inputs, acceptance criteria without asking for clarification.

---

## File structure (locked before tasks)

### Files created by this plan

```
docs/gtm-v4/
  00-master-brief.md                     # current-state brief (hand-written first time)
  02-decisions-log.md                    # v3 reconciliation
  README.md                              # directory map
  01-templates/
    lens-digital-native.md
    lens-bold-contrarian.md
    lens-frugal-scrappy.md
    lens-pattern-matching.md
    lens-first-principles.md
    evaluator-cfo.md
    evaluator-target-parent.md
    evaluator-solo-founder-agent.md
    synth-1-prompt.md
    synth-2-prompt.md
    prd-template.md
    experiment-template.md
  trunk/
    marketing/
      ugc/
        instagram-reels/
          <loop artifacts written at execution time — Task D2>

.claude/commands/gtm-factory.md           # the skill itself

.claude/agents/
  instagram-executor-agent.md             # stub executor — proves PRD-consumability
```

### Files modified by this plan

```
docs/gtm-v4/... (plan creates everything above fresh)
~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md  # index update
```

Each file has a single responsibility:
- Each **lens template** defines one research lens's voice, scope, and output format.
- Each **evaluator template** defines one persona's critique voice and output format.
- **Synth templates** define the merge logic for the two synthesis phases.
- **PRD + experiment templates** define the terminal output shapes.
- **`gtm-factory.md`** is the orchestrator — reads templates, dispatches agents in the right order, collects outputs, writes files.
- **`instagram-executor-agent.md`** is a stub that proves the PRD is consumable.

---

## Sub-phase A — Scaffolding

Goal of sub-phase A: directory tree exists, master brief captures current state, decisions-log reconciles with v3. Nothing about agents yet.

### Task A1: Create `docs/gtm-v4/` directory structure + README

**Files:**
- Create: `docs/gtm-v4/README.md`
- Create: `docs/gtm-v4/01-templates/.gitkeep`
- Create: `docs/gtm-v4/trunk/.gitkeep`

- [ ] **Step 1: Create directories**

```bash
mkdir -p docs/gtm-v4/01-templates
mkdir -p docs/gtm-v4/trunk
touch docs/gtm-v4/01-templates/.gitkeep
touch docs/gtm-v4/trunk/.gitkeep
```

- [ ] **Step 2: Write `docs/gtm-v4/README.md`**

```markdown
# GTM v4 — PRD Factory

The live tree of GTM loops, plans, and executable PRDs for Brush Quest.
See spec: `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`.

## Layout

- `00-master-brief.md` — current product + business state, refreshed before each loop.
- `01-templates/` — lens prompts, evaluator prompts, synth prompts, PRD template, experiment template.
- `02-decisions-log.md` — running log of decisions that span nodes; reconciles with v3.
- `<node-path>/` — one folder per tree node (trunk → branches → sub-branches → leaves).
  Each node contains its loop artifacts (`_research/`, `_evals/`, `_synth-v1.md`,
  `_synth-final.md`, `_status.yaml`, optional `prds/`, optional `_meta-prd.md`).

## Running a loop

`/gtm-factory new-loop <node-path> "<question>"`

The skill reads ancestor `_synth-final.md` files, dispatches 5 lens agents in parallel,
runs Synth-1, dispatches 3 evaluators in parallel, runs Synth-2, checks the termination
gate, and emits either PRDs (at leaves) or `_meta-prd.md` child charters (at branches).

## Supersedes

`docs/gtm-engine/GTM_ENGINE_v3.md` (narrative) — v3 stays on disk as historical context.
v4 reshapes output from one narrative doc to a tree of executable PRDs.
```

- [ ] **Step 3: Self-check**

Verify the three files exist: `ls docs/gtm-v4/` should show `01-templates/`, `trunk/`, `README.md`.

- [ ] **Step 4: Commit**

```bash
git add docs/gtm-v4/
git commit -m "feat(gtm-v4): scaffold directory structure + README"
```

---

### Task A2: Draft `docs/gtm-v4/00-master-brief.md` (current-state brief)

**Files:**
- Create: `docs/gtm-v4/00-master-brief.md`

This is the brief every lens agent, evaluator, and synth agent gets as input. It must be complete, current, and free of aspirational language.

- [ ] **Step 1: Gather current-state facts**

Pull facts from:
- `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md`
- `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/decision_product_strategy_2026_03.md`
- `CLAUDE.md`
- Recent `git log --oneline -20`
- `pubspec.yaml` for current version

- [ ] **Step 2: Write `docs/gtm-v4/00-master-brief.md`**

```markdown
# Master Brief — Brush Quest as of 2026-04-20

> Refreshed automatically before each new loop. Every agent (lens, evaluator, synth)
> receives this as context along with any ancestor `_synth-final.md` files.

## Product

- **What it is:** Kids' toothbrushing app. Theme: Space Rangers vs Cavity Monsters.
  Gamified 2-minute timer (4 configurable quadrants), defeat monsters, earn stars,
  unlock heroes + weapons + worlds.
- **Target user:** Kids aged 4–8 (primary: 7yo boys). Primary testers: Oliver (7) and
  Theo (3).
- **Platforms:** Android (Flutter) — LIVE on Google Play internal testing as of
  2026-04-11. iOS — scaffolded + SignInWithApple wired, Apple Business org in review
  since 2026-04-17 (expected ~2026-04-24). iOS TestFlight target: ~2–4 weeks out.
- **Current build:** v1.0.0+17. 774 tests. `dart analyze` clean.
- **Key product decisions locked:**
  - Voice: Buddy (George) only for v1 launch — others in backup.
  - Economy prices: locked until multi-profile ships.
  - Monetization: Free tier (4 worlds / 3 heroes / 3 weapons) + Brush Quest+ $9.99
    one-time for full content. Star packs $0.99 / $2.99 / $4.99 in parent settings.
    NO ads ever. NO subscription. No in-app purchase prompts shown to children.
  - Content approach: curated and user-generated both acceptable.

## Business

- **LLC:** AnemosGP LLC (formed, EIN 41-5007192, D-U-N-S 144980774).
- **Google Play:** Org account VERIFIED (jim@anemosgp.com).
- **Apple Developer (Business):** In review. Expect 2026-04-24.
- **Amazon Appstore:** Identity verification pending (case 19804300171).
- **Bank:** Mercury.
- **Budget for launch GTM:** $1,000–$2,000 total.
- **Founder:** Jim Chabas. Solo, not full-time (has another job). Willing to hire,
  but for now: agentic execution wherever possible.
- **Face of the brand:** Not Jim. If revenue covers it, hire a face later.

## Constraints

- **COPPA-strict.** No child personally identifiable data in marketing. No child name
  or face in shareable artifacts (hero character serves as proxy).
- **No ads inside the app.** Marketing may run ads targeting parents.
- **Brand tone:** warm, practical, slightly irreverent to the "brushing is miserable"
  parent experience. Never patronizing. Never "screen time is bad."

## Distribution surfaces (status as of 2026-04-20)

- Google Play — internal testing LIVE, submitted for public review 2026-04-11
- iOS App Store — scaffolded, awaiting Apple Business + TestFlight
- Amazon Appstore — pending identity verification
- Direct APK — possible, not prioritized
- Landing page — live at brushquest.app (active, QR code present, email capture live)

## Prior GTM work

- `docs/gtm-engine/GTM_ENGINE_v3.md` + `rounds/` — 10,304 lines from 2026-04-03. Pre-
  launch synthesis. Treat as one reference input, not a binding plan. Some assumptions
  (pre-launch) are now stale.
- Weekly GTM-prep Railway trigger runs Wednesdays 8:43am PT (opens PR with marketing
  drafts). To be reconciled with this factory later.

## Metrics already tracked

- Total brushes, best streak (per user)
- Daily active brushes
- Stars earned, Ranger Rank, wallet balance
- Brush history timestamps
- Firebase Auth events (sign-in rate)
- Firestore sync events (user count with cloud sync)
- Play Console: installs, uninstalls, rating

## Metrics not yet tracked (gaps to name in PRDs that need them)

- Marketing attribution (UTM + Play referrer match)
- Retention cohorts (D1/D7/D30 WAK) — data exists, no dashboard
- Per-channel install attribution
- Parent touchpoints (email capture source, QR scan source)

## What's live in parallel to any GTM work

- Play Store public review (2026-04-11 submitted; 1–7 day window)
- iOS TestFlight prep (Apple Business approval pending)
- Oliver v17 retest feedback loop (informal, ad-hoc)
```

- [ ] **Step 3: Self-check**

Read the brief end-to-end. Every claim must be verifiable from memory files, code, or the current git state. No aspirational or speculative statements. No "soon" or "coming" without a date.

- [ ] **Step 4: Commit**

```bash
git add docs/gtm-v4/00-master-brief.md
git commit -m "feat(gtm-v4): master brief with current Brush Quest state (2026-04-20)"
```

---

### Task A3: Draft `docs/gtm-v4/02-decisions-log.md` (v3 reconciliation)

**Files:**
- Create: `docs/gtm-v4/02-decisions-log.md`

- [ ] **Step 1: Read v3 engine doc's summary/conclusion**

```bash
head -100 docs/gtm-engine/GTM_ENGINE_v3.md
```

- [ ] **Step 2: Write the decisions log**

```markdown
# GTM Decisions Log

Cross-node decisions that span multiple branches. This is a running log — append,
don't rewrite. Decisions here bind child loops.

## 2026-04-20 — Supersede v3 output shape, reuse v3 inputs

**Decision:** v4 (this factory) supersedes v3's output shape. v3's narrative doc
(`docs/gtm-engine/GTM_ENGINE_v3.md`) remains on disk as a source for Lens L4
(pattern-matching) — "what did we previously conclude and does current state
invalidate any of it?"

**Why:** v3 produced ~10K lines of unused narrative. Output shape change (tree of
executable PRDs) addresses execution bottleneck. v3 research still has value.

## Carried forward from v3 (still binding)

- Budget: $1,000–$2,000 for launch GTM.
- Content approach: both curated and user-generated acceptable.
- Founder constraint: not full-time; agentic wherever possible.
- Face of brand: not Jim (hire if revenue allows).
- Legal posture: COPPA-strict, pursue compliance without shortcuts.
- No ads inside app. No purchase prompts to children.

## Superseded / re-opened vs v3

- v3 assumed pre-launch; we are now live on Play internal testing. All "launch
  day" framings in v3 are re-interpreted as "public-release day" (pending Play
  review).
- v3's free-launch target (2026-04-11) has passed; timeline anchor is now
  2026-07-20 (90 days).
- iOS was out-of-scope in v3; v4 plans for iOS launch inside the 90-day window.

## Decisions from this plan (Phase 1)

- Skill lives at `.claude/commands/gtm-factory.md` (repo-local, matches /cyclepro).
- Loop artifacts tree-structured at `docs/gtm-v4/<node-path>/`.
- Phase 1 ships with validation loop only (trunk loop runs next, as first real use).
- Feedback loops (A/B/C), experiments execution, dashboard are follow-on plans.
```

- [ ] **Step 3: Commit**

```bash
git add docs/gtm-v4/02-decisions-log.md
git commit -m "feat(gtm-v4): decisions log + v3 reconciliation"
```

---

## Sub-phase B — Template library

Goal of sub-phase B: every prompt and template the skill needs to dispatch loops. Each file is a self-contained prompt that an agent reads as its primary instruction plus the context brief.

Template acceptance criteria (applied to every B task):
1. Has a clear "voice" (the lens or persona is unmistakable from the output).
2. Covers the FULL question (lens agents do NOT champion a single route; they scan all).
3. Specifies output structure explicitly (headings, length bands, format).
4. Zero placeholders. Zero "fill in later." Zero ambiguous requirements.
5. References `00-master-brief.md` and ancestor `_synth-final.md` files as required inputs.

### Task B1: Lens template — digital-native (L1)

**Files:**
- Create: `docs/gtm-v4/01-templates/lens-digital-native.md`

- [ ] **Step 1: Write the template**

```markdown
# Lens L1 — Digital-Native

## Your role
You are a modern D2C / SaaS / dev-tool founder who has shipped 3+ products to
>10K users using the playbooks that dominate the last 5 years of internet-
native growth: Product Hunt launches, Reddit AMAs, Twitter/X narrative threads,
Substack + newsletter growth, SEO content flywheels, dev-first freemium, micro-
SaaS pricing psychology, community-led growth, Discord/Slack communities,
creator partnerships at scale via Fourthwall/Passes/Beehiiv, platform-native
distribution (Linktree, Beacons, Arc, Notion embeds).

## Your lens
How would I think about this question if Brush Quest were a SaaS or D2C brand
and I had to grow it using the playbooks I know cold? What feels obvious inside
that world? Which plays transfer to a kids' app with a parent buyer? Which
don't — and why?

## Your scope
Cover the FULL question. Do NOT champion one route. Evaluate every plausible
route through your lens. At the end, express preference with confidence bands,
not a single winner.

## Inputs you receive
- `docs/gtm-v4/00-master-brief.md` (current state)
- All ancestor `_synth-final.md` files (frozen parent decisions)
- The specific question for this loop

## Output structure (write ~500–900 words)

### 1. Framing from the digital-native playbook
2–3 sentences positioning the question in SaaS/D2C terms. What's the analogue?

### 2. Route coverage
For EACH route type that could apply (paid UA, UGC/creators, earned media,
partnerships, PLG/referral, community, ASO, email/newsletter), write 2–4
sentences on:
- What a modern D2C/SaaS founder would default to here
- What transfers to kids-app with parent buyer
- What does not transfer and why

### 3. Three underused plays
What 3 things would this audience NOT expect from a kids app, that a SaaS
founder would ship without hesitation? Examples: open metrics page, changelog-
as-marketing, public roadmap, dev-first brand voice, usage-based "price"
signal, Notion-style product pages.

### 4. Your ranked takeaway
Rank the routes you covered from most-promising to least-promising for THIS
product at THIS stage. Bands (high/medium/low confidence). Include your ONE
non-obvious bet — something a conservative founder would not ship.

### 5. Quick failure modes
3 bullet points on how this lens itself can mislead (e.g., "SaaS playbooks
assume self-serve; kids apps have parent gatekeepers").

## Style
- Direct. No fluff. No "in today's digital landscape."
- First-person singular acceptable.
- Cite specific companies / products by name when drawing analogies.
- If you don't know, say so — do not bluff.
```

- [ ] **Step 2: Self-check**

Read the file. Confirm:
- The "voice" is distinct (SaaS founder, not generic).
- Output structure is explicit.
- No placeholders.
- Instructs cover-full-question, not champion one route.

- [ ] **Step 3: Commit**

```bash
git add docs/gtm-v4/01-templates/lens-digital-native.md
git commit -m "feat(gtm-v4): lens L1 — digital-native template"
```

---

### Task B2: Lens template — bold-contrarian (L2)

**Files:**
- Create: `docs/gtm-v4/01-templates/lens-bold-contrarian.md`

- [ ] **Step 1: Write the template**

```markdown
# Lens L2 — Bold / Contrarian

## Your role
You are a former unit-economics skeptic turned ambitious bet-taker. You have
seen founders die of caution — settling for $20 CAC on a $9.99 LTV product —
and you have seen founders win by making one audacious bet that reshaped the
distribution curve. You believe the biggest risk at early stage is shipping
the safe plan everyone else is shipping.

## Your lens
What's the 10× play on this question? What's the bet nobody sane is making?
If I had 100× the budget, what would I do — and which cheap proxy tests that
thesis right now? Where is the expected-value math hiding a wildly asymmetric
payoff?

## Your scope
Cover the FULL question. Do NOT champion one single bold bet; name 2–3 bold
plays and the conservative counter-bets they'd beat. Every bold play must name
its cheap-proxy test.

## Inputs you receive
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files
- The specific question

## Output structure (write ~500–800 words)

### 1. The default plan (what everyone would do)
2–3 sentences describing the safe, median GTM play for this question. Name the
unremarkable 3-channel mix a median founder would ship.

### 2. The asymmetric bet candidates (2–3)
For each:
- **The bet:** one sentence.
- **Why it's 10× potential:** mechanism of asymmetric upside.
- **Why it's contrarian:** what conventional wisdom would reject it.
- **Cheap proxy test:** one experiment, <$200 or <1 week, that signals before
  we commit. If you cannot design the proxy, the bet is unripe.

### 3. The uncomfortable truth
One paragraph: what part of the safe plan is actually a slow death? What trap
should we refuse to walk into even though it looks rational?

### 4. Your ranked takeaway
Order the asymmetric bets by expected value (probability × upside). Include
the conservative counter-bet each one beats.

### 5. Quick failure modes
3 bullets on how bold thinking misleads (e.g., "confusing 'contrarian' with
'stupid'; some consensus is consensus because it's right").

## Style
- Direct and confident.
- Name numbers when you make claims (approximate is fine; "likely 5–10×" beats
  "significantly better").
- If the brief hints that a bold play would require violating a locked product
  decision (COPPA, monetization model, no ads), do not propose that play —
  find a bold play inside the rules.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/lens-bold-contrarian.md
git commit -m "feat(gtm-v4): lens L2 — bold-contrarian template"
```

---

### Task B3: Lens template — frugal-scrappy (L3)

**Files:**
- Create: `docs/gtm-v4/01-templates/lens-frugal-scrappy.md`

- [ ] **Step 1: Write the template**

```markdown
# Lens L3 — Frugal / Scrappy

## Your role
You are a solo founder with $500 and 10 hours this week. You have shipped 4
products that grew from zero on effectively no budget. Your superpower is
finding distribution surfaces that are free, un-crowded, and actually viewed
by your target user. You think paid acquisition is often a trap at <10K users
because you don't have the creative testing budget to find a winning ad yet.

## Your lens
What works this week with $0–$500 and one founder plus agentic executors,
no team? Where are the free distribution surfaces where the right parents
already are? Where can we pay in hustle instead of money?

## Your scope
Cover the FULL question. For every route the other lenses might love, ask:
what's the $0 or $100 version of this? Can a single agent run it?

## Inputs you receive
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files
- The specific question

## Output structure (write ~500–800 words)

### 1. Free distribution surfaces
List every free surface where parents of 4–8yo kids actually spend attention.
For each: surface, rough audience size, approximate effort to reach (hours/week),
what "winning" there looks like. Examples: specific subreddits, FB mom groups,
school parent email chains, pediatric-dentist waiting rooms, PTA newsletters,
kid-tech Substacks, Product Hunt kids/family categories, app review sites.

### 2. Agent-runnable zero-cost plays
For the 3 most promising free surfaces, sketch a play that a single Claude-
Code executor-agent could run (or run most of) given the right MCPs. Name:
- The action the agent takes
- The MCP / tool needed (if we have it — flag if we don't)
- The human-in-loop moment (often: approval of first post)
- The minimum viable first week

### 3. Money traps to avoid at this stage
3 bullets: places to NOT spend the $500–$2000 until we have X data.
(e.g., "Don't buy Google App Install ads until the app has 500+ ratings; CPI
 will be >$8 without social proof.")

### 4. Your ranked takeaway
Order the free + scrappy plays by expected volume per hour invested. Bands
(high/medium/low confidence). Include the ONE move you'd ship this week if
you had to pick.

### 5. Quick failure modes
3 bullets on how frugal-scrappy misleads (e.g., "grinding free channels past
their capacity; some channels cap at 500 installs and no amount of hustle
changes that").

## Style
- Sharp, specific. Name actual subreddits, actual FB groups, actual blogs.
- Cite approximate reach numbers. Estimates are fine.
- When hunching or guessing, mark with "(hunch)".
- Do not invent channels that don't exist.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/lens-frugal-scrappy.md
git commit -m "feat(gtm-v4): lens L3 — frugal-scrappy template"
```

---

### Task B4: Lens template — pattern-matching (L4, web-research)

**Files:**
- Create: `docs/gtm-v4/01-templates/lens-pattern-matching.md`

- [ ] **Step 1: Write the template**

```markdown
# Lens L4 — Pattern Matching (with web research)

## Your role
You are an analyst who has studied what actually worked for ~20 kids / family
apps in 2022–2026. You do not theorize from first principles; you look at
what worked (or didn't) for comparable products, with receipts. You are
explicitly empowered to use WebSearch and WebFetch to ground claims in recent
public information.

## Your lens
What have comparable apps actually done? For each of: Lingokids, Khan Academy
Kids, Yoto, Dr. Panda / TutoTOONS, BabyBus, Moshi (sleep/kids), Gro-Play,
Hopster, Wonder, and 3 more you discover — what was their GTM playbook at a
comparable stage? What worked? What publicly failed? What's most analogous to
Brush Quest's shape (short-session habit, parent-bought, ~$10 premium)?

## Your scope
Cover the FULL question via comparable-app evidence, NOT theory. If you make
a claim, cite the source (URL, publication, date). If the evidence is weak,
say so. This lens is the reality check for all others.

## Inputs you receive
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files
- The specific question
- WebSearch + WebFetch tools

## Output structure (write ~700–1,200 words)

### 1. Three most analogous apps (justify each)
For each: why analogous (product shape, age range, price model, buyer flow).
Brief (1–2 sentences) description for reader orientation.

### 2. What actually worked (by channel)
For each major channel type (UGC, paid UA, partnerships, PR, ASO, referral),
cite 2–3 specific examples from comparable apps with source links or known
facts. Note the channel's role (lead, support, dead end) and visible results.

### 3. What publicly failed
Documented failures and their causes. Parent-backlash moments, App-Store
removals, COPPA actions, bad PR arcs from comparable products.

### 4. Pattern transfer to Brush Quest
Which patterns transfer cleanly? Which need translation? Which don't transfer
(why)?

### 5. Open questions web research can't answer
What would we need private data on? (e.g., unit economics of specific apps.)
Flag these so the synth phase knows the gap.

### 6. Your ranked takeaway
Order the channels by empirical track record for this app shape. Confidence
bands. Cite your strongest evidence.

### 7. Quick failure modes
3 bullets on how pattern matching misleads (e.g., "survivorship bias in
what's visible; we see the winners' channel but not the grind before the win").

## Style
- Evidence-first. Numbers where you can get them.
- Cite sources with URLs + dates wherever possible.
- "I couldn't find specific data on X" is acceptable and often necessary.
- Don't bluff. Don't paraphrase unsourced claims as facts.

## Tool use
Use WebSearch / WebFetch liberally. Expect to read 5–15 web pages per loop.
Prefer company blog posts, founder interviews on podcasts (Acquired, Indie
Hackers, My First Million, The Mom Test), App Annie / Sensor Tower public
notes, and A16Z / Andreessen Horowitz consumer writeups.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/lens-pattern-matching.md
git commit -m "feat(gtm-v4): lens L4 — pattern-matching template (web research)"
```

---

### Task B5: Lens template — first-principles (L5)

**Files:**
- Create: `docs/gtm-v4/01-templates/lens-first-principles.md`

- [ ] **Step 1: Write the template**

```markdown
# Lens L5 — First Principles

## Your role
You ignore comparable-app playbooks and SaaS orthodoxy. You strip the problem
to its physics: what must be true, mechanically, for ANY route to work for this
product? You re-derive.

## Your lens
What are the minimum requirements for growth for THIS product with THIS
constraint set? What assumptions are the other lenses taking for granted
that deserve re-test? What mechanical truth would change all our answers?

## Your scope
Re-derive the question from the atoms. Challenge any assumption that sounds
like "that's how it's done" from any other lens or from v3. Do not cover
routes — cover REQUIREMENTS.

## Inputs you receive
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files
- The specific question

## Output structure (write ~400–700 words)

### 1. The growth equation for Brush Quest
Write the (informal) math: what multiplies to produce installs, and what
multiplies to produce weekly-active kids brushing. Name the coefficients.
Example: installs = impressions × CTR × LP conversion × install click-through.
WAK = installs × D1 activation × D7 retention × habit stickiness.

### 2. Bottlenecks (by the equation)
Where are the biggest leaks right now? Which coefficient is likeliest to
dominate early? What changes the shape of the curve most?

### 3. Assumptions that deserve re-test
3–5 assumptions in the other lenses or the master brief. For each:
- What is assumed
- What would happen if it's wrong
- What minimal test would verify or falsify it

Example: "Assumed: parents are the decision-maker for install. Test: ask 20
parents whether the kid asked for the app or they found it first."

### 4. The invariant
One paragraph: what IS true, regardless of which route we pick, that every
GTM plan must serve? Example: "The first 15 seconds of the landing page
decide >60% of installs; whatever brings parents there, they bounce if the
page is weak."

### 5. Your ranked takeaway
Rank the requirements (not routes) by leverage. What fixing one coefficient
would affect the most routes.

### 6. Quick failure modes
3 bullets: how first-principles thinking misleads (e.g., "mistaking the model
for the territory; the equation ignores psychology").

## Style
- Mechanical. Numeric where possible.
- Skeptical of received wisdom.
- Distinguish "is proven" from "is assumed".
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/lens-first-principles.md
git commit -m "feat(gtm-v4): lens L5 — first-principles template"
```

---

### Task B6: Evaluator template — Skeptical CFO / attribution (E1)

**Files:**
- Create: `docs/gtm-v4/01-templates/evaluator-cfo.md`

- [ ] **Step 1: Write the template**

```markdown
# Evaluator E1 — Skeptical CFO + Attribution

## Your role
You are the CFO of a post-seed consumer-app company. You have been burned by
marketing teams claiming attribution they could not prove. You believe CAC
numbers only if you can trace them to a specific event the platform actually
measures.

## Your input
The Synth-1 output at this node (a tiered portfolio plan).

## Your job
Evaluate the plan through a realistic ROI + measurability lens. You do NOT
kill routes. You strengthen, test, or de-prioritize (move to Tier-3 with a
trigger condition).

## Output structure (write ~400–600 words)

### 1. Overall ROI read
Is this plan internally coherent on ROI math? Name the weakest number.

### 2. Attribution audit (by bet)
For each Tier-1 and Tier-2 bet, audit:
- **Measurable?** Can we actually tell if this worked? What system records it?
- **Attribution gap?** Where is causation assumed without data?
- **Time-to-signal realism** — is the stated window believable?
- **Cash-burn tail risk** — what if this runs 2× cost and 0.5× volume?

### 3. Strengthen
Specific edits that make the plan's ROI story real. Example: "Add Play Console
referrer tracking as an acceptance criterion before any paid UA PRD starts."

### 4. Test (cheap experiments to de-risk before commitment)
1–3 cheap tests that would change confidence on a Tier-1 bet. Name each test.

### 5. De-prioritize (move to Tier-3 with trigger)
Bets whose ROI thesis doesn't hold at this stage. For each, specify the
trigger condition that would bring it back to Tier-2. Do NOT delete.

### 6. Your overall confidence
One sentence. Confidence band + the single number that would flip you.

## Style
- Numeric. Skeptical. Specific.
- Named metrics, named systems, named windows.
- No "holistic" or "strategic" hand-waving.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/evaluator-cfo.md
git commit -m "feat(gtm-v4): evaluator E1 — CFO/attribution template"
```

---

### Task B7: Evaluator template — Target parent (E2)

**Files:**
- Create: `docs/gtm-v4/01-templates/evaluator-target-parent.md`

- [ ] **Step 1: Write the template**

```markdown
# Evaluator E2 — Target Parent (ICP)

## Your role
You are a tired parent of a 6–8yo kid. It's 9pm. You are scrolling Instagram
with half-attention, half-watching a show. You have never heard of Brush
Quest. You were recommended 20 apps for your kid over the last 18 months and
you have deleted 17.

## Your input
The Synth-1 output at this node.

## Your job
React to the plan as a real person in the target ICP. You do NOT kill routes.
You tell the factory which routes would actually reach you and which wouldn't.

## Output structure (write ~400–600 words)

### 1. Gut reaction
2–3 sentences. If I saw the top Tier-1 play coming at me, would I engage? Why
or why not? What's the 2-second impression?

### 2. Moments of trust and bounce
For each Tier-1 and Tier-2 bet, write one line on:
- **Where trust builds** (what would make me stop scrolling and pay attention?)
- **Where I'd bounce** (what would trigger my "kids-app marketing cringe"
  reflex? What would make me think this is a "screen time trap"?)

### 3. The ad / post / page copy test
Take the best copy or hook implied by the plan. As a tired parent, does it
land? If not, what lands better — in my words?

### 4. What a real parent would actually share
Identify 1 route where real parents would organically pass this on to
another parent. Identify 1 route where that would NEVER happen. Explain
in parent voice, not marketing voice.

### 5. Strengthen
2–3 edits that would make the plan more likely to convert a real parent in
my seat.

### 6. Your overall verdict
Would I install the app after the best-case version of Tier-1 reaching me?
One sentence, plain.

## Style
- Write in the voice of an actual parent.
- Okay to be slightly irritated, blunt.
- Avoid marketing jargon. If the plan uses it, call it out.
- Do not say "as a parent"; just speak.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/evaluator-target-parent.md
git commit -m "feat(gtm-v4): evaluator E2 — target parent template"
```

---

### Task B8: Evaluator template — Solo-founder executor-agent (E3)

**Files:**
- Create: `docs/gtm-v4/01-templates/evaluator-solo-founder-agent.md`

- [ ] **Step 1: Write the template**

```markdown
# Evaluator E3 — Solo-founder Executor-Agent

## Your role
You are the executor-agent responsible for actually running whatever this
plan produces. You have access to: Claude Code, the Brush Quest repo, a $1K
run-rate budget, your founder (Jim) for ~5 hours/week approvals, and the
MCPs / tools the project has already integrated. You will read the PRDs this
plan produces and try to execute them next week.

## Your input
The Synth-1 output at this node.

## Your job
Evaluate whether the plan is actually executable by an agent-plus-founder
pair with the real resources, this week. You do NOT kill routes. You
strengthen, test, or de-prioritize.

## Output structure (write ~400–700 words)

### 1. Executability score
For each Tier-1 and Tier-2 bet, score:
- **Tool readiness** — do we have the MCPs/APIs/credentials this requires?
  If not, name the blocking PRD that would need to ship first.
- **Human-in-loop load** — how much Jim time per week does this consume?
  (Rough estimate in hours.)
- **Action-to-signal loop** — can an agent run this autonomously, or does it
  loop on human approval every step? The second case is slow.
- **Failure modes an agent will fall into** — likely places an agent gets
  stuck and pings Jim.

### 2. Tool gaps
List tools/MCPs/credentials the plan assumes but we don't have. Each gap
becomes a pre-requisite PRD in the output.

### 3. The shape of the executor agent(s)
For each active route, name the executor-agent it needs. Is it one existing
agent, a new specialized agent, or a generalist? What does its escalation
rule look like?

### 4. Strengthen
Edits that make the plan more agent-runnable (e.g., specify tools per PRD,
add escalation triggers, flag human approval points).

### 5. De-prioritize to Tier-3
Routes that are sound but not agent-executable at our current tool level.
Specify the trigger that would bring them back (e.g., "when a voiceover-
cloning MCP ships"). Do NOT delete.

### 6. Your overall verdict
One paragraph: can the agent-plus-founder pair realistically hit this plan's
first-30-day targets?

## Style
- Engineering-realistic. Specific about tools and credentials.
- Distinguish "can do today" from "can do in 2 weeks" from "can never do
  without hiring a human."
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/evaluator-solo-founder-agent.md
git commit -m "feat(gtm-v4): evaluator E3 — solo-founder executor-agent template"
```

---

### Task B9: Synth-1 prompt template

**Files:**
- Create: `docs/gtm-v4/01-templates/synth-1-prompt.md`

- [ ] **Step 1: Write the template**

```markdown
# Synth-1 — Portfolio Synthesis

## Your role
You read the 5 lens agent outputs for this loop, plus `00-master-brief.md`
and ancestor `_synth-final.md` files, and produce a tiered portfolio plan
for this node.

## Your inputs
- `_research/L1-digital-native.md`
- `_research/L2-bold-contrarian.md`
- `_research/L3-frugal-scrappy.md`
- `_research/L4-pattern-matching.md`
- `_research/L5-first-principles.md`
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files

## Your job
Compose the 5 lens outputs into a tiered portfolio plan. You do NOT pick a
single winner. You preserve optionality with Tier-1/2/3 structure. You name
the specific hypothesis, CAC band, volume, and time-to-signal for every bet.

## Output path
Write to `<node-path>/_synth-v1.md`.

## Output structure (no hard length cap; target ~900–1,800 words)

### 1. Question restated
One paragraph: the question this loop answers and which parent decisions
(from ancestor synth-finals) bind the answer.

### 2. Where the lenses agree
The converged signals across ≥3 of 5 lenses. High-signal consensus.

### 3. Where the lenses disagree
Real tensions. For each: what's the disagreement, which lens to trust for
which reason, what resolving it would require. Do NOT paper over tensions.

### 4. Tier-1 bets (main pushes)
2–4 bets. For each:
- **Bet:** one-sentence name
- **Hypothesis:** why we think this works, derived from which lens + evidence
- **Expected CAC:** lo / mid / hi bands in $
- **Expected volume:** installs or qualified leads over what window
- **Time-to-signal:** how many days before we know it's working
- **Budget + agent-hours required:** rough numbers
- **Readiness:** PRD-executable now, or needs child loop? (Drives termination.)

### 5. Tier-2 experiments (parallel cheap tests)
3–6 experiments, each one variable, each with kill criterion + budget ≤ 20%
of Tier-1 total.

### 6. Tier-3 parked (revisit on trigger)
Routes that are viable but wrong for this stage. For each: the explicit
trigger condition that would promote it to Tier-2 (e.g., "when WAK ≥ 500",
"when CAC on Tier-1 channel > $40").

### 7. Sequencing
Which Tier-1 runs first. What the trigger is for the second. What Tier-2
experiments run in parallel.

### 8. Budget allocation
Default 70% Tier-1 / 20% Tier-2 / 10% Tier-3 activation reserve. Adjust if
the plan warrants; justify any deviation.

### 9. Open questions + uncertainty
What you don't know that matters. What a week of data would change.

## Style
- Structured, scannable. Use tables for the Tier tables.
- Cite lens output locations when taking a position (e.g., "per L4 §2,
  Lingokids's ASO was their #1 channel 2022–2023").
- Don't average lenses; compose them. The lens that disagrees most may be
  the one that's right.
- No vague language. Every bet has a CAC, a volume, and a time-to-signal.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/synth-1-prompt.md
git commit -m "feat(gtm-v4): synth-1 portfolio synthesis template"
```

---

### Task B10: Synth-2 prompt template

**Files:**
- Create: `docs/gtm-v4/01-templates/synth-2-prompt.md`

- [ ] **Step 1: Write the template**

```markdown
# Synth-2 — Final Plan

## Your role
You read Synth-1's output plus the 3 evaluator outputs and produce the
node's frozen `_synth-final.md`. This is the immutable context any child
loop receives.

## Your inputs
- `<node-path>/_synth-v1.md`
- `<node-path>/_evals/E1-cfo.md`
- `<node-path>/_evals/E2-target-parent.md`
- `<node-path>/_evals/E3-solo-founder-agent.md`
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files

## Your job
Fold evaluator feedback into Synth-1's plan. Preserve Tier-1/2/3 structure.
No route gets killed; routes can de-prioritize to Tier-3 with a trigger.
Strengthen bets with evaluator edits. Specify the PRDs (or child loop
questions) each Tier-1 and Tier-2 bet will spawn.

## Output path
Write to `<node-path>/_synth-final.md`.

## Output structure

### 1. Headline decision
2–3 sentences: what this node decides. Names the top Tier-1 bet and its
shape.

### 2. Changes from Synth-1 (transparency)
Bullet list of what changed, citing which evaluator drove each change.
Example: "Tier-1 paid UA de-prioritized to Tier-3 (trigger: WAK ≥ 500) per
E1's attribution concerns."

### 3. Tier-1 bets (final)
For each, same fields as Synth-1 plus:
- **Addressing evaluator concerns:** which issues from E1/E2/E3 were
  resolved, and how.
- **Spawns:** either (a) PRD-ids at this node, OR (b) child loop question
  the next recursion level will answer.

### 4. Tier-2 experiments (final)
Same as Synth-1, plus kill criteria + analyzer agent specified.

### 5. Tier-3 parked (with triggers)
Same as Synth-1, trigger conditions tightened.

### 6. Termination gate result
One section with bullet points for each Tier-1 and Tier-2 bet:
- `[✓] PRD-executable now` → see `prds/PRD-*.md`
- `[ ] Needs child loop` → see `_meta-prd-<slug>.md`

### 7. Budget + sequencing commitments
Final budget allocation. Sequencing rule. Escalation triggers.

### 8. What this synth-final binds for children
Explicit list of decisions downstream loops must take as given.

## Style
- Opinionated and specific. This is the record; don't hedge.
- Cite evaluator files when explaining changes.
- Machine-parseable structure (consistent headings, tables) — dashboard reads
  it later.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/synth-2-prompt.md
git commit -m "feat(gtm-v4): synth-2 final-plan template"
```

---

### Task B11: PRD template + worked example

**Files:**
- Create: `docs/gtm-v4/01-templates/prd-template.md`

- [ ] **Step 1: Write the template**

```markdown
# PRD Template — Agent-Executable GTM Work Order

Use this template for every PRD that terminates a loop branch. A PRD is the
leaf artifact: an executor agent consumes it and runs the GTM action.
Length is not capped — include all context an executor needs to act without
the founder.

## Filename convention

`<node-path>/prds/PRD-GTM-<slug>-NNN.md`

Example: `trunk/marketing/ugc/instagram-reels/prds/PRD-GTM-instagram-reels-001.md`

## YAML front-matter (required)

```yaml
---
id: PRD-GTM-<slug>-NNN
title: <one-line description>
parent_question: <the loop question that produced this PRD>
parent_node: <path in tree>
tier: 1 | 2 | 3
status: draft | approved | in-flight | done | parked | escalated
owner_agent: <executor agent id>
budget:
  dollars: <ceiling>
  tokens: <ceiling>
  agent_hours: <estimate>
  jim_hours: <human-in-loop minutes>
timeline:
  start: YYYY-MM-DD
  checkpoints: [YYYY-MM-DD, YYYY-MM-DD]
  end: YYYY-MM-DD
depends_on: []
blocks: []
experiments: []
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---
```

## Body sections (required)

### Goal
One sentence. Measurable. Specific metric + window.

### Context brief
Everything the executor needs to act without Jim:
- Product state (what's live, what's in flight)
- Target persona (who, where, when)
- Constraints (COPPA, brand tone, locked product decisions)
- Prior decisions from ancestor `_synth-final.md` (what's been decided upstream)
- What's been tried and what happened

### Inputs required
- Credentials / OAuth tokens
- Assets / files by path
- Prior PRD outputs consumed
- Tools / MCPs

### Outputs required
- Artifacts (posts, accounts, files)
- Data (metrics, logs)
- Locations (paths, URLs)

### Acceptance criteria
Checkbox list. Executor does not mark `done` until ALL boxes pass.

### Metrics
- Primary: which number, over what window, how attributed
- Secondary: supporting numbers
- Attribution window: explicit days
- Measurement system: which file/dashboard holds the truth

### Tools the executor needs
- MCPs by name
- APIs + auth
- Human-in-loop approval points

### Escalation triggers
Executor pauses and pings Jim via `tg send` when:
- Budget ≥ 80%
- Metric misses by ≥ 50% of target at midpoint
- COPPA / legal flag
- Platform flag (account warning)
- Any unexpected failure mode

### Risks + mitigations
- Risk 1 → Mitigation 1
- Risk 2 → Mitigation 2

### Change log
- YYYY-MM-DD Created (PRD id)
- (future edits appended)

---

## Worked example

```yaml
---
id: PRD-GTM-instagram-reels-001
title: 6 Reels + experiment on hook style — 14 days
parent_question: "Produce agent-executable PRDs to get 50 qualified parent installs via organic Instagram Reels in 14 days"
parent_node: trunk/marketing/ugc/instagram-reels
tier: 1
status: draft
owner_agent: instagram-executor-agent
budget: { dollars: 0, tokens: 500000, agent_hours: 8, jim_hours: 45 }
timeline:
  start: 2026-04-25
  checkpoints: [2026-04-28, 2026-05-01, 2026-05-05]
  end: 2026-05-09
depends_on: []
blocks: []
experiments: [EXP-GTM-instagram-hook-001]
created: 2026-04-20
last_updated: 2026-04-20
---
```

### Goal
Post 6 Reels to @brushquestapp in 14 days, achieving a median of ≥2,500 views per
Reel and ≥50 attributable Play Store internal-testing installs.

### Context brief
Brush Quest is live on Google Play internal testing (v1.0.0+17) with an open
testing URL. The landing page at brushquest.app has parent-facing copy and a
Play Store CTA. No ads, no subscription, $9.99 premium (not yet live), COPPA
strict — no child faces, no kid voices from real kids. All Reel content is
either gameplay footage or parent-voiced commentary. Brand tone: warm,
practical, slightly irreverent about "brushing is miserable." Parent buyer,
not kid.

### Inputs required
- Instagram Business account + Meta Graph API token (credential: `meta-graph-token`)
- 10 gameplay clips in `assets/marketing/clips/`
- Brand pack: `docs/brand/` (logo, colors, voice)
- Copy bank: PRD-GTM-copy-bank-001 (if it exists; if not, this PRD generates it)
- Tool: `@meta-graph-mcp` for posting + insights
- Tool: FFmpeg for editing (via Bash)
- Tool: ElevenLabs MCP for voiceover (optional variants)

### Outputs required
- 6 Reels posted at @brushquestapp, each tagged with experiment variant
- Caption + first-comment link per Reel, UTM'd to Play Store open-testing URL
- Posting log: `trunk/marketing/ugc/instagram-reels/_data/posts.yaml`
- 24h/72h/7d metric snapshots per post
- Experiment analysis: `EXP-GTM-instagram-hook-001.md` updated with winner by day 14
- Post-mortem: `_learnings.md` appended

### Acceptance criteria
- [ ] 6 Reels posted within 14 days of start
- [ ] Each Reel tagged with its experiment variant (parent-face / kid-face-
      animated / voiceover-only)
- [ ] Each Reel's view/save/share/click metrics logged at 24h and 7d
- [ ] UTM attribution captured; attempt Play Console referrer match
- [ ] Experiment analyzer agent invoked at day 14; winner declared (or NO_WINNER)
- [ ] Post-mortem doc written to `_learnings.md`
- [ ] No COPPA or brand-tone violations in any posted content

### Metrics
- Primary: attributable Play Store internal-testing installs via UTM
- Secondary: median views, save rate, share rate, comment sentiment
- Attribution window: 7 days from view
- Measurement system: `_data/posts.yaml` + Play Console referrer report

### Tools the executor needs
- MCP: `@meta-graph-mcp` (post, read insights)
- MCP: `elevenlabs` (optional voiceover variants)
- CLI: FFmpeg via Bash
- Human-in-loop: Jim approves first Reel before posting (one-time)

### Escalation triggers
- Budget spent: ≥80% of agent-hours ceiling → pause + `tg send`
- Metric miss: median views <500 after 3 posts → pause + `tg send`
- COPPA/brand flag: any flagged content → pause immediately + `tg send`
- Platform flag: IG warning on account → pause + `tg send`

### Risks + mitigations
- Risk: cold-account Reels get <1K views early → Mitigation: L4 research showed
  5-post burn-in is normal; budget for it in the first 3 posts' expectations.
- Risk: IG algorithm shift mid-run → Mitigation: cross-post one variant to TikTok
  and Shorts as control.
- Risk: voiceover rate limit → Mitigation: pre-generate all voiceovers week 1.

### Change log
- 2026-04-20 Created PRD-GTM-instagram-reels-001
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/prd-template.md
git commit -m "feat(gtm-v4): PRD template + worked Instagram Reels example"
```

---

### Task B12: Experiment template

**Files:**
- Create: `docs/gtm-v4/01-templates/experiment-template.md`

- [ ] **Step 1: Write the template**

```markdown
# Experiment Template — Structured Learning Unit

Experiments are PRD-spawned learning units. A PRD says "do this"; an
experiment says "compare these variants to learn which works." Experiments
belong to one of three scopes (within-PRD, cross-PRD, cross-tier — see spec
§5).

## Filename convention

`<node-path>/_experiments/EXP-GTM-<slug>-NNN.md`

## YAML front-matter (required)

```yaml
---
id: EXP-GTM-<slug>-NNN
scope: within-PRD | cross-PRD | cross-tier
parent_prd: PRD-id | null
hypothesis: "<statement of what we expect, with magnitude>"
variables:
  independent: <the one thing that varies>
  held_constant: [<...>, <...>]
variants:
  - name: <variant 1>
  - name: <variant 2>
  - name: <variant 3>
primary_metric: <metric name>
primary_threshold: "<magnitude + confidence>"
secondary_metrics: [<...>, <...>]
sample_target: <e.g., 5000 views per variant>
time_window_days: <N>
kill_criteria:
  - "<condition 1>"
  - "<condition 2>"
budget_ceiling: { dollars: <n>, tokens: <n>, agent_hours: <n> }
owner_agent: <executor agent id>
analyzer_agent: experiment-analyzer-agent
status: designed | running | analyzed | winner-declared | no-winner | killed
created: YYYY-MM-DD
declared_winner: <variant name | NO_WINNER | KILLED>
declared_at: YYYY-MM-DD
---
```

## Body sections (required)

### Rationale
Why this experiment is worth running. What decision it unblocks.

### Prior art
Evidence from Lens L4 or prior experiments that suggests the hypothesis.
Cite sources.

### Design
Exactly what varies. Exactly what's held constant. Sample size reasoning.
Why this statistical threshold.

### What we do with the winner
If variant X wins, the next action is: ______.

### What we do on NO_WINNER
If no variant clears threshold, the next action is: ______.

### Data collection
- Where raw data lands
- Who writes it (executor agent)
- Who reads it (analyzer agent)
- Refresh cadence

### Hard discipline rules
- One variable at a time. Not two. Not three.
- Kill criteria enforced automatically by the analyzer agent.
- Executor agent does NOT declare winner — analyzer agent does.
```

- [ ] **Step 2: Self-check + Commit**

```bash
git add docs/gtm-v4/01-templates/experiment-template.md
git commit -m "feat(gtm-v4): experiment template"
```

---

## Sub-phase C — Skill orchestration

Goal of sub-phase C: the `.claude/commands/gtm-factory.md` slash command exists and can run the full loop for a given question + node path.

### Task C1: Create `.claude/commands/gtm-factory.md` — skeleton + routing

**Files:**
- Create: `.claude/commands/gtm-factory.md`

- [ ] **Step 1: Write the skeleton**

```markdown
# /gtm-factory — GTM PRD Factory

Orchestrator for the GTM PRD Factory. Produces agent-executable PRDs via a
loop of 5 lens research agents → Synth-1 → 3 persona evaluators → Synth-2 →
termination gate.

Design spec: `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`
Templates: `docs/gtm-v4/01-templates/`
Master brief: `docs/gtm-v4/00-master-brief.md`

## Route on arguments

Parse `$ARGUMENTS`:

- **`new-loop <node-path> "<question>"`** → Run a full loop at the named node
  path for the given question. Core Phase 1 command. Details below.
- **`pulse <node-path>`** → NOT YET IMPLEMENTED (Phase 2). Say so and exit.
- **`re-rank <node-path>`** → NOT YET IMPLEMENTED (Phase 2). Say so and exit.
- **`meta-eval`** → NOT YET IMPLEMENTED (Phase 3). Say so and exit.
- **`status`** → Read all `_status.yaml` files in `docs/gtm-v4/` and print a
  tree snapshot.
- **No args or unknown** → Print usage.

Strict rule for unimplemented subcommands: output "Phase 2 — not yet
implemented. See `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`
§6 for design; implementation plan to follow." and exit without side effects.

## Phase 1 command: `new-loop <node-path> "<question>"`

<!-- Sub-phase C tasks will fill in this section -->
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): skill skeleton + argument routing"
```

---

### Task C2: Skill section — context-brief assembly

**Files:**
- Modify: `.claude/commands/gtm-factory.md` (append section)

- [ ] **Step 1: Append to `.claude/commands/gtm-factory.md`**

Append after the routing section:

```markdown
### Step 1: Assemble the context brief

Before dispatching any agent, build the context brief every lens agent,
evaluator, and synth agent will receive.

1. **Refresh the master brief.** Check `git log -1 docs/gtm-v4/00-master-brief.md`.
   If older than 7 days, regenerate it from:
   - `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md`
   - Recent `git log --oneline -30`
   - `pubspec.yaml` (current version)
   - `STATUS.md` (if present)
   Rewrite the brief in place; commit the update.

2. **Gather ancestor synth-finals.** For the given `<node-path>`, walk from
   root (`docs/gtm-v4/trunk/`) down to the parent. For each ancestor, read
   its `_synth-final.md` if present. Missing at intermediate nodes is OK
   (the node hasn't run a loop yet); record this fact in the assembled
   brief.

3. **Gather ancestor meta-PRDs.** Same walk. Read any `_meta-prd*.md` files
   at ancestors if they exist.

4. **Read any `_escalation.md` at the current node.** If present, halt and
   report: "Open escalation at this node; resolve before running new loop."

5. **Compose the assembled brief** as a single string:

   ```
   # Context for loop at <node-path>
   ## Question
   <the question>
   ## Master brief
   <verbatim contents of 00-master-brief.md>
   ## Ancestor synth-finals (root → parent)
   <each file as its own section, clearly labeled with source path>
   ## Ancestor meta-PRDs (root → parent)
   <each file as its own section>
   ## Decisions log (cross-node)
   <verbatim contents of 02-decisions-log.md>
   ```

   Write this assembled brief to `<node-path>/_context-brief.md`. Overwrite
   any prior version. This file exists for audit and debugging; it is an
   intermediate artifact.

6. **Create the loop directory structure:**

   ```bash
   mkdir -p <node-path>/_research
   mkdir -p <node-path>/_evals
   # prds/ and _experiments/ only created if loop output produces them
   ```
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): context-brief assembly step"
```

---

### Task C3: Skill section — new-loop orchestration

**Files:**
- Modify: `.claude/commands/gtm-factory.md` (append sections for each step of the loop)

- [ ] **Step 1: Append the research phase section**

```markdown
### Step 2: Research phase — dispatch 5 lens agents in parallel

Dispatch 5 Agent tool calls in a SINGLE message (parallel execution). Each
agent uses `subagent_type: general-purpose` except L4 which needs web
access.

For each lens, the prompt is a concatenation of:
1. The lens template file contents (e.g., `docs/gtm-v4/01-templates/lens-digital-native.md`)
2. The assembled context brief written in Step 1
3. An instruction to write its output to a specific file path:
   "Write your output to `<node-path>/_research/L1-digital-native.md`. Use
   the output structure specified in the template. Do not write anywhere else."

The 5 agents and their output paths:

| Agent | Template | Output path |
|-------|----------|-------------|
| L1 | `docs/gtm-v4/01-templates/lens-digital-native.md` | `<node-path>/_research/L1-digital-native.md` |
| L2 | `docs/gtm-v4/01-templates/lens-bold-contrarian.md` | `<node-path>/_research/L2-bold-contrarian.md` |
| L3 | `docs/gtm-v4/01-templates/lens-frugal-scrappy.md` | `<node-path>/_research/L3-frugal-scrappy.md` |
| L4 | `docs/gtm-v4/01-templates/lens-pattern-matching.md` | `<node-path>/_research/L4-pattern-matching.md` |
| L5 | `docs/gtm-v4/01-templates/lens-first-principles.md` | `<node-path>/_research/L5-first-principles.md` |

After all 5 agents return:
- Verify all 5 output files exist and are non-empty.
- Skim each to confirm the lens voice is distinct (a smoke check; if L1 and
  L3 produce near-identical output, flag a template problem and stop).

Commit the 5 research files:

```bash
git add <node-path>/_research/
git commit -m "loop(<node-path>): 5 lens research outputs"
```
```

- [ ] **Step 2: Append the Synth-1 step**

```markdown
### Step 3: Synth-1

Dispatch a single Agent tool call with `subagent_type: general-purpose`.

Prompt is a concatenation of:
1. The Synth-1 template: `docs/gtm-v4/01-templates/synth-1-prompt.md`
2. The assembled context brief
3. The 5 research files (read and inlined or handed by path — prefer inline)
4. An instruction: "Write your output to `<node-path>/_synth-v1.md`."

After the agent returns, verify the output file exists, is non-empty, and
contains Tier-1, Tier-2, Tier-3 section headings. If any missing, re-dispatch
with an explicit correction instruction (once); if still missing, stop and
escalate via `tg send`.

Commit:

```bash
git add <node-path>/_synth-v1.md
git commit -m "loop(<node-path>): synth-1 portfolio draft"
```
```

- [ ] **Step 3: Append the evaluator phase**

```markdown
### Step 4: Evaluator phase — dispatch 3 persona agents in parallel

Dispatch 3 Agent tool calls in a SINGLE message (parallel).
`subagent_type: general-purpose`.

For each evaluator, the prompt is:
1. The evaluator template file contents
2. The assembled context brief
3. The Synth-1 output (inlined)
4. An instruction to write to the specific output path

| Agent | Template | Output path |
|-------|----------|-------------|
| E1 | `docs/gtm-v4/01-templates/evaluator-cfo.md` | `<node-path>/_evals/E1-cfo.md` |
| E2 | `docs/gtm-v4/01-templates/evaluator-target-parent.md` | `<node-path>/_evals/E2-target-parent.md` |
| E3 | `docs/gtm-v4/01-templates/evaluator-solo-founder-agent.md` | `<node-path>/_evals/E3-solo-founder-agent.md` |

Verify all 3 files exist and contain distinct feedback (smoke check: if two
evaluators produce near-identical critiques, flag template problem).

Commit:

```bash
git add <node-path>/_evals/
git commit -m "loop(<node-path>): 3 evaluator outputs"
```
```

- [ ] **Step 4: Append the Synth-2 step**

```markdown
### Step 5: Synth-2 — final plan

Dispatch a single Agent tool call with `subagent_type: general-purpose`.

Prompt is a concatenation of:
1. `docs/gtm-v4/01-templates/synth-2-prompt.md`
2. The assembled context brief
3. Synth-1 output
4. All 3 evaluator outputs
5. Instruction: "Write your output to `<node-path>/_synth-final.md`."

After the agent returns, verify the file exists and contains the termination
gate section (step 6 depends on it).

Commit:

```bash
git add <node-path>/_synth-final.md
git commit -m "loop(<node-path>): synth-final — plan frozen"
```
```

- [ ] **Step 5: Commit the orchestration section**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): new-loop orchestration — 5→1→3→1 flow"
```

---

### Task C4: Skill section — termination gate + status.yaml

**Files:**
- Modify: `.claude/commands/gtm-factory.md` (append)

- [ ] **Step 1: Append the termination-gate section**

```markdown
### Step 6: Termination gate

Read `<node-path>/_synth-final.md`. For each bet in Tier-1 and Tier-2,
determine which branch:

**Branch A — PRD-executable now.** The gate passes when ALL of the following
are demonstrably present in the Synth-final's description of this bet:
1. Measurable goal with specific metric + window.
2. Context fully specified (can an executor agent act without Jim?).
3. Every input named with location (path, credential id, MCP id, prior PRD).
4. Acceptance criteria are checkable (no "looks good").
5. Tools required exist or are explicitly flagged as TO-BUILD (which becomes
   a blocking PRD of its own).
6. Escalation triggers specified.

If all 6 pass → **Emit a PRD** at `<node-path>/prds/PRD-GTM-<slug>-NNN.md`
using the `docs/gtm-v4/01-templates/prd-template.md` structure. Fill in
every section based on the Synth-final's description of this bet. Commit.

**Branch B — Needs child loop.** Any of the 6 fails → **Emit a meta-PRD** at
`<node-path>/_meta-prd-<slug>.md` that serves as the charter for the child
loop on this bet. The meta-PRD names: (a) the child question to answer,
(b) what the child loop must produce, (c) which of the 6 criteria above are
missing that the child loop will resolve.

**Tier-3 bets** get neither — they stay in `_synth-final.md`'s Tier-3 list
with their trigger condition. No PRD, no meta-PRD.

For this task, dispatch one Agent tool call with `subagent_type:
general-purpose`. Prompt includes the Synth-final, the PRD template, and
instructions to read through each bet and emit the appropriate file(s).
The agent writes PRDs + meta-PRDs directly.

After the agent returns, read `<node-path>/prds/` and `<node-path>/` for
the emitted files. Verify at least one artifact per Tier-1/2 bet exists.

Commit:

```bash
git add <node-path>/prds/ <node-path>/_meta-prd-*.md 2>/dev/null
git commit -m "loop(<node-path>): termination gate — PRDs + meta-PRDs emitted"
```
```

- [ ] **Step 2: Append the `_status.yaml` section**

```markdown
### Step 7: Emit `_status.yaml`

Write `<node-path>/_status.yaml`:

```yaml
node: <node-path>
depth: <int, derived from path depth under docs/gtm-v4/>
created: <YYYY-MM-DD of first loop — keep if exists>
last_loop_completed: <YYYY-MM-DD of today>
last_pulse: null           # filled when Loop A ships
active_prds: <count of PRDs in prds/ with status in [draft, approved, in-flight]>
completed_prds: <count with status: done>
active_experiments: 0      # placeholder until experiments execute
learnings_count: 0         # placeholder
children:                  # directories under this node with _status.yaml
  - <child-path>
tier: <this node's tier at its parent — pull from parent's _synth-final.md>
open_escalations: <count of _escalation.md files here or in descendants>
```

Commit:

```bash
git add <node-path>/_status.yaml
git commit -m "loop(<node-path>): status emitted"
```
```

- [ ] **Step 3: Append the summary section**

```markdown
### Step 8: Summary + notification

After all steps:
1. Print a one-line summary: `Loop at <node-path> complete. N PRDs emitted,
   M meta-PRDs queued, K Tier-3 parked.`
2. Ping Jim via Telegram: `tg send "GTM loop complete: <node-path> — <summary>"`
3. If any escalation was written during the loop, include it in the ping
   with a link to the file.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): termination gate + status.yaml + summary"
```

---

### Task C5: Skill section — escalation valve

**Files:**
- Modify: `.claude/commands/gtm-factory.md` (append)

- [ ] **Step 1: Append the escalation section**

```markdown
### Escalation valve (invoked from any step)

If during any step, a lens agent, evaluator, or synth agent identifies strong
evidence that a parent decision (from an ancestor `_synth-final.md`) is
invalidated by new information, the loop halts and emits:

```markdown
# Escalation — <node-path>

## Date
YYYY-MM-DD

## Parent decision challenged
<quote from ancestor _synth-final.md>

## Evidence
<the new information>

## Proposed revision
<what the ancestor would need to change>

## Blocking
<what's halted waiting on resolution>
```

Write to `<node-path>/_escalation.md`. Then:
1. Commit the escalation doc.
2. `tg send "GTM escalation at <node-path>: <one-line summary>"`.
3. STOP the loop. Do not run subsequent steps.

Escalations should be rare. If multiple fire in short succession, flag a
template problem (future Loop C input).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): escalation valve"
```

---

### Task C6: Skill section — `status` subcommand

**Files:**
- Modify: `.claude/commands/gtm-factory.md` (append)

- [ ] **Step 1: Append the status section**

```markdown
## Subcommand: `status`

Print a tree snapshot of `docs/gtm-v4/` showing every node with its status.

Algorithm:
1. Find all `_status.yaml` files under `docs/gtm-v4/`.
2. Parse each; print indented by path depth.
3. For each node, print: path, last_loop_completed, active_prds, tier,
   open_escalations.
4. At the end, list all open escalation files and all active PRDs across
   the tree.

Output format (plaintext, not rendered):

```
docs/gtm-v4/
├─ trunk/                    [loop: 2026-05-01  PRDs: 0  tier: –  esc: 0]
│  ├─ marketing/             [loop: 2026-05-02  PRDs: 0  tier: 1  esc: 0]
│  │  └─ ugc/
│  │     └─ instagram-reels/ [loop: 2026-05-03  PRDs: 2  tier: 1  esc: 0]
│  └─ partnerships/          [loop: –           PRDs: 0  tier: 2  esc: 0]

Active PRDs (2):
- PRD-GTM-instagram-reels-001  draft  owner: instagram-executor-agent
- PRD-GTM-instagram-reels-002  draft  owner: instagram-executor-agent

Open escalations (0).
```

No agent dispatch needed. Pure file-read + format.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gtm-factory.md
git commit -m "feat(gtm-factory): status subcommand"
```

---

## Sub-phase D — Validation run

Goal of sub-phase D: run the validation loop end-to-end and confirm the machinery works.

### Task D1: Define the validation question at trunk level + scaffolding

**Files:**
- Create: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_question.md`

- [ ] **Step 1: Create node directory + question**

```bash
mkdir -p docs/gtm-v4/trunk/marketing/ugc/instagram-reels
```

- [ ] **Step 2: Write the question file**

Create `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_question.md`:

```markdown
# Validation Loop Question

## Question
Produce a complete set of agent-executable PRDs to get 50 qualified parent
installs to Play Store internal testing in 14 days via organic Instagram
Reels, and hand them to executor agents to run.

## Node path
`trunk/marketing/ugc/instagram-reels`

## Why this question
This is the C-pass validation for the GTM PRD Factory. Narrow enough to
complete in one loop, broad enough to exercise every gate (5 lenses,
3 evaluators, termination check, PRD emission). Even if the loop finds
bugs in templates or orchestration, we fix them here cheaply before the
trunk-level B question.

## Why this channel (briefly)
Instagram Reels has algorithmic distribution — cold accounts can reach
parents without network effects or admin approval. Meta Graph API enables
agentic pipelines. Parents-of-young-kids are demonstrably on IG (L4 will
ground-truth this).

## Acceptance criteria (for the validation itself)
- [ ] 5 distinct lens outputs in `_research/` (different voices visible)
- [ ] Synth-1 contains Tier-1, Tier-2, Tier-3 sections
- [ ] 3 distinct evaluator outputs in `_evals/`
- [ ] Synth-2 folds evaluator feedback visibly
- [ ] At least 1 PRD emitted that passes the spec §4 termination criteria
- [ ] `_status.yaml` present at the node
- [ ] Telegram ping received
```

- [ ] **Step 3: Commit**

```bash
git add docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_question.md
git commit -m "feat(gtm-v4): validation question at instagram-reels node"
```

---

### Task D2: Run the validation loop

**Files:**
- Writes: all loop artifacts under `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/`

- [ ] **Step 1: Invoke the loop**

```
/gtm-factory new-loop trunk/marketing/ugc/instagram-reels "Produce a complete set of agent-executable PRDs to get 50 qualified parent installs to Play Store internal testing in 14 days via organic Instagram Reels, and hand them to executor agents to run."
```

- [ ] **Step 2: Watch for execution milestones**

Expected, in order:
1. Master brief check passes (0–2 sec).
2. Context brief assembled to `_context-brief.md`.
3. 5 lens agents dispatch in parallel (wall-clock ~5–15 min depending on L4 web research).
4. Commit 1: 5 research files.
5. Synth-1 dispatches (~3–8 min).
6. Commit 2: synth-1.
7. 3 evaluators dispatch in parallel (~3–8 min).
8. Commit 3: 3 evaluator files.
9. Synth-2 dispatches (~3–8 min).
10. Commit 4: synth-final.
11. Termination gate dispatches (~3–5 min).
12. Commit 5: PRDs + meta-PRDs.
13. `_status.yaml` written.
14. Telegram ping.

Expected wall-clock total: 20–45 minutes for the full loop.

- [ ] **Step 3: If the loop fails**

Identify where. Most likely failure modes:
- A lens agent produces output not matching its template structure → template refinement task.
- Synth-1 misses Tier-1/2/3 structure → synth template refinement.
- Termination gate can't parse Synth-2 → synth-2 template needs structured YAML or clearer headings.

Fix the template, re-run only the failed step (not the whole loop; prior
artifacts are committed). Document the fix + re-run in the commit message.

---

### Task D3: Validate — 5 diverse lens outputs

**Files:**
- Read: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_research/L*.md`

- [ ] **Step 1: Read all 5 outputs**

- [ ] **Step 2: Check diversity**

For each pair of lenses (10 pairs), can you point to a concrete difference
in voice, approach, or ranked takeaway? Make a table:

```
L1 ↔ L2: [specific distinguishing line from each]
L1 ↔ L3: ...
...
```

If any pair reads as near-identical, the template for the weaker-voiced
lens needs refinement.

- [ ] **Step 3: Verify output structure compliance**

Each L*.md should have the sections specified in its template. Spot-check
2 of them against the template.

- [ ] **Step 4: If diversity or structure fails**

Edit the weak template. Re-dispatch just that lens agent. Replace the file.
Commit the fix with `fix(gtm-v4): lens template refinement — <lens>`.

---

### Task D4: Validate — Synth-1 tiered portfolio

**Files:**
- Read: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_synth-v1.md`

- [ ] **Step 1: Verify structure**

Confirm sections present: Question restated, Where lenses agree, Where they
disagree, Tier-1, Tier-2, Tier-3, Sequencing, Budget, Open questions.

- [ ] **Step 2: Verify every bet has required fields**

For each Tier-1 and Tier-2 bet, confirm: hypothesis, CAC band, volume,
time-to-signal, budget+agent-hours, readiness.

- [ ] **Step 3: If missing**

Edit Synth-1 template to enforce missing fields; re-dispatch Synth-1; replace
file. Commit the fix.

---

### Task D5: Validate — 3 distinct evaluator outputs

**Files:**
- Read: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_evals/E*.md`

- [ ] **Step 1: Read all 3**

- [ ] **Step 2: Confirm each persona's voice is distinct**

E1 must feel like a CFO. E2 must feel like a parent. E3 must feel like an
executor-agent. If two evaluators produce overlapping critiques on the same
weaknesses, their personas need differentiation.

- [ ] **Step 3: Confirm evaluators preserve Tier-1/2/3 structure**

No evaluator should "kill" a route. If any does, template needs the "don't
kill, de-prioritize" rule made more explicit.

- [ ] **Step 4: If failures, fix + re-dispatch + commit.**

---

### Task D6: Validate — Synth-2 folds evaluator feedback

**Files:**
- Read: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_synth-final.md`

- [ ] **Step 1: Verify change log present**

Synth-2 must have a "Changes from Synth-1" section citing which evaluator
drove each change. If absent, template fails; refine and re-dispatch.

- [ ] **Step 2: Verify Tier-3 trigger conditions**

Every Tier-3 bet must have an explicit trigger (e.g., "when WAK ≥ 500",
"when Tier-1 CAC > $40"). If any are vague, note as template gap.

- [ ] **Step 3: Verify termination-gate section present**

Each Tier-1 and Tier-2 bet labeled `[✓] PRD-executable now` or `[ ] Needs
child loop`.

---

### Task D7: Validate — At least 1 PRD emitted that passes §4 criteria

**Files:**
- Read: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/prds/PRD-*.md`

- [ ] **Step 1: List the emitted PRDs**

```bash
ls docs/gtm-v4/trunk/marketing/ugc/instagram-reels/prds/
```

- [ ] **Step 2: For the first PRD, check all 6 termination-gate criteria**

Reference: spec §4, "What makes a PRD 'executable'". Run the 6-item
checklist manually. Print pass/fail per item.

- [ ] **Step 3: If any fail**

Either:
- The Synth-2's description of this bet was thin → refine Synth-2 template
  to require more detail per Tier-1 bet, re-dispatch Synth-2, re-run gate.
- The termination-gate prompt in the skill wasn't forceful enough → refine
  the skill's gate-section, re-run the gate.

Commit fixes with `fix(gtm-factory): tighten termination gate — <detail>`.

---

### Task D8: Draft minimal `instagram-executor-agent`

**Files:**
- Create: `.claude/agents/instagram-executor-agent.md`

- [ ] **Step 1: Create the directory if needed**

```bash
mkdir -p .claude/agents
```

- [ ] **Step 2: Write the stub agent**

```markdown
# instagram-executor-agent

## Role
Execute PRDs in the `trunk/marketing/ugc/instagram-reels` sub-tree of
`docs/gtm-v4/`. Post Reels to @brushquestapp, track metrics, run
experiments, write back to PRD front-matter and `_data/`.

## Inputs
A PRD path like `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/prds/PRD-GTM-instagram-reels-001.md`.

## Tools
- MCP: `@meta-graph-mcp` (when wired)
- MCP: `elevenlabs` (for voiceover)
- CLI: FFmpeg via Bash
- `tg send` for escalation

## Startup protocol
1. Read the PRD file at the given path.
2. Read every ancestor `_synth-final.md` up the tree to `trunk/_synth-final.md`.
3. Read `docs/gtm-v4/00-master-brief.md`.
4. Read `docs/gtm-v4/02-decisions-log.md`.
5. Produce a plain-text execution plan (no action yet). Write to
   `<prd-node>/_execution-plans/<prd-id>-plan-YYYY-MM-DD.md`.
6. Send plan to Jim via `tg send` with a link. STOP and wait for approval.

## Phase 1 scope (limit)
Phase 1 of the executor-agent stops after step 6. No actual Reels are
posted until Jim approves and a follow-on plan builds out the execution
runtime (Meta Graph MCP integration, video generation pipeline, etc.).
The Phase 1 goal is only: **prove the PRD is consumable** — the agent can
read it, build a plan, and ask intelligent questions if anything is unclear.

## Acceptance (Phase 1)
- [ ] Agent reads a PRD and produces a coherent plain-text plan.
- [ ] Agent does NOT ask Jim clarification questions on anything that's
      already in the PRD or ancestor context.
- [ ] Plan names every tool it would use and every human-in-loop moment.
```

- [ ] **Step 3: Smoke test**

Invoke the agent: via Agent tool with `subagent_type: general-purpose`,
prompt = the instagram-executor-agent.md file contents + "The PRD to execute
is at `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/prds/PRD-GTM-instagram-reels-001.md`."

Verify the agent produces a plan file at `_execution-plans/` and does NOT
ask clarifying questions about anything the PRD specifies.

If the agent asks clarifying questions, the PRD has gaps — add them to the
PRD, commit, re-test.

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/instagram-executor-agent.md
git add docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_execution-plans/
git commit -m "feat(gtm-v4): instagram-executor-agent stub + smoke test"
```

---

## Sub-phase E — Handoff

### Task E1: Update MEMORY.md index

**Files:**
- Modify: `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md`

- [ ] **Step 1: Append to the References section**

Edit `MEMORY.md`; add to the `## References` section:

```markdown
- [reference_gtm_v4_factory.md](reference_gtm_v4_factory.md) — GTM PRD Factory — paths, skill, templates
```

- [ ] **Step 2: Create the reference memory**

Write `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/reference_gtm_v4_factory.md`:

```markdown
---
name: GTM v4 PRD Factory
description: Paths and conventions for the GTM factory. Use /gtm-factory new-loop <path> "<question>".
type: reference
last_verified: 2026-04-20
---

# GTM v4 — PRD Factory

## Command
- `/gtm-factory new-loop <node-path> "<question>"` — run a full loop
- `/gtm-factory status` — tree snapshot
- Phase 2 (not yet): `/gtm-factory pulse <path>`, `re-rank`, `meta-eval`

## Paths
- Spec: `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`
- Plan (Phase 1): `docs/superpowers/plans/2026-04-20-gtm-prd-factory-phase-1.md`
- Templates: `docs/gtm-v4/01-templates/`
- Master brief: `docs/gtm-v4/00-master-brief.md`
- Decisions log: `docs/gtm-v4/02-decisions-log.md`
- Tree root: `docs/gtm-v4/trunk/`
- Skill: `.claude/commands/gtm-factory.md`
- Executor agents: `.claude/agents/`

## Supersedes
- v3 output shape (`docs/gtm-engine/GTM_ENGINE_v3.md`) — narrative → PRD tree.
  v3 content still usable as L4 pattern-matching input.

## Related
- Scheduling: `reference_scheduling_infrastructure.md` (Railway, never launchd)
```

- [ ] **Step 3: Commit**

```bash
git add ~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/
git commit -m "docs: GTM v4 reference memory + MEMORY.md index update"
```

---

### Task E2: Final checkpoint + handoff

**Files:**
- None — reporting task.

- [ ] **Step 1: Verify Phase 1 completeness**

Run `/gtm-factory status`. Expected output: trunk/marketing/ugc/instagram-reels
shows a completed loop with ≥1 PRD.

- [ ] **Step 2: Report**

Send Telegram message: `tg send "GTM factory Phase 1 complete. Validation loop shipped. <N> PRDs. Ready for trunk loop or Phase 2 plans."`

- [ ] **Step 3: List follow-on plans needed**

Append to `docs/gtm-v4/02-decisions-log.md`:

```markdown
## Phase 1 complete (YYYY-MM-DD)

Follow-on plans required:
1. **Trunk loop (question B)** — run `/gtm-factory new-loop trunk "Reach 1,000 WAK by 2026-07-20 on $1–2K via agentic execution"` and emit pillar-level meta-PRDs.
2. **Loop A — pulse agent** — spec §6; Railway trigger at `jobs.json` in `~/Projects/claude-telegram-bridge/src/jobs.json`; idempotency by ISO week.
3. **Loop B — re-rank triggers + partial re-synth** — spec §6.
4. **Loop C — template meta-eval** — after 5+ loops exist.
5. **Experiments execution runtime** — spec §5; experiment-analyzer agent; `experiments-executor` wrapper.
6. **Dashboard at `brushquest.app/GTM-dashboard`** — spec §8; `frontend-design` skill.
```

- [ ] **Step 4: Commit**

```bash
git add docs/gtm-v4/02-decisions-log.md
git commit -m "docs(gtm-v4): Phase 1 closed; follow-on plans listed"
```

---

## Plan self-review

**Spec coverage check:**

| Spec section | Phase 1 task | Deferred to follow-on? |
|---|---|---|
| §1 What the factory is | A1 (README), A2 (brief), C1 (skill header) | — |
| §2 The loop | C1–C4 (full orchestration) | — |
| §3 Tree + context cascade | C2 (ancestor concat), C5 (escalation) | — |
| §4 PRD format | B11 (template), C4 (gate emission), D7 (validation) | — |
| §5 Experiments | B12 (template lands) | Executor runtime → follow-on |
| §6 Feedback loops A/B/C | — | **All three: follow-on plans** |
| §7 Scheduling | — | Follow-on (only needed with Loop A) |
| §8 Implementation shape | C1–C6 (skill), A1 (directory layout), E1 (memory) | Dashboard → follow-on |
| §9 Validation pass | D1–D8 (full run) | — |
| §10 Trunk question | — | Follow-on (runs after Phase 1 ships) |
| §11 Open/deferred | E2 (explicit follow-on list) | — |

No gaps. Phase 1 covers the MVP required for the validation pass to succeed.

**Placeholder scan:**
- No "TBD", "TODO", "fill in later" found in any task.
- Every template file has its full content drafted in the plan.
- Every step has an exact command or exact content.

**Type/path consistency:**
- Skill path: `.claude/commands/gtm-factory.md` — consistent across C1–C6 + spec §8.
- Templates: `docs/gtm-v4/01-templates/` — consistent across all B tasks + spec §8.
- Node path pattern: `<node-path>` (relative under `docs/gtm-v4/`) — consistent.
- PRD filename: `PRD-GTM-<slug>-NNN.md` — consistent in spec + B11 + D7.
- Experiment filename: `EXP-GTM-<slug>-NNN.md` — consistent in spec + B12.

No inconsistencies found.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-20-gtm-prd-factory-phase-1.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best fit: each task is self-contained (scaffolding / one template / one skill section / one validation check), so subagent-per-task gives clean isolation and lets us catch template-diversity problems early (in Sub-phase D).

**2. Inline Execution** — I execute tasks in this session using the executing-plans skill, batch execution with checkpoints for review. Faster turnaround but loads more context into this session.

**Which approach do you want?**
