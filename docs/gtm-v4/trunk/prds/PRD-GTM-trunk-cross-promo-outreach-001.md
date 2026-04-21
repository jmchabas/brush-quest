---
id: PRD-GTM-trunk-cross-promo-outreach-001
title: T2-D — Sleep / bedtime-app cross-promo cold outreach (zero cash, 14-day kill clock)
parent_question: "Can a small set of bedtime/routine kids-app founders (Moshi Sleep, Slumberkins, Hatch, Yoto content partners) be converted into a low-effort cross-promo swap — audience skew right, zero paid spend?"
parent_node: trunk
tier: 2
status: draft
owner_agent: experiment-runner
budget:
  dollars: 0
  tokens: 250000
  agent_hours: 10
  jim_hours: 2
timeline:
  start: 2026-04-29
  checkpoints: [2026-05-06]
  end: 2026-05-13
depends_on:
  - PRD-GTM-trunk-instrumentation-aso-001.md
blocks: []
experiments: [EXP-GTM-trunk-t2d-crosspromo-001]
created: 2026-04-21
last_updated: 2026-04-21
---

## Goal

By 2026-05-13 (14 days after Pillar 1 ships), 10 cold outreach emails sent
to bedtime/routine kids-app founders; ≥1 "let's talk" reply received, OR
the experiment is killed and findings logged. Zero dollars spent.

## Context brief

### Product state
- Brush Quest v1.0.0+17 LIVE on Play internal testing; public Play review
  clearing in window. iOS TestFlight 2–4 weeks out. Pillar 1 instrumentation
  ships Week 1 (prerequisite — this PRD starts Week 2).
- Voice: Buddy (George). Monetization: Free + Brush Quest+ $9.99 one-time +
  star packs. Locked.
