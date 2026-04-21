# Execution Plan — PRD-GTM-instagram-reels-006

**PRD:** Warm-network sweep — Buttondown blast + PTA 3-line text from Jim's phone
**Executor agent:** instagram-executor-agent (Phase 1 smoke test)
**Plan date:** 2026-04-21
**PRD start date:** 2026-04-23 (Day 3 of 14-day sprint)
**PRD end date:** 2026-05-07

> **Phase 1 scope reminder:** This plan is a READ → PLAN → STOP exercise.
> No emails are sent, no texts go out, no Firestore queries run. The sole
> deliverable of Phase 1 is this document. Execution pauses until Jim
> approves the plan in a future loop.

---

## 1. Context loaded (startup protocol complete)

| File | Purpose | Result |
|---|---|---|
| `prds/PRD-GTM-instagram-reels-006.md` | The PRD to execute | Read |
| `instagram-reels/_synth-final.md` | Frozen node-level decisions | Read — binds §8 rules |
| `marketing/ugc/_synth-final.md` | Ancestor | DOES NOT EXIST — noted |
| `marketing/_synth-final.md` | Ancestor | DOES NOT EXIST — noted |
| `trunk/_synth-final.md` | Ancestor | DOES NOT EXIST — noted |
| `gtm-v4/00-master-brief.md` | Product + business state | Read |
| `gtm-v4/02-decisions-log.md` | Cross-node decisions | Read |

The tree above `instagram-reels/` is empty of synth-finals because this is the
first node under the `gtm-v4` factory to produce a frozen plan. Inheritance
stops at the instagram-reels `_synth-final.md`, which itself references
master-brief + decisions-log. No context gaps from missing ancestors.

---

## 2. Understood goal, metric, and window

**Goal.** Drive **8–18 qualified parent installs** in 14 days via two warm
channels: (a) one Buttondown email to the existing list with UTM-tagged
`/rangers` link, and (b) Jim personally texting ~15–25 Oliver's-2nd-grade-class
parents a 3-line SMS with a separately-UTM-tagged link.

**Metric (deterministic, from Synth-final §8.2 & PRD-001 schema).**
`qualified_install = parent_email_captured=true AND play_tester_enrolled=true
AND first_brush_timestamp IS NOT NULL within 72h`. Measured from Firestore
`parents/` + `testers/` + brush-history collection. Day-7 and Day-14
snapshots written to `_data/t1d_day7_attribution.yaml` and
`_data/t1d_day14_attribution.yaml`.

**Window.** 2026-04-23 → 2026-05-07 (14 days). Attribution window = 7 days
from click. Fires only after PRD-001 (landing live) AND PRD-005 (burner-phone
UTM round-trip green) both pass — Synth-final §8.3 gate is binding.

**Acceptance summary.** 9 checkbox criteria in PRD §Acceptance. The binding
ones: (1) PTA template is EXACTLY 3 lines with `[Parent Name]` slot and the
`utm_source=pta&utm_medium=sms` UTM; (2) banned-word grep on both drafts
returns zero hits; (3) Jim logs ≥10 distinct PTA sends in the send-log; (4)
Day-14 qualified-install floor ≥5; (5) no COPPA/spam complaint response from
any parent (single such response = immediate `tg send` escalation).

---

## 3. Day-by-day execution sketch

Sprint Day 0 = 2026-04-21 (today, plan-write day). PRD-006 start = Sprint Day 3.

### Day 0 (2026-04-21) — this plan
- Agent produces this plan file. STOP. (Phase 1 boundary.)

### Day 1 (2026-04-22) — pre-flight, still paused
- Wait for PRD-001 + PRD-005 green signals. Those are prerequisites per
  §depends_on. No executor action unless gate fires.

### Day 2 (2026-04-22 EOD) — go/no-go read
- If PRD-005 burner-phone round-trip log shows UTM → email capture →
  Firestore row joinable on `parent_id`, flip PRD-006 status to `ready`.
- If not green, pause. Do NOT draft anything until attribution is proven —
  drafting without attribution risks Jim sending real email with a broken
  link.

