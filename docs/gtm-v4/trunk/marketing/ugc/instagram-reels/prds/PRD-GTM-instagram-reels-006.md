---
id: PRD-GTM-instagram-reels-006
title: Warm-network sweep — Buttondown blast + PTA 3-line text from Jim's phone
parent_question: "Produce agent-executable PRDs to get 25–40 qualified parent installs in 14 days. This PRD owns the T1d warm-network lane."
parent_node: trunk/marketing/ugc/instagram-reels
tier: 1
status: draft
owner_agent: outbound-comms-agent
budget:
  dollars: 0
  tokens: 120000
  agent_hours: 2
  jim_hours: 120   # 2 hrs: 1 hr drafting review + 1 hr physically texting PTA parents + sending Buttondown
timeline:
  start: 2026-04-23   # Day 3 of the 14-day sprint (fires after T1c UTM round-trip passes)
  checkpoints: [2026-04-25, 2026-04-30]
  end: 2026-05-07
depends_on:
  - PRD-GTM-instagram-reels-001   # landing page live, UTM capture working, CSV pipeline green
  - PRD-GTM-instagram-reels-005   # burner-phone UTM round-trip test passed (the Day-3 go/no-go gate)
blocks: []
experiments: []
created: 2026-04-20
last_updated: 2026-04-20
---

## Goal

Drive **8–18 qualified parent installs** (per the Firestore `qualified_install` query in PRD-001) in 14 days by (a) sending one Buttondown email to the existing parent list with a brushquest.app/rangers?utm_source=buttondown link, and (b) Jim sending a 3-line plain-text SMS from his personal phone to ~15–25 2nd-grade-class parents at Oliver's school, again with a unique UTM parameter.

## Context brief

### Product state (2026-04-20)
- Brush Quest is LIVE on Google Play internal testing since 2026-04-11 (v1.0.0+17). Public review submitted; clearing expected inside this sprint. When it clears, landing flips from "early access" to public install via a config flag owned by PRD-001.
- Landing destination: `https://brushquest.app/rangers` (owned by PRD-001). Captures email → writes `parents/{parent_id}` in Firestore → nightly CSV export to Jim's inbox for Play Console internal-tester upload.
- iOS: Apple Business clears ~2026-04-24; `/rangers` already has an "iOS coming soon — join waitlist" capture.

### Target persona (who / where / when)
- **Buttondown list** (~existing size: TBD by agent from Buttondown dashboard at send time). These are parents who opted into brushquest.app updates. Warmest audience available. Expect 20–40% open rate.
- **PTA list** = parents of kids in Oliver's 2nd-grade class. Jim has most in his phone contacts already. Send via native SMS/iMessage from his own phone. This is explicitly NOT a newsletter, NOT a group MMS — individual sends so parents don't see each other.
- Time-of-day for Buttondown: Tuesday or Wednesday, 9–10am local. Highest parent open rates per general email norms.
- Time-of-day for PTA text: Weekday 7–8pm (after dinner, before bedtime). NOT during the school day.

### Constraints (immutable per Synth-final §8)
- **BANNED words in all parent-facing copy:** "internal tester," "Google group," "alpha," "beta." Use "early access."
- COPPA-strict — no child face/name in any copy that's forwardable. No "Oliver's app" in the email; Jim is a dad building something, his kid tested it.
- Brand tone: warm, practical, slightly irreverent about "brushing is miserable." Never patronizing. Never "screen time is bad."
- PTA text is 3 lines MAX. Not a pitch. Plain-text-from-Jim, per E2 §5.3 and Synth-final §8.7.
- Voice: Jim's real voice, not marketing voice. Kids-names-are-OK in a private text to known parents, but NEVER in the Buttondown email (public-ish artifact, COPPA trap).
- iOS waitlist CTA must be present alongside the Android install CTA on the landing; email copy should say "Android now, iOS in a couple weeks" honestly.

### Prior synth-final decisions binding this PRD
- Per §8.1: target band is 25–40 qualified installs node-wide; T1d's slice is 8–18.
- Per §8.2: "qualified install" = `parent_email_captured=true AND play_tester_enrolled=true AND first_brush_timestamp IS NOT NULL within 72h`.
- Per §8.3: this PRD cannot fire until PRD-001 + PRD-005 are green.
- Per §8.7: PTA = plain-text SMS from Jim's phone. NOT Buttondown with a "forward this to a friend" CTA.
- Per §8.9: Jim approves in the daily 60-min batched review window. No out-of-window pings unless an escalation trigger fires.
- Per §7 sequencing: T1d fires Day 3 (2026-04-23) after T1c green.

