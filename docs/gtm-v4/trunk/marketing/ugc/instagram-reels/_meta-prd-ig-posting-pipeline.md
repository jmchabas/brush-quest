# Meta-PRD — Instagram posting pipeline (brand handle + Jim's personal handle)

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bets:**
- T2a — Throwaway-handle parent-confessional format test on @brushquest
- T2b — 2 Reels from Jim's personal IG (warm-start hypothesis)

**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

Without a live Instagram Graph API MCP in the current toolkit, how does an agent (a) post Reels to @brushquest, (b) cross-post variants to Jim's personal IG, (c) read Insights on both to compare reach, AND (d) do all of this in a way that fits Jim's 60-min daily window rather than becoming a second job?

## Why this isn't PRD-executable now

Missing criterion 5 (tools exist or flagged) and 3 (inputs named).

- **No IG Graph API MCP** in the available toolkit. The existing Chrome-MCP can semi-drive IG but has session-lifetime + account-safety issues.
- **@brushquest is a cold handle** — Synth-final §2 acknowledged this is the core format-test, not a funnel bet. If the handle is cold at Day 1, we need to accept that first 3 posts under-index on reach (L4 cold-start pattern) and bake that into T2a's kill criteria.
- **Jim's personal IG** is warmer but posting commercial content from a personal account risks algorithmic deprioritization + potential "commerce on personal account" flag. Needs a decision: do we convert Jim's IG to Business (required for Graph API) or leave it personal and use Chrome-MCP?
- **Reels require video editing** (captions, hooks, text overlay, audio). The creative brief (§8.5) is strict: meltdown hook at 0s, game reveal at 0:06, hands-only, no Space Ranger aesthetic at 0–3s. Who edits? ffmpeg via agent? Premiere by Jim? Canva/CapCut?
- **Insights access** for @brushquest is possible via Graph API IF we convert to Business + connect a Facebook Page. Insights for Jim's personal account is viewable only while logged in.
- **Posting schedule + hashtag strategy + first-comment-with-link** — all native IG patterns not covered by a generic MCP.

## What the child loop must produce

1. **Account tier decision:**
   - @brushquest — convert to Business + connect to a Facebook Page OR keep Creator-tier? Graph API needs Business. Decision + rationale.
   - Jim's personal IG — stay personal (no Graph API access) and use Chrome-MCP semi-auto, OR convert to Business (loses warm signals)? Recommendation: stay personal to preserve the warm-start hypothesis T2b is testing; accept manual-with-agent-drafts flow.
2. **Posting mechanism per account:**
   - @brushquest: if Business → Graph API via a to-be-registered Meta Developer app + long-lived token. Else → Chrome-MCP with agent-written caption + Jim presses "share."
   - Jim's personal: Chrome-MCP or Jim-manual with agent-written drafts in `/tmp/jim-queue/`.
3. **Creative production pipeline:**
   - Video source: in-app gameplay captures (Android Studio recorder) + optional parent-voice voiceover via ElevenLabs.
   - Editing: ffmpeg-driven agent for cut/captions/overlay OR Jim on CapCut. Pick. Probably ffmpeg for velocity.
   - Thumbnail: first-frame auto-generation OR custom cover.
   - Duration target: 12–25s per Synth-final §8.5 (meltdown hook at 0s, reveal at 0:06 — min ~8s, max the IG-algorithm-preferred ~30s).
4. **Caption + hashtag strategy:**
   - Caption template per archetype (confessional-parent, counter-intuitive-screen-time, founder-build-in-public).
   - Hashtag bank (≤8 per post) — parenting-native, not app-marketing-native.
   - First-comment link: `brushquest.app/rangers?utm_source=ig_cold&utm_medium=social_post&utm_campaign=format_test_2026_04&utm_content={post_slug}` for @brushquest; `utm_source=jim_personal_ig` for the personal-account variant.
5. **Insights collection per account:**
   - @brushquest (Business): Graph API pull at 24h, 72h, 7d per post. Logs to `_data/ig_brushquest_insights.yaml`.
   - Jim's personal (no API): Chrome-MCP screenshot of Insights tab at same intervals; OCR OR Jim manually enters 5 numbers into a Google Sheet. Pick the lightest-weight route.
6. **Kill-criteria gates** (already set in Synth-final T2a + T2b, but need pipeline-level clarity):
   - T2a: median reach <500 across 3 posts in 5 days → kill format AND the whole @brushquest-handle strategy (per Synth-final §4).
   - T2b: personal-account reach <2× @brushquest same-day → warm-start hypothesis dead.
7. **Comparison reporting:** Dashboard Agent produces a same-day delta chart comparing personal vs. @brushquest reach for same creative (T2b's core test).

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Yes — Synth-final §4 kill criteria set | Child loop translates to code-level check |
| 2. Context fully specified | No — account tier, editing tool, Insights read path all undefined | Child loop decides all three |
| 3. Every input named + located | No — no Meta Developer app, no Chrome-MCP session plan, no gameplay-clip library path | Child loop names each |
| 4. Acceptance criteria checkable | Partial | Child loop defines the Insights-snapshot acceptance |
| 5. Tools exist OR flagged TO-BUILD | No — IG Graph API integration is TO-BUILD; Chrome-MCP workflow is TO-DESIGN | Child loop scopes |
| 6. Escalation triggers | Partial — Synth-final §7 has "account warning" but no content-moderation flag path | Child loop adds IG-specific triggers |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** `_meta-prd-attribution-schema.md` — UTM shape for `utm_source=ig_cold` + `utm_source=jim_personal_ig`.
- **Depends on:** `PRD-GTM-instagram-reels-001` (landing live, attribution working).
- **Blocks:** T2a + T2b executor PRDs (to be created once this meta resolves).
- **Shares creative spec with:** `_meta-prd-creator-scouting.md` — creator brief (PRD-003) sets the aesthetic, T2a/T2b self-produced Reels follow the same spec.
- **Jim-hours contention:** per Synth-final §7 escalation trigger "Jim-hours >10/wk actual vs. 7 planned → deprioritize T2a/T2b first." T2a/T2b ARE the lowest-priority Tier-2 lanes. Child loop must propose a posting cadence that does not break this.

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.5: creative-brief rules apply to BOTH self-produced Reels AND paid-creator Reels. Meltdown hook at 0s, game reveal at 0:06, hands-only, COPPA.
- §8.9: 60-min daily Jim window. Posting time is IN the window; agent prepares + Jim approves.
- §8.14: no IG MCP = spawn this meta-PRD, not a workaround. Don't pretend Chrome-MCP is "the same as" Graph API for Insights — different trust and rate properties.
- §8.11: T2a/T2b are NOT on the Day-3 kill-gate critical path (that's T1c). If the IG pipeline is down Day 3, other lanes continue.

## Rough size estimate for the child loop

Small-to-medium. ~5–8 hrs agent time. Mostly decision-making: account tier, posting mechanism, editing tool. A/B/C evals probably NOT needed — lower-stakes lane than T1c/T1b. One round of L3/L4 on cold-handle IG starting cost + warm-personal-account deprioritization patterns is enough.
