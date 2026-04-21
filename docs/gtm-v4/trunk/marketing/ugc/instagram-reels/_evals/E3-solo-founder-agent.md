# E3 — Solo-founder Executor-Agent Evaluation

**Node:** `trunk/marketing/ugc/instagram-reels`
**Plan reviewed:** `_synth-v1.md` (2026-04-20)
**Evaluator lens:** what an agent + Jim (5 hrs/wk) can actually ship next week with $1K, Claude Code, and the MCPs already wired.

---

## 1. Executability score

| Bet | Tool readiness | Jim-hrs/wk | Agent-autonomy loop | Likely failure mode |
|---|---|---|---|---|
| **T1a** Reddit dual-post (r/androidtesting + r/daddit) | **Partial.** No Reddit MCP. Posting = manual via claude-in-chrome (browser tier "read" → needs Chrome MCP for click/type). No Reddit credentials in repo. | 2 hrs (post + reply to DMs; Reddit rule is founder must respond personally or looks botted) | Drafting = autonomous. Posting = Jim or browser-MCP with Jim-supervised click. Reply triage = loop-on-approval. | Shadow-remove, mod-removal of Play link, downvote spiral, Jim missing 4-hr reply window. |
| **T1b** Micro-creator proxy → scale | **Weak.** No Meta Creator Marketplace MCP, no Modash, no IG Graph API. Scouting = manual IG scroll via Chrome MCP or Gmail cold-outreach. Payment = Mercury (auth MCP present, no payment-initiate). | 2 hrs (contract, brief approval, payment trigger) | Scouting+drafting outreach = autonomous via Gmail MCP. Audience-fit verification = **blocked**, relies on creator screenshotting demographics (trust-based). Contract signing = Jim. | Creator ghosts after down-payment; audience-fit misrepresented; payment timing vs post timing drift. |
| **T1c** brushquest.app/rangers landing + email→auto-enroll | **Strong.** Landing page is in repo, Buttondown account live, Firebase Admin SDK usable from Claude Code. No Buttondown MCP but REST API is trivial. | 1 hr (copy approval, visual QA on iPhone) | Fully autonomous build + deploy. Escalate only on copy and the Google-Group auto-enroll mechanic (needs Jim's Play Console cookie or a service-account — currently not wired). | Google internal-testing tester-list is edited via Play Console UI, not API — "auto-enroll" is likely manual CSV upload by Jim until public review clears. |
| **T1d** Buttondown + warm network sweep | **Strong.** Buttondown REST via curl, Gmail MCP for personal outreach, Google Calendar for PTA follow-ups. | 2 hrs (PTA outreach is relationship work — not delegable) | Email drafting autonomous. PTA outreach cannot be agentic; it IS Jim's warm tie. | Jim doesn't actually send the PTA message. This is the single highest-leverage, highest-slip bet. |
| **T2a** Throwaway-handle format test | Manual IG posting; no IG API. | 1 hr | Creative draft autonomous; uploads manual. | Jim burns out on daily posting cadence by Day 4. |
| **T2b** Jim's personal IG, 2 Reels | Manual. | 0.5 hr | Jim-in-loop by definition. | Same as T2a. |
| **T2c** Dentist QR poster | ai-image-gen + Canva MCP + print. | 0.5 hr (hand poster to dentist) | Design autonomous; physical handoff is Jim. | Poster never reaches dentist wall. |
| **T2d** Substack pitches | Gmail MCP covers it. | 0.5 hr | Fully autonomous draft + send with Jim one-click approve. | Low response rate is expected; not a failure. |
| **T2e** Slideshow Reel format | Canva MCP + manual upload. | 0.5 hr | Autonomous up to upload. | Upload cadence. |
| **T2f** FB group seed | Manual; no FB API. | 0.5 hr | Jim-in-loop. | FB link-suppression confirms L3's call and kills itself. |

**Weekly Jim-hour budget for full Tier-1+2: ~10–11 hrs.** Plan claims 7. **Over budget by ~2x** once IG/Reddit/FB manual uploads are realistic.

---

## 2. Tool gaps (pre-requisite PRDs)

1. **Instagram posting pipeline PRD.** No IG Graph API MCP. Options: (a) Chrome MCP + saved session for semi-auto posts; (b) Buffer/Later REST wrapper; (c) Jim posts manually on a schedule. Pick one before T2a/T2b/T2e can run.
2. **Reddit posting + monitoring PRD.** No Reddit MCP. Minimum: PRAW-wrapped CLI Jim triggers; agent drafts, Jim approves, script posts. Also need a comment-monitor cron so DM reply SLA isn't missed.
3. **Play Console tester auto-enroll PRD.** Google Play Developer Publishing API supports internal-testing list edits via service account — currently not wired. Without this, T1c's "auto-enroll" is a CSV Jim uploads nightly.
4. **Buttondown → Firebase bridge PRD.** Small: Buttondown webhook → Cloud Function → Firestore `testers/` collection + Play Console CSV export. Straightforward from Claude Code.
5. **UTM attribution PRD.** Landing-page UTM capture → Firestore + Play Store `referrer` extra. Must ship with T1c or Day 14 retro is vibes (per synth §9.2).
6. **Creator audience-fit verification PRD.** No Modash, no Creator Marketplace. Fallback: require creator screenshot of IG Insights demographic tab before paying. Trust-based — flag this clearly in T1b.
7. **TikTok/Meta paid ads** — deferred; out of 14-day scope, correctly parked in T3.

---

## 3. Shape of the executor agent(s)

- **"Landing + Pipeline Agent"** (T1c + bridges) — generalist Claude Code agent. Owns landing-page code, Buttondown webhook, UTM capture, CSV export. Escalate on: copy wording, privacy-policy edits, Firebase schema changes.
- **"Outbound Comms Agent"** (T1d + T2d + creator outreach) — Gmail-MCP-driven. Drafts, lists for Jim approval in one batch per morning, sends on approval. Escalate on: anything that names a real person Jim hasn't met.
- **"Social Post Agent"** (T1a Reddit + T2a/b/e/f IG/FB) — Chrome-MCP + computer-use hybrid. Prepares posts in a staging doc (Google Drive MCP), Jim clicks "send" from phone. Escalate on: any moderation flag, any link suppression, any reply that's a real parent question (not spam).
- **"Creator Ops Agent"** (T1b) — mostly dormant. Activates on Day 5 gate. Owns brief, payment authorization request to Jim, and post-go-live tracking. Escalate on: every $-out, every contract.
- **"Dashboard Agent"** (attribution + 14-day retro) — reads Firestore + Play Console CSVs, writes `_retro.md`. Autonomous.

Escalation rule set: any money out, any message to a real named human, any legal/COPPA copy, any write to Firestore schema → Jim approves. Everything else → run.

---

## 4. Strengthen

- **Pin tools per PRD header.** Each PRD lists required MCPs + credentials upfront. Reject plan if a tool isn't live.
- **Add explicit "human-gate" markers** to synth §7 sequencing. Day 1 has ~5 human gates (PTA DM, Reddit post button, creator DM approval, landing-copy signoff, email-blast send). Batch these into a **single 60-min Jim window** instead of interrupt-driven pings.
- **Replace "auto-enroll" in T1c with "CSV-to-Jim-inbox" until Play Publishing API is wired.** Honest naming. Ship the API wiring as a T2 experiment in parallel.
- **Creator audience-fit verification needs a one-pager checklist** (screenshot requirement, US-parent share ≥40%, red-flag patterns). Otherwise agent forwards any interested creator to Jim, wasting his hours.
- **T1a Reddit posts must be posted by Jim's personal account**, not a new @brushquest account (androidtesting mods catch fresh accounts). Codify this in the PRD.
- **Add a Day 3 "kill-if-nothing" gate.** If by end of Day 3 zero installs are attributed, something is broken in T1c attribution — not in the funnel. Debug telemetry before scaling any bet.
- **Flag Canva MCP + ai-image-gen + lottiefiles** are available — Reel storyboards and static creative can ship without Jim's design time. Synth underuses these.

---

## 5. De-prioritize to Tier-3

- **T2e slideshow-carousel Reel format** — requires IG API or manual upload cadence Jim can't sustain. Trigger to revisit: when IG posting pipeline PRD (gap #1) ships.
- **T2f FB group seed** — no FB API MCP, link suppression likely. Trigger: when a group admin explicitly invites us (relationship-led, not cold).
- **T1b "scale batch" tier** (the $400 extension) — keep the $120 proxy as Tier-1, but the scale decision should be Tier-3 until attribution (gap #5) is proven end-to-end. Trigger: T1c attribution shows proxy CAC <$15 with ≥3 confirmed qualified installs.
- **Do NOT deprioritize T1a or T1d** — these are the engine. T2a/T2b stay as cheap signal tests.

---

## 6. Overall verdict

**Realistically, the agent+Jim pair hits 25–40 qualified installs in 14 days, not 50** — assuming T1c ships Day 1–2 (the bottleneck) and Jim defends his 10 weekly hours. The plan's portfolio shape is correct: Reddit + warm network carry the load, Reels are content scaffolding. The main executability risk is not the bets themselves but **unacknowledged manual toil**: IG, Reddit, FB, Play Console tester list, and PTA outreach are all human-in-the-loop and the plan under-counts Jim-hours by ~30%. Ship T1c + T1d + T1a in Week 1, gate T1b on attribution working, and push T2e/T2f to Tier-3 until a posting-pipeline PRD lands. If public Play review clears mid-sprint (likely, since we're Day 9 of a 1–7 day nominal window), re-score everything — the dominant funnel coefficient drops and 50 becomes defensible.
