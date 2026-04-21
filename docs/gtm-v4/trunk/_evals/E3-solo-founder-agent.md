# E3 — Solo-founder Executor-Agent Evaluation

**Evaluating:** `trunk/_synth-v1.md`
**Date:** 2026-04-21
**Stance:** strengthen, test, de-prioritize — don't kill routes.

---

## 1. Executability score

### Tier-1 pillars

**Pillar 1 — Retention instrumentation + ASO (Week 1).**
- Tool readiness: HIGH. PostHog / Amplitude free tier + Firebase + Play Console already wired. UTM + Play referrer = `play_install_referrer` lib, shippable.
- Jim load: 8–12 hrs that week. **Realistic only if Cycle 16 defers UX work.** Jim just shipped Cycle 15; Cycle 16 is already queued against deferred T3s + Oliver v13 retest. Two parallel tracks of eng work in one week = slip risk.
- Loop: agent-autonomous for code, PRs, dashboard scaffolding. Jim approves merge + tests on device.
- Failure modes: Play referrer attribution on iOS is non-trivial (SKAdNetwork / AppsFlyer-adjacent). Agent will ping Jim when it hits Apple attribution edge cases.
- **Score: 8/10 shippable in Week 1 if Cycle 16 slips one week.** Recommend making that call explicit.

**Pillar 2 — Pediatric-dentist partnerships.**
- Tool readiness: MEDIUM. Scraping (Playwright MCP ✓), Gmail drafts (✓), Canva MCP (✓ for flyer design), print-on-demand (no MCP — human checkout step). No CRM MCP — Gmail labels become CRM.
- Jim load: ~6 hrs/wk as projected **is optimistic**. First-call / relationship close on a dentist is not agent-automatable — agent drafts outreach, but a dentist saying "yes, drop 20 flyers" requires a phone call or in-person drop. This is the pillar most bottlenecked on human trust-building.
- Loop: agent runs list-building + first-touch emails autonomously. Every reply loops through Jim. Conversion step = phone/in-person.
- Failure modes: agent will draft dozens of emails, get 5% reply rate, and queue Jim for 10 phone calls he doesn't have time for. Pipeline stalls at "interested but not signed."
- **Score: 6/10.** Real ceiling ~3 practices signed by Day 60, not 5. Adjust volume projection to 120–250 WAK, not 200–400.

**Pillar 3 — Earned media + Editor's Choice + CSM.**
- Tool readiness: MEDIUM. Gmail drafts ✓, WebSearch/WebFetch ✓ for journalist discovery, Canva ✓ for press-kit. **Editor's Choice nomination is not a form — it's a relationship with a Play BD rep.** Not agent-accessible. CSM submission is a web form (Playwright-runnable).
- Jim load: 2–3 hrs/wk understated. Press replies arrive on a journalist's timeline; Jim has to be on a call within 48h or the pitch dies. Expect 4–6 hrs/wk in burst weeks.
- Loop: list-build + pitch drafting agent-autonomous. Replies + interviews = human.
- Failure modes: 0 Editor's Choice traction (no BD relationship); CSM listing lives but drives fewer installs than projected; 1 of 10 press pitches lands and it's a long-tail blog.
- **Score: 6/10 for earned media, 3/10 for Editor's Choice.** Split them.

**Pillar 4 — Substack / newsletter sponsorships.**
- Tool readiness: HIGH. Sponsor discovery via WebSearch + Beehiiv ad-directory, outreach via Gmail, payment via Mercury + Stripe — all scriptable. No Buttondown API MCP yet (gap), but manual UTM routing works.
- Jim load: 1–2 hrs/wk realistic.
- Loop: nearly fully agent-autonomous through to sponsorship booking. Jim approves spend (>$100 trigger).
- Failure modes: 2–4 placements is ambitious; parenting Beehiiv inventory is thin and often books 60–90 days out. Expect 1–2 placements in 90 days, not 4.
- **Score: 8/10.** Most agent-runnable of the four.

### Tier-2 experiments

| | Tool readiness | Jim hrs/wk | Autonomy | Notes |
|---|---|---|---|---|
| T2-A Cavity Monster song | LOW — **no TikTok API MCP** for posting/metrics. Fiverr checkout = human. Creative-gen OK (ElevenLabs music ✓, ai-image-gen ✓). | 1–2 | Low; every post is manual | Platform gap is binding. |
| T2-B Cross-promo outreach | HIGH — Gmail ✓ | <1 | High | Cheapest agent-runnable T2. |
| T2-C Reddit Concierge | LOW — **no Reddit API MCP**. Chrome MCP works but slow; ToS-fragile. | 4–6 (cap) | Low | Jim-time-binding. Keep capped. |
| T2-D Public metrics page / Beehiiv | HIGH — builds on P1 | 1 | High | |
| T2-E Micro-creator gifting | MEDIUM — Gmail ✓, but no Creator Marketplace MCP, discovery manual | 2 | Medium | Works as manual outreach. |
| T2-F Local FB mom-groups | LOW — **no Facebook Groups API**. Chrome MCP + Jim's account = ToS risk. | 1 | Low | Human-trust-gated. |

