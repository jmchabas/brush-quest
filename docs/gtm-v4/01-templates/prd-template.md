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
