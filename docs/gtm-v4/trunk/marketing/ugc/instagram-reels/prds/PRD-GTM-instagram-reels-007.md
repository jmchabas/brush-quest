---
id: PRD-GTM-instagram-reels-007
title: Substack cold pitch to 3 parenting writers — founder-story angle
parent_question: "Produce agent-executable PRDs to get 25–40 qualified parent installs in 14 days. This PRD owns the T2d Substack outreach experiment."
parent_node: trunk/marketing/ugc/instagram-reels
tier: 2
status: draft
owner_agent: outbound-comms-agent
budget:
  dollars: 0
  tokens: 80000
  agent_hours: 3
  jim_hours: 30   # 30 min one-time: approve 3 pitches in one batched window, then respond to any replies in-window
timeline:
  start: 2026-04-25   # Day 5 per Synth-final §7 sequencing
  checkpoints: [2026-04-28, 2026-05-02]
  end: 2026-05-05   # 10-day kill window per Synth-final §4 T2d
depends_on:
  - PRD-GTM-instagram-reels-001   # landing live + attribution working — pitches include a UTM'd link
blocks: []
experiments:
  - EXP-GTM-instagram-reels-t2d   # kill criterion: 0 of 3 respond in 10 days → kill
created: 2026-04-20
last_updated: 2026-04-20
---

## Goal

Send **3 personalized cold pitches** to 3 named parenting-newsletter writers by 2026-04-26, targeting a mention (paragraph or link) in their next 2 weeks of content. Kill at 10 days if 0 of 3 respond. Pass/fail signal is founder-story land, not install count — any install attribution is upside.

## Context brief

### Product state (2026-04-20)
- Same as PRD-006. Android LIVE on Play internal testing v1.0.0+17. Landing at `brushquest.app/rangers` with UTM capture. iOS soon.
- Public Play review expected to clear inside this sprint. Pitches should read as "just launched" not "still beta."

### Target persona (who / where / when)
Three specific writers, in descending priority order. Agent researches current contact channels before pitching — do NOT assume last-known addresses are current.