---

## 2. Tool gaps (pre-requisite PRDs)

Blocking or partially blocking:
1. **TikTok posting + analytics MCP** — blocks T2-A signal measurement. Without it, "5K plays in 72h" requires Jim or a hired account to log in daily.
2. **Reddit API MCP** — blocks T2-C scaling past Jim's 6-hr cap.
3. **Instagram/Meta Graph API MCP** — blocks any future Reels promotion from Reels-sibling loop.
4. **Buttondown API MCP** — partial block on Pillar 4 attribution (UTM → subscriber join).
5. **Play Console API MCP** — manual console-clicks for Editor's Choice nom and press-kit submission. Soft block on Pillar 3.
6. **Creator Marketplace / Aspire MCP** — blocks any scale-up of T2-E beyond 20 nano-creators.
7. **Simple CRM MCP** (pipedrive/attio) — Gmail labels scale poorly past ~30 dentist practices in Pillar 2.

Not blocking but nice: AppsFlyer/Adjust MCP for deeper attribution than UTM+referrer.

---

## 3. Executor-agent shape

- **Pillar 1:** existing Claude Code generalist. Cyclepro handles it — treat as Cycle 16.5.
- **Pillar 2:** new specialized **`dentist-outreach-agent`**. Tools: Playwright (scraping), Gmail (drafts), Canva (kits), knowledge-graph (practice CRM). Escalates on any reply requiring phone.
- **Pillar 3:** new **`press-pitcher-agent`**, reuses dentist-outreach spine. Escalates on journalist reply inside 4 hours (Jim phone).
- **Pillar 4:** new **`newsletter-sponsor-agent`**. Gmail + WebSearch + Mercury. Escalates only on >$100 spend approval.
- **Tier-2:** one **`experiment-runner` generalist** with kill-clock enforcement; do not build 6 specialists.

Escalation rule for all: fire `tg send` on reply, on kill-clock hit, and on every Jim-approval gate.

---

## 4. Strengthen

- **Make Week 1 a hard Cycle 16 replacement, not parallel.** Telegram Jim today asking for the call; don't assume he knows.
- **Split Pillar 3 into 3a (earned media, score 6) and 3b (Editor's Choice, score 3).** 3b is Tier-3 until a Play BD contact exists.
- **Lower Pillar 2 volume projection to 120–250 WAK** and put a Day-45 kill gate at <2 practices signed.
- **Every PRD must name (a) the MCP it uses, (b) the Jim-escalation trigger, (c) the kill clock.** Current Synth-1 is implicit on these.
- **Add a Week-1 tool-gap PRD** that ships the CRM + attribution glue (items 4, 7 in §2) before Week 2 outreach begins.

## 5. De-prioritize to Tier-3

- **Pillar 3b — Play Editor's Choice nomination.** No BD relationship, no nomination form. Trigger to promote: a Play BD contact made (via Pillar 3a press hit or direct intro). Keep CSM submission in 3a; it *is* agent-runnable.
- **T2-A Cavity Monster song** — demote to Tier-3 until TikTok MCP ships OR Jim confirms he'll run the account 15 min/day. Hold $150.
- **T2-F Local FB groups** — demote. ToS risk + no API + deep human-trust curve. Revisit when a community-liaison hire happens.

## 6. Verdict

Plan is **directionally right and ~70% executable today.** The agent-plus-founder pair can realistically ship Pillar 1 + Pillar 4 + T2-B + T2-D inside Day 30 — that alone is a credible 200–400 WAK pace. Pillar 2 will produce 1–3 signed practices by Day 30, not 5 — still a real Tier-1 signal. Pillar 3a (earned media) is a Day-45–60 story, not Day-30. The stretch from "real portfolio" to "hit 1,000 WAK by Day 90" depends on (a) Jim accepting Cycle 16 slips to make Week 1 real, (b) Pillar 2 dentist conversion hitting the middle of its band, and (c) one newsletter placement landing inside Day 45. If any two of those slip, Day-90 lands at 400–600 WAK with clean retention data — which per Q6 in §9 of Synth-1 is arguably a better outcome than 1,000 WAK blind.