### Day 3 (2026-04-23) — drafting day (agent autonomous)
- **Morning (agent-time, ~90 min):**
  - Generate the two UTM strings:
    - Buttondown: `https://brushquest.app/rangers?utm_source=buttondown&utm_medium=email&utm_campaign=warm_sweep_2026_04`
    - PTA: `https://brushquest.app/rangers?utm_source=pta&utm_medium=sms&utm_campaign=warm_sweep_2026_04`
  - Draft Buttondown email → `_data/buttondown_draft_2026_04_23.md`.
    - Subject (one line, <50 char)
    - Preview text (one line)
    - Body <200 words, Jim's real voice (per Synth-final §8.4), warm +
      slightly irreverent (per master-brief brand tone + CLAUDE.md copy
      rule #1), one CTA button, honest "Android now, iOS in a couple
      weeks, join iPhone waitlist" line, NO child name, NO "internal
      tester / Google group / alpha / beta."
  - Draft PTA text template → `_data/pta_text_template_2026_04_23.md`.
    - EXACTLY 3 lines. One personalization slot `[Parent Name]`.
    - UTM baked into link; note at top of file (bold) telling Jim not to
      strip the UTM when copying.
    - Example shape already provided in PRD §Outputs item 2.
  - Run banned-word grep gate:
    `grep -iE "(internal tester|google group|alpha|beta)" <both drafts>`
    must return zero. If any hit → re-draft, do not proceed.
  - Queue both drafts into `/tmp/jim-queue/2026-04-23/` for the 60-min
    daily Jim window (Synth-final §8.9).

- **Jim's 60-min review window (evening, ~45 min of the 60):**
  - Jim reads both drafts. Per Synth-final §8.9, one approval covers both.
  - If approved as-is → agent flips drafts to "ready to send." If Jim
    requests edits → agent revises, re-runs banned-word grep, re-queues.
  - Jim clicks send on Buttondown (non-delegable, per PRD-006 §Tools HIL #3).
  - Agent confirms send via Buttondown API `GET /v1/emails/{id}` — status
    should be `sent`, not `draft`.
  - Jim sends PTA texts from iPhone (non-delegable, per PRD-006 §Tools HIL
    #2). Target ≥10 distinct recipients. 7–8pm weeknight send window
    (PRD §Context brief).
  - Jim logs each send in `_data/pta_send_log_2026_04_23.md` (agent pre-
    creates the file with the column headers).

### Day 4 (2026-04-24) — early-signal read
- Agent queries Buttondown API for open / click stats. Logs to
  `_data/t1d_buttondown_stats_day1.yaml`.
- Agent queries Firestore for any `utm_source IN ('buttondown','pta')`
  rows in `parents/`. First signal check — expect 0–5 rows, don't overreact.
- No send actions this day. Monitor only.

### Day 5–6 (2026-04-25 → 2026-04-26)
- Daily Firestore attribution peek. Append to running file.
- **Checkpoint: 2026-04-25 (Day 5)** — PRD `timeline.checkpoints` marker.
  Agent writes a 5-line status line: counts of email-captured,
  tester-enrolled, first-brush-completed for each UTM source. If zero
  rows from BOTH sources → see §4 Escalation.

### Day 7 (2026-04-28) — Day-7 attribution snapshot (hard PRD deliverable)
- Agent runs Firestore query per PRD-001 §acceptance query.
- Writes `_data/t1d_day7_attribution.yaml` with: clicks → email captures →
  tester-CSV-rows → first-brush counts, broken down by UTM source.
- Compares against Synth-final §7 Day-7 decision gate: if zero attributed
  installs, debug telemetry. If reasonable volume, continue.

### Day 8–13 (2026-04-29 → 2026-05-04)
- Passive monitoring. PRD-006 does NOT have a second send. The
  attribution window (7 days from click) is already closing for the
  earliest clicks. No new send actions.

### Day 14 (2026-05-07) — retro
- Agent queries Firestore one final time. Writes
  `_data/t1d_day14_attribution.yaml` (final).
- Agent appends T1d row to node-level `_retro.md` with: final
  qualified-install count, CAC ($0 expected, since no paid spend), open
  rate, click rate, PTA reply rate (from Jim's log), acceptance-criteria
  checklist final state.
- If the Day-14 floor (≥5 qualified installs) is not met → note in retro
  as a miss. Do NOT auto-retry; retry decision lives in the next loop
  recursion, not in PRD-006.

---

## 4. Tools / MCPs the agent would use

| Tool | Purpose | Auth / setup |
|---|---|---|
| `Read` + `Write` + `Edit` (filesystem) | Draft files, grep-gate, retro writeback | Native |
| `Bash` (grep) | Banned-word gate before send | Native |
| Buttondown HTTP API `POST /v1/emails` (draft) | Upload draft to Jim's Buttondown account | `BUTTONDOWN_API_KEY` env var — must be set before Day 3 |
| Buttondown HTTP API `GET /v1/emails/{id}` | Confirm send status after Jim hits send | Same key |
| Buttondown HTTP API `GET /v1/subscribers?count=true` | Get list size for retro (secondary metric) | Same key |
| Firestore read SDK or `gcloud firestore query` | Day-7 + Day-14 attribution snapshots | Service account key provisioned by PRD-001 — agent consumes, does not create |
| `tg send` CLI | Escalation pings only (see §5 below) | Installed at `~/.local/bin/tg` (per global CLAUDE.md Way 5) |
| `mcp__claude_ai_Gmail__create_draft` | OPTIONAL — forward one-pager approval summary to Jim's inbox if `/tmp/jim-queue/` is insufficient. Probably skip. | Already authorized in this session |

**Explicitly NOT used** (despite being deferred-available): Instagram, Reddit, Canva, ElevenLabs, Chrome MCP, Playwright, any computer-use. PRD-006 is plain-text + email + SMS only.

**Meta-PRDs consumed (but not modified):**
- `_meta-prd-buttondown-firebase-bridge.md` — Buttondown webhook → Cloud Function → Firestore. Needed so Buttondown opens / clicks reach Firestore attribution. If this meta-PRD's child loop hasn't shipped by 2026-04-23, PRD-006 can still send the email but Buttondown-side attribution is partial (clicks show only in Buttondown dashboard, not Firestore). Agent should flag this in the Day-3 plan if status is unknown.
- `_meta-prd-attribution-schema.md` — Firestore `parents/` + `testers/` schema. PRD-006 queries but doesn't write this schema.

---

## 5. Human-in-loop moments (exactly when Jim is needed)

| # | Day | Action | Time cost | Non-delegable? |
|---|---|---|---|---|
| HIL-1 | Day 3 evening 60-min window | Review Buttondown draft + PTA template. One approval covers both. | ~20 min | Yes — §8.9 |
| HIL-2 | Day 3, same window | Click send on Buttondown email from his own account | ~1 min | Yes — real-named-human list |
| HIL-3 | Day 3, 7–8pm | Physically send PTA texts from iPhone to ≥10 parents. Personalize each `[Parent Name]`. | ~30–40 min | Yes — PRD §Tools HIL #2, Synth-final §8.15 |
| HIL-4 | Day 3, after sending | Log each PTA send in `pta_send_log_2026_04_23.md` | ~5 min | Yes — only Jim knows who he texted |
| HIL-5 | ad-hoc, Day 3–14 | Respond to PTA-text replies if any parent flags privacy, child-data, or "is this spam" concern | Unpredictable | Yes — relationship work |

**Total planned Jim-hours: ~1 hr 10 min.** PRD budget allows 2 hrs. ~50-min cushion for revision cycles or Day-14 retro review.

**Escalation pings (ONLY these interrupt outside the 60-min window):**
- Buttondown API non-2xx → `tg send "T1d: Buttondown API error <status>, draft NOT sent"`
- Banned word surfaces in reviewed copy → pause + re-draft
- PTA parent flags concern → `tg send "T1d: PTA parent [name-redacted] flagged privacy concern, pausing further sends"`
- Day-7 zero attributed installs from BOTH sources → `tg send "T1d: Day-7 zero attributed installs, possible tracking break, need debug"`
- COPPA/legal flag in any copy (child name, face, school name appearing) → pause + `tg send`
- Jim-hours actual >3 hrs → `tg send "T1d: over Jim-hours budget, consider culling PTA personalization"`

---

## 6. Acceptance criteria mapping (which execution step satisfies which check)

| Acceptance criterion | Satisfied by (plan step) |
|---|---|
| Buttondown draft in `_data/` reviewed by Jim | Day 3 morning draft + HIL-1 |
| PTA 3-line template in `_data/`, exactly 3 lines, has placeholder, has UTM | Day 3 morning draft + banned-word grep |
| Zero banned words (grep must return zero) | Day 3 morning grep gate — agent will NOT queue to Jim if grep finds hits |
| iOS waitlist line / honest "iOS in a couple weeks" in both | Day 3 draft checklist item |
| Buttondown email sent, send status confirmed via API | HIL-2 + Day 4 API `GET` check |
| ≥10 PTA sends logged in `pta_send_log_2026_04_23.md` | HIL-3 + HIL-4 |
| Day-7 Firestore query returns rows for BOTH `buttondown` AND `pta` UTM sources | Day 7 snapshot query |
| Day-14 qualified installs ≥5 | Day 14 retro query |
| No parent response with confusion / COPPA / spam complaint | Passive monitoring; escalation triggers if violated |
| T1d row in `_retro.md` with final CAC | Day 14 retro writeback |

---

## 7. Risk + mitigation alignment with PRD §Risks

The PRD's 6 risks all have mitigations baked into the day-by-day above:
1. Small Buttondown list → accept, note in retro (PTA is the volume lane).
2. PTA parents feel pitched → 3-line plain text, no emoji spam, no forward-ask, 7–8pm send.
3. PTA UTM stripped when copying → bold note at top of template file.
4. iOS line confuses iPhone parents → "Android now, iOS in a couple weeks, iPhone waitlist" copy on both surfaces.
5. Buttondown marked spam → single send, plain template, no A/B, no image-heavy HTML.
6. Email forwarded to non-parent audience → banned-word gate + no child name + CLAUDE.md parent-CUJ review pass.

---

## 8. Verdict

**Can this PRD be executed by an agent-plus-founder pair?** **Yes, with
one soft dependency.** Everything in the PRD body is actionable as written.
The Day-7 and Day-14 Firestore queries depend on PRD-001's schema + service
account being live and the Buttondown→Firestore bridge (meta-PRD) having
shipped. Neither is PRD-006's job to build; they are inputs. If they
aren't green by Day 3, PRD-006 can still send (email + text), but
Firestore-side attribution degrades to "Buttondown dashboard only" for the
email channel and "manual count from PTA replies" for the SMS channel.
That degradation should be flagged on Day 3 in a `tg send` ping, not silently absorbed.

The human-gated send moments are correctly identified as non-delegable and
fit inside the 60-min daily window with cushion. The banned-word gate is
mechanical and trustworthy. The escalation triggers are specific and
actionable.

**Phase 1 smoke test result (this plan's own acceptance):** The PRD is
CONSUMABLE. The agent built a day-by-day plan without asking the
orchestrator for a single clarification. The gaps listed below are real
but are template-refinement feedback, not blockers.

---

## 9. PRD gaps (feedback for next loop's template refinement — NOT blockers)

Count: **6 gaps**. None prevent execution; all would sharpen the next PRD generation.

1. **Buttondown list size is "TBD by agent from Buttondown dashboard at send
   time" but no API method is named to fetch it before draft.** The PRD
   references Buttondown `GET /v1/subscribers?count=true` implicitly via
   "subscriber count" but doesn't wire it into §Inputs required. Low-impact
   gap — agent can infer — but a future template should make "data agent
   must fetch before drafting" its own section distinct from "assets."

2. **"Jim's daily 60-min review window" has no fixed clock time.**
   Synth-final §8.9 says it's batched, but neither the synth nor the PRD
   names the hour (e.g. "7–8 pm PT"). For Day-3 timing this matters: if
   Jim's window is morning, the PTA 7–8pm send window is a second session
   that day, so "one 60-min window covers everything" is slightly wrong.
   The PTA SMS is a SECOND Jim-session on Day 3, not part of the review
   hour.

3. **"Day 3" is Day 3 of the 14-day sprint, but the sprint's Day 0 is not
   explicitly dated in the PRD.** PRD says `start: 2026-04-23` = Day 3.
   Back-calculating, sprint Day 0 = 2026-04-20 (today, per the env). OK,
   but three separate date systems (sprint day, calendar day, PRD timeline
   dates) all appearing in §Context and §timeline is a readability risk.
   Future template: pick one canonical time reference and stick with it.

4. **The CSV-to-Jim-inbox pipeline from PRD-001 is assumed to handle the
   `parents/` rows for `utm_source='buttondown'|'pta'` exactly the same as
   any other UTM source, but PRD-006 doesn't state this assumption.** If
   PRD-001 happens to hardcode the inbox CSV to only include certain
   sources, PRD-006 would silently fail tester enrollment. Low-prob but
   non-zero. Future template: require each downstream PRD to list the
   "contract" it assumes from each upstream PRD.

5. **PTA send log has optional `response_received` column, but no schema
   for WHAT to log in it.** Is it a boolean? A free-text note? A reply
   timestamp? If the agent is expected to process this log later for
   the Day-14 retro's "PTA reply rate" secondary metric, its shape matters.

6. **No instruction for what to do if PRD-001 / PRD-005 ship LATE (after
   2026-04-22 EOD Day 2).** Synth-final §8.3 says T1d can't fire until
   T1c is green. PRD-006 assumes T1c IS green by its start. But if T1c
   slips to Day 4–5, does PRD-006 slip with it (and the 14-day window
   becomes 11 days), or does the 14-day window slide? The answer affects
   the Day-14 qualified-install floor. Future template: every dependent
   PRD should specify "if upstream slips, do I slip or do I shrink?"

---

**End of plan. Phase 1 boundary: STOP here. Do not send drafts, do not
query APIs, do not Telegram Jim until a future loop explicitly approves
crossing into Phase 2 execution.**