1. **Emily Oster — Parent Data** (https://parentdata.org). Data-driven parenting decisions. Loud on evidence-based routines (sleep, food, screen time). Fit: habit-formation angle, D7/retention math, "is gamified toothbrushing actually working or is it placebo." Preferred contact channel to verify: Parent Data contact form or listed substack email. She almost certainly does not reply personally; aim for the editorial team.
2. **Emily Cherkin — The Screentime Consultant** (https://www.thescreentimeconsultant.com). Anti-screen-addiction lane. Fit: "here's a screen-time use case that's 2 minutes twice a day and solves a real parenting problem — roast it." Counter-intuitive angle is the hook.
3. **Amy Wilson & Margaret Ables — What Fresh Hell Podcast/Newsletter** (https://www.whatfreshhellpodcast.com). "Laughing in the face of motherhood" tone. Fit: irreverent, parent-voice, meltdown-at-tooth-brushing is their native terrain. Founder-story / LLC-with-a-7yo-QA-lead is the hook.

Timing: pitch Saturday 2026-04-25 or Sunday 2026-04-26 evening (writers batch Monday morning). Avoid Friday afternoon.

### Constraints (immutable per Synth-final §8)
- BANNED words: "internal tester," "Google group," "alpha," "beta." Use "early access."
- COPPA-strict. No child name/face in any pitch. Founder story is about Jim + the problem, not about Oliver.
- Brand tone: warm, practical, slightly irreverent. Match the writer's voice in the opening line but don't mimic.
- No spam patterns: no "I know you're busy," no "I think your readers would love this" framing. Lead with a specific observation about one of their recent pieces.
- Each pitch must be unique — no templated opening.
- DO NOT mass-BCC or send the same email to all three. Each is a separate send.

### Prior synth-final decisions binding this PRD
- §4 T2d: kill criterion is 0 of 3 respond in 10 days → kill. No escalation, no second wave.
- §8.4: "early access" language rule.
- §8.5: Space Ranger aesthetic not banned here (this is parent-text content, not a Reel), but the "meltdown at bedtime" framing is the hook, not hero art.
- §8.9: Jim approves in one daily 60-min window. Agent drafts, Jim reviews 3 pitches together, agent sends.

### What's been tried / what happened
- Nothing. This is a cold lane with no prior relationship to any of the three writers.

## Inputs required

### Credentials / OAuth tokens
- Gmail MCP — Jim's Gmail (jim@anemosgp.com OR jmchabas@gmail.com — agent picks the one whose footer looks most founder-legit, probably jim@anemosgp.com since LLC-verified). Auth via `@claude_ai_Gmail`.
- No paid API keys required.

### Assets / files by path
- Landing: `https://brushquest.app/rangers?utm_source=substack&utm_medium=email&utm_campaign=writer_pitch_2026_04&utm_content={writer_slug}`
  - `writer_slug` values: `oster`, `cherkin`, `whatfreshhell`
- Founder one-pager (agent generates if not present at `_data/founder_one_pager.md`): 4 bullets — who Jim is, what Brush Quest is, one interesting data point (Oliver's retention, LLC-is-a-solo-founder-grind, COPPA-strict), one "here's what I'm curious if your readers would say" ask.
- Pitch drafts output: `_data/substack_pitches_2026_04_25.md` (3 drafts in one file for batched Jim review).
- Reply log: `_data/substack_reply_log.yaml`.
- Writer research notes: `_data/substack_writer_research.md` — for each writer, agent logs their 3 most recent posts + titles so the pitch opener is genuinely specific.

### Prior PRD outputs consumed
- PRD-001: landing + UTM capture. Pitches include the UTM'd link.

### Tools / MCPs
- `@claude_ai_Gmail` — create_draft, list_drafts (for verifying 3 drafts exist before send), send via draft-sent workflow (Jim approves → agent sends).
- `WebFetch` or `WebSearch` — research each writer's recent posts to seed the specific-observation opener. Do NOT rely on stale memory.
- `tg send` CLI — escalation pings.

## Outputs required

### Artifacts
1. **Writer research notes** — `_data/substack_writer_research.md`. For each of the 3 writers: outlet URL, verified contact channel (email, contact-form URL, or "no public channel — pitch via Substack reply"), 3 most recent piece titles + publish dates + one-sentence summary of each.
2. **3 pitch drafts** — `_data/substack_pitches_2026_04_25.md`. Each pitch:
   - Subject line (each unique, each ≤8 words)
   - Opening that references a specific recent piece of theirs (from research notes, not generic flattery)
   - Founder-story paragraph (Jim, solo, AnemosGP LLC, Android launched Apr 11, iOS 2 weeks out)
   - The counter-intuitive or interesting angle (habit math for Oster; counter-intuitive-screen-time for Cherkin; meltdown-lore for What Fresh Hell)
   - One specific ask (a paragraph, a link, or a "happy to send you a promo code for your listeners when Play review clears")
   - UTM'd landing link
   - Short, signed "Jim" + one-line LLC signature
   - ≤180 words total body
3. **3 Gmail drafts created** via `@claude_ai_Gmail__create_draft` — to be sent by Jim (one-click) or by agent on Jim's explicit approval.
4. **3 pitches sent** — confirmed by Gmail thread IDs logged in `_data/substack_reply_log.yaml`.
5. **Reply monitor** — agent checks `@claude_ai_Gmail__search_threads` daily in the 60-min window for replies to the 3 threads, logs to `_data/substack_reply_log.yaml` (columns: `writer`, `thread_id`, `reply_received_at`, `reply_type` ∈ {yes|maybe|no|bounce|silent}, `action_taken`).
6. **Day-10 kill-or-escalate decision** — written to `_data/t2d_day10_decision.md`:
   - 0 of 3 replied → "kill T2d, no second wave" and stop.
   - ≥1 replied positive → append to `_retro.md` as live follow-up; escalate to Jim in 60-min window for manual response.
7. **Day-14 retro entry** — T2d row in `_retro.md` with outcome + any attributed installs.

### Data
- `_data/substack_pitches_2026_04_25.md` (3 drafts)
- `_data/substack_reply_log.yaml`
- `_data/substack_writer_research.md`
- `_data/t2d_day10_decision.md`

### Locations
- All artifacts under `docs/gtm-v4/trunk/marketing/ugc/instagram-reels/_data/`.

## Acceptance criteria

- [ ] Writer research notes exist for all 3 writers with ≥3 recent piece titles each, ≤14 days old as of pitch date.
- [ ] 3 unique pitch drafts exist in `_data/substack_pitches_2026_04_25.md`. No two pitches share opening sentence, subject line, or core hook.
- [ ] Each pitch contains the correct per-writer UTM (`utm_content=oster|cherkin|whatfreshhell`).
- [ ] Banned-words grep gate: zero hits on `(internal tester|Google group|alpha|beta)` across all 3 drafts.
- [ ] COPPA check: no occurrence of Oliver's name or any other child name; founder-story is about Jim + the problem, not about any specific child.
- [ ] Jim approves all 3 drafts in a single 60-min batched window. (1 approval, not 3.)
- [ ] 3 Gmail drafts created; 3 Gmail sends confirmed with thread IDs logged.
- [ ] By Day 10 (2026-05-05): reply-log complete. Decision file written.
- [ ] If 0 of 3 replied → decision file says "kill" and no further work is done on this PRD.
- [ ] If ≥1 replied → Jim is escalated in his next 60-min window with the specific reply content + suggested response. Agent does NOT auto-reply on Jim's behalf to a real named human.
- [ ] T2d row appended to `_retro.md` by Day 14.

## Metrics

- **Primary (this PRD's own kill-gate):** number of replies from 3 pitches within 10 days. Target: ≥1. Zero = kill.
- **Secondary:** install attribution to `utm_source=substack` per PRD-001 Firestore query — upside only, not the gating metric.
- **Attribution window:** 14 days from pitch-send. If a writer publishes on Day 11 (just after kill-gate) and installs come Day 13, they count in retro.
- **Measurement system:**
  - Reply tracking → `_data/substack_reply_log.yaml` (agent writes via Gmail MCP sweep).
  - Install attribution → Firestore query per PRD-001.

## Tools the executor needs

- `@claude_ai_Gmail__create_draft` — 3 times, one per pitch.
- `@claude_ai_Gmail__search_threads` — daily during 10-day monitor window.
- `@claude_ai_Gmail__get_thread` — on each hit to extract reply content.
- `WebFetch` or `WebSearch` — writer research.
- Bash — grep-gate on banned words; UTM-string formatting.
- `tg send` — escalation.
- **Human-in-loop approval points:**
  1. Jim reviews all 3 pitches + research notes in one 60-min window on 2026-04-25.
  2. Jim clicks send on each Gmail draft (or explicitly authorizes agent to send, tracked in approval note).
  3. Jim personally responds to any reply — agent does not auto-reply.

## Escalation triggers

Agent pings Jim via `tg send` when:
- Any of the 3 pitch emails bounces (invalid address) → `tg send "T2d: pitch to <writer> bounced, contact channel invalid, need alternative"`.
- A writer replies with a "maybe, more info?" — escalate same day, don't let it cool → `tg send "T2d: <writer> replied positive, needs Jim response in 60-min window"`.
- A writer replies angry/flagging spam → `tg send "T2d: <writer> flagged spam, pause further pitches, apology thread?"`. Do NOT send remaining pitches until Jim decides.
- Day-10 kill-gate triggered → `tg send "T2d: 0/3 replied in 10 days, killing lane per Synth-final §4"`.
- Any factual error surfaced in a writer's reply (e.g. "but your app does X which my piece argues against") → `tg send "T2d: factual challenge from <writer>, Jim must respond"`.
- A reply comes in outside the 60-min window but is time-sensitive (<24h response window implied) → `tg send` immediately; this is an out-of-window-OK trigger per Synth-final §7 ("any real-named-human response that can't wait").

## Risks + mitigations

- **Risk:** Emily Oster doesn't read cold pitches; editorial team filters. → **Mitigation:** target the Parent Data editorial contact if published; mention the one specific data angle (D7 cohort / habit-math) that their team would forward.
- **Risk:** Pitches pattern-match "founder spam" and get auto-archived. → **Mitigation:** opener referencing a recent specific piece; plain-text not HTML; no images attached; Jim's LLC signature (real legal entity) in footer.
- **Risk:** A writer publishes critically (e.g. "another gamified-screen-time app") and traffic is negative. → **Mitigation:** the landing's copy is honest about what the app does; parents who click through a skeptical mention and still install are high-quality. Do NOT ask for retraction; do NOT reply publicly. Log and move on.
- **Risk:** COPPA or screen-time-ethics trap in founder story. → **Mitigation:** explicit banned-words grep + copy rule "app is 4 minutes of screen time per day, no ads, no purchase prompts to children, $9.99 one-time premium for parents." Stay on the facts.
- **Risk:** Zero replies and the kill-gate feels premature at Day 10. → **Mitigation:** Synth-final is frozen; 10 days is the commit. Kill is kill. Any "second wave" must come from a new synth-final pass, not this PRD.
- **Risk:** Agent makes up writer research (hallucinates recent post titles). → **Mitigation:** research notes require URL + publish date. Agent uses `WebFetch` live, does not cite from memory. If a URL 404s, agent drops that writer and flags to Jim; does not fabricate.

## Change log

- 2026-04-20 Created PRD-GTM-instagram-reels-007 from Synth-final §4 T2d and §8 binding decisions.