- `brushquest.app/rangers` bridge page is the binding destination URL
  (synth-final §8 #14).

### Target persona (recipients)
Founders / product leads at kids-focused routine apps:
- **Moshi Sleep** (moshikids.com) — sleep stories, mindfulness for kids.
- **Slumberkins** (slumberkins.com) — emotional-learning creatures + app.
- **Hatch** (hatch.co) — Rest+, sound machine, routines. Parent product.
- **Yoto** (yotoplay.com) — audio player; content partnerships team.
- **Khan Academy Kids** (khankids.org) — long shot but aligned.
- **Lingokids** (lingokids.com) — playful learning 2–8.
- **Sago Mini** — play-based apps 2–5 (lower age skew but brand-adjacent).
- **Tinybop** — curious kids 4–10. Historically receptive to indie devs.
- **Homer Learning** (learnwithhomer.com) — early-reading.
- **Elly Education / Wonder Weekly** — dental-adjacent content partners.

(Agent may substitute 1–2 based on web research. Final list locked after
Jim approves.)

Pitch angle: "Brush Quest handles the 2 min of brushing in a kid's bedtime
routine. Your app handles the sleep part. Cross-promo makes both our
products feel more complete."

### Constraints
- COPPA strict — no child PII in any outbound email; no screenshots with
  real kids' faces.
- Brand tone: warm, practical, first-name from Jim, parent-to-parent feel.
  NOT "solo founder + AI agents" angle (synth-final §8 #19 — reserved for
  tech press, not product outreach).
- Zero cash. Agent-hrs + 2 Jim-hrs total.
- Each email uses `utm_source=crosspromo_{company_slug}_{contact_slug}` in
  any embedded links (synth-final §8 #15).

### Prior decisions from `_synth-final.md` (binding)
- `_synth-final.md` §4 T2-D: "Cold-email 10 bedtime/routine app founders
  (Moshi Sleep, Slumberkins, Hatch, Yoto content partners). Zero cash;
  Jim's time only. Kill: <1 'let's talk' reply in 14 days. Promote: ≥2 =
  pursue as T1 child loop."
- Synth-final §4 analyzer escalation rule: `experiment-runner` fires
  `tg send` on kill-clock hit, any Jim-approval gate (>$50 spend or any
  phone call), and promote-trigger hit.

### What's been tried
- None specifically. Brush Quest has no prior cross-promo outreach.
- Landing-page email capture is live at brushquest.app (Buttondown).

## Inputs required

- Gmail access for jim@anemosgp.com (agent drafts; Jim sends from own
  account for deliverability).
- Contact research: founder emails via WebSearch + Apollo.io free tier /
  Hunter.io free tier if needed (zero-cash).
- Template email + 2 variants (one warm/personal, one mutual-exchange
  framing).
- `brushquest.app/rangers` bridge page (from PRD-01 `/rangers` scaffolding).
- Pillar 1 attribution must be live so any click can be measured.
- Tool: Gmail MCP (drafts + thread management).
- Tool: WebSearch (contact research).
- Tool: `tg send` (escalation).

## Outputs required

- 10 personalized cold-outreach email drafts in Gmail (jim@anemosgp.com
  drafts folder).
- `trunk/_data/t2d_outreach_log.yaml` with:
  - `recipient_name`, `recipient_company`, `recipient_email`,
  - `sent_at`, `utm_source`, `email_variant` (A/B label),
  - `reply_received` (bool), `reply_sentiment`
    (positive/neutral/negative/none), `reply_at`,
  - `next_action` (call / dead / nurture).
- Post-run analysis: `trunk/prds/_t2d_postmortem.md` (outcome + what to do
  next — promote / kill / extend).
- Experiment record: `EXP-GTM-trunk-t2d-crosspromo-001.md` closed with
  winner-variant call (or NO_WINNER).

## Acceptance criteria

- [ ] 10 personalized cold emails drafted in Gmail (Jim approves batch, then
      agent or Jim sends — approval is ONE-TIME batch approval, not
      per-email).
- [ ] Each email uses unique `utm_source=crosspromo_{company}_{contact}`.
- [ ] Outreach log populated at `trunk/_data/t2d_outreach_log.yaml`.
- [ ] 14-day kill clock ends on 2026-05-13 — agent sends `tg send` with
      outcome regardless.
- [ ] Kill criterion: if <1 "let's talk" reply by Day 14 → experiment
      killed, postmortem written, budget not extended.
- [ ] Promote criterion: if ≥2 "let's talk" replies → `tg send` to Jim +
      postmortem proposes T1 child loop charter.
- [ ] No COPPA, brand-tone, or platform (Gmail deliverability) violations.
- [ ] Postmortem doc written at `trunk/prds/_t2d_postmortem.md`.

## Metrics

- **Primary:** count of "let's talk" / "interested" replies within 14 days.
  Kill <1. Promote ≥2.
- **Secondary:**
  - Reply rate (replies / sent).
  - Positive sentiment rate.
  - Any click-throughs to `brushquest.app/rangers` via UTM.
- **Attribution window:** 14 days from send date.
- **Measurement system:** Gmail thread state + PostHog/Amplitude UTM
  (built in PRD-01) + `trunk/_data/t2d_outreach_log.yaml`.

## Tools the executor needs

- MCP: `mcp__claude_ai_Gmail__*` (drafts, threads, labels)
- Web: WebSearch for contact research
- Bash: minor (yaml log generation)
- Human-in-loop:
  1. Jim approves list of 10 recipients before outreach (one-time).
  2. Jim approves batch of drafts once (one-time, not per-email).
  3. Jim sends from his own Gmail (agent creates draft; Jim clicks send).

## Escalation triggers

Executor pauses and `tg send`s Jim when:
- Kill-clock hits on Day 14 (send outcome regardless — kill, promote, or
  extend-proposal).
- Promote trigger hits (≥2 "let's talk" replies) BEFORE Day 14 — escalate
  immediately to propose T1 child loop.
- Any reply proposes a phone call — agent does NOT schedule; pings Jim.
- Any reply mentions paid sponsorship / revenue share — Jim approval gate.
- Any platform / deliverability flag (spam complaint, bounce > 20%,
  Google Workspace warning) — pause and ping.
- Agent-hours ≥ 8 (80% of 10-hr ceiling).

## Risks + mitigations

- **Risk:** cold-email response rate is 3–10%; 10 emails may yield 0
  replies by chance. → **Mitigation:** kill clock is honest; if 0 replies
  at 14d, log and move on. Do not scale.
- **Risk:** founders ignore agent-drafted copy as "AI slop." →
  **Mitigation:** 2 variants, one warm/personal; Jim reviews + lightly
  edits before send; send from jim@anemosgp.com (not a burner).
- **Risk:** a reply leads to a multi-hour call request. → **Mitigation:**
  escalation trigger pauses agent; Jim decides scheduling.
- **Risk:** cross-promo deal needs legal paperwork (data-sharing, COPPA).
  → **Mitigation:** any ask beyond an email reply is Jim-gated; T1 child
  loop (if promoted) scopes that work.
- **Risk:** founder replies with "cool idea, but we're not doing partners
  right now" — looks like a promote but isn't. → **Mitigation:**
  `reply_sentiment` field distinguishes genuine interest ("let's talk /
  let me introduce you / we've done these") from polite-deflect.

## Change log

- 2026-04-21 Created PRD-GTM-trunk-cross-promo-outreach-001 from
  `_synth-final.md` §4 T2-D. All 6 gate criteria hold at trunk freeze:
  (1) measurable goal, (2) inputs available, (3) outputs defined,
  (4) acceptance criteria binary, (5) escalation + budget named,
  (6) no blocking unknowns (recipient list is agent-researchable).