### What's been tried / what happened
- Buttondown list exists; prior sends recorded but no parent-install attribution wired (landing at `/rangers` didn't exist). This send is the first with UTM round-trip.
- Jim has previously texted 1–2 close friends about Brush Quest; they installed but were never tracked. Those convert at ~100% when you have direct relationship — the PTA cohort is the scalable extension.

## Inputs required

### Credentials / OAuth tokens
- `buttondown-api-key` — Buttondown API key, stored in 1Password / env as `BUTTONDOWN_API_KEY`. Agent uses to send email via Buttondown send endpoint.
- No PTA-text credential required; Jim sends physically from his iPhone.

### Assets / files by path
- Landing URL (with UTM placeholders): `https://brushquest.app/rangers?utm_source={source}&utm_medium={medium}&utm_campaign=warm_sweep_2026_04`
- UTM matrix the agent must generate + deliver to Jim:
  - Buttondown link: `utm_source=buttondown&utm_medium=email&utm_campaign=warm_sweep_2026_04`
  - PTA text link: `utm_source=pta&utm_medium=sms&utm_campaign=warm_sweep_2026_04`
- Email draft output path: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_data/buttondown_draft_2026_04_23.md`
- PTA text template output path: `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_data/pta_text_template_2026_04_23.md`
- Buttondown dashboard: https://buttondown.email/emails (Jim approves send)
- Class-parent phone contact list: Jim's iPhone Contacts (no export required — Jim reads + sends manually). Agent generates the copy template only.

### Prior PRD outputs consumed
- PRD-001 output: live landing at `/rangers` with UTM capture writing to Firestore `parents/{parent_id}`. Without this, attribution is dead.
- PRD-005 output: burner-phone round-trip test log proving UTM → email capture → Firestore row joinable on `parent_id`. Must be green before this PRD fires.

### Tools / MCPs
- `@claude_ai_Gmail` — only if agent needs to forward draft to Jim's inbox for approval. Otherwise bypass.
- Buttondown HTTP API — `POST /v1/emails` (draft) + `POST /v1/emails/{id}/send` (send, on Jim approval).
- `tg send` CLI — for escalation pings.
- No Instagram / Reddit / creator MCPs required.

## Outputs required

### Artifacts
1. **Buttondown email draft** — saved to `_data/buttondown_draft_2026_04_23.md`. Subject line, preview text, body (<200 words), one CTA button to `/rangers?utm_source=buttondown...`. iOS waitlist line. No "internal tester" language. No child's name.
2. **PTA text template** — saved to `_data/pta_text_template_2026_04_23.md`. 3 lines. Example shape: "Hey [Parent Name] — Jim here, Oliver's dad. I built a toothbrushing game for kids that's actually working with him + wanted to share it with the class. Android-only for now, iOS in a couple weeks, link's here: brushquest.app/rangers?utm_source=pta&utm_medium=sms&utm_campaign=warm_sweep_2026_04". One personalization placeholder `[Parent Name]`.
3. **Buttondown email — sent** (Jim clicks send in his daily 60-min window).
4. **PTA text — sent** by Jim, count logged by Jim in `_data/pta_send_log_2026_04_23.md` (columns: `parent_first_name`, `sent_at`, `response_received` [optional]).
5. **Day-7 attribution snapshot** — agent queries Firestore for installs with `utm_source IN ('buttondown','pta')`, writes to `_data/t1d_day7_attribution.yaml`.
6. **Day-14 retro entry** — agent appends T1d row to `_retro.md` with final qualified-install count + CAC.

### Data
- `_data/t1d_day7_attribution.yaml` — counts by UTM source, conversion funnel (clicks → email captures → tester-CSV-rows → first-brush).
- `_data/t1d_day14_attribution.yaml` — same, final.

### Locations
- All artifacts under `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_data/`.
- Email send is external (Buttondown). Text is external (Jim's phone).

## Acceptance criteria

- [ ] Buttondown draft written to `_data/buttondown_draft_2026_04_23.md` and reviewed by Jim in the daily 60-min window.
- [ ] PTA 3-line text template written to `_data/pta_text_template_2026_04_23.md` — EXACTLY 3 lines, uses `[Parent Name]` placeholder, contains the `?utm_source=pta&utm_medium=sms...` UTM.
- [ ] Zero banned words in final copy: grep the draft for `(internal tester|Google group|alpha|beta)` case-insensitive → must return zero.
- [ ] Both drafts include the iOS waitlist line or an honest "iOS in a couple weeks" acknowledgment.
- [ ] Buttondown email sent from Jim's Buttondown account (Jim presses send; agent confirms send status via API).
- [ ] Jim confirms via `_data/pta_send_log_2026_04_23.md` that PTA texts were sent to ≥10 distinct class-parent numbers.
- [ ] Day-7 Firestore attribution query returns `buttondown` AND `pta` rows (both sources reach Firestore, not just one).
- [ ] Day-14 qualified-install count for T1d ≥5 (honest floor; 8–18 mid-case per Synth-final §3 T1d).
- [ ] No parent responds reporting confusion, COPPA flag, or spam complaint. Any single such response triggers immediate escalation per §Escalation.
- [ ] T1d row appended to `_retro.md` with final CAC (should be ~$0 since no paid spend).

## Metrics

- **Primary:** qualified installs attributed to `utm_source IN ('buttondown','pta')` per the PRD-001 Firestore query, measured at Day 7 and Day 14 of sprint.
- **Secondary:** Buttondown open rate, click-through rate; PTA reply rate (informal, Jim logs); email-captures (pre-install funnel step).
- **Attribution window:** 7 days from click. A parent who clicks on Day 3 and first-brushes on Day 10 counts; one who first-brushes on Day 11 does not.
- **Measurement system:** Firestore `parents/` + `testers/` + brush-history collection per PRD-001 schema. Agent writes Day-7 + Day-14 snapshots to `_data/t1d_day7_attribution.yaml` + `_data/t1d_day14_attribution.yaml`. These are the single source of truth; Buttondown dashboard numbers are secondary signals only.

## Tools the executor needs

- Buttondown HTTP API (draft + send). Auth: bearer token `BUTTONDOWN_API_KEY`.
- Firestore read access (service account key owned by PRD-001; agent consumes).
- Bash for UTM-string formatting + grep-gate on banned words.
- `@claude_ai_Gmail` (optional) for emailing Jim a one-pager approval summary.
- `tg send` CLI for escalation pings.
- **Human-in-loop approval points:**
  1. Jim reviews both drafts in one daily 60-min window (per Synth-final §8.9) before anything goes out. One approval covers both.
  2. Jim physically sends the PTA text from his iPhone (non-delegable).
  3. Jim clicks send on the Buttondown draft (non-delegable per financial-safety-equivalent: sending to a real named-human list).

## Escalation triggers

Agent pauses work and pings Jim via `tg send` when:
- Buttondown API returns non-2xx on draft creation or send → `tg send "T1d: Buttondown API error <status>, draft NOT sent"`.
- Agent detects any banned word (`internal tester`, `Google group`, `alpha`, `beta`) in Jim's reviewed copy before send → pause and re-draft, do not send until clean.
- Any parent replies to PTA text with concern (privacy, child data, "is this spam") → `tg send "T1d: PTA parent [name-redacted] flagged privacy concern, pausing further sends"` — Jim decides how to respond.
- Day-7 Firestore attribution query returns ZERO T1d-attributed rows (both `buttondown` and `pta` UTM sources empty) → `tg send "T1d: Day-7 zero attributed installs, possible tracking break, need debug"`.
- Any COPPA/legal flag — any mention of child's name, face, school name appearing in copy — pause immediately, `tg send`.
- Jim-hours actual exceeds 3 hrs total for this PRD vs. 2 budgeted → `tg send "T1d: over Jim-hours budget, consider culling PTA personalization"`.

## Risks + mitigations

- **Risk:** Buttondown list is small (<50 subscribers) so even a great open rate yields <5 clicks. → **Mitigation:** PTA channel is the real volume lane; Buttondown is free upside. Accept this. If Buttondown list <25, note in retro that the warm-network thesis rests on PTA, not Buttondown.
- **Risk:** PTA parents feel "pitched" and the Jim<>class-parent relationship frays. → **Mitigation:** 3-line plain text from personal number, no "forward this to your friends" ask, no emoji spam, no link-preview unfurl weirdness. Personalize the `[Parent Name]` slot. Send at 7–8pm weeknight, not weekend.
- **Risk:** PTA text lacks the landing UTM and attribution breaks. → **Mitigation:** Template has UTM baked in; Jim is told explicitly "do not remove the ?utm_source=pta... portion when copying." Agent writes note at top of template file in bold.
- **Risk:** iOS line confuses parents on iPhones who can't install. → **Mitigation:** Copy reads "Android now, iOS in a couple weeks, join the iPhone waitlist here" — the landing handles the iOS branch.
- **Risk:** Buttondown send marks the sender as spam, future email trust drops. → **Mitigation:** single send, no A/B test, one clean CTA, no image-heavy HTML. Use Buttondown's default plain template.
- **Risk:** A parent forwards the email to a non-parent audience (e.g. a group chat) and exposes unreviewed COPPA copy. → **Mitigation:** banned-word grep gate + no child-name + explicit review pass against CLAUDE.md's landing page copy rules (parent CUJ, factual, visual).

## Change log

- 2026-04-20 Created PRD-GTM-instagram-reels-006 from Synth-final §3 T1d and §8 binding decisions.
