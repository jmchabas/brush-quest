# Meta-PRD — Reddit posting + reply-SLA pipeline

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bet:** T1a — Reddit dual-post (r/androidtesting + r/daddit) from Jim's personal account
**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

How do we post to Reddit from Jim's aged personal account (not a brand handle) AND monitor replies within a 6-hour SLA without a Reddit MCP, without burning Jim-hours outside his daily 60-min window, AND without violating mod-culture on r/androidtesting (fresh-account auto-removal, karma gates)?

## Why this isn't PRD-executable now

Missing criterion 3 (inputs named + located) and 5 (tools exist or flagged TO-BUILD) from the termination gate:

- **No Reddit MCP available** in the current environment. Nothing in the ToolSearch list handles Reddit directly.
- **Posting from Jim's personal aged account** is non-delegable to an agent without OAuth-scoped app creds (PRAW requires account credentials + Reddit dev-app registration), AND running PRAW on Jim's personal account risks a sitewide-ToS flag if Reddit detects automation on a human account.
- **Mod dynamics on r/androidtesting:** mods remove posts from new accounts + posts that smell like marketing. Jim's account age helps but doesn't bypass — mod-DM pre-approval (E1 §4.2) is required, and there's no programmatic way to request that.
- **Reply-SLA monitoring:** honest-founder Reddit posts convert on *replies*, not the initial upvote curve. A 6-hour reply-latency budget is real, and there's no current automation to ping Jim when a question lands. Must design that notification loop.
- **Risk of sitewide ban** on Jim's personal account is catastrophic (loses aged-account advantage forever) — warrants explicit decision about which channel to use.

## What the child loop must produce

1. **Decision:** which posting channel to use.
   - Option A: PRAW CLI, run locally as Jim, posts scripted but Jim clicks "submit." Agent drafts, Jim presses submit.
   - Option B: Chrome-MCP semi-automated — agent loads Reddit in Jim's browser session, fills form fields, Jim presses submit.
   - Option C: Pure manual — agent writes the draft to `/tmp/jim-queue/YYYY-MM-DD/reddit-post.md`, Jim copy-pastes into Reddit himself.
   - Recommendation with reasoning. Probably Option C for the first post (lowest ToS risk) then revisit.
2. **Reply-SLA mechanism:** how does Jim get pinged within 6 hours of a top-level comment landing on his post? Options: RSS of post JSON → cron → `tg send`; Chrome-MCP poll; or Jim's own Reddit notification habits. Pick one, specify cron or timer.
3. **Mod-DM pre-approval workflow** (E1 §4.2): a draft DM to r/androidtesting mods before the post goes live. Template copy. Timing — how long to wait for mod reply before posting anyway.
4. **Anti-marketing-tone copy rules** for the post itself (honest-founder voice, no product-page links in the body, link in profile or top comment, "I built this because…" opener).
5. **Sub-specific post drafts** — r/androidtesting ≠ r/daddit. The first is a functional ("here's my build, looking for testers") post; the second is a parent-voice founder story. Two distinct drafts.
6. **Kill criteria for the pipeline itself:** if the first post is removed in <6h → mod-DM is required before re-post. If the second sub flags → pause subreddit and move Reddit budget to a different sub (candidates: r/Parenting, r/Dads, r/ScreenTime).

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Partial (Synth-final T1a says 12–25 qualified installs in 14 days; need per-post sub-target) | Child loop adds per-sub post-level targets (e.g. median 3 qualified per post) |
| 2. Context fully specified | No — mod culture + account history not yet captured | Child loop produces mod-DM templates, account-age check, karma-gate check |
| 3. Every input named + located | No — credential flow for posting undecided | Child loop picks PRAW vs Chrome-MCP vs manual; names credential or non-credential path |
| 4. Acceptance criteria checkable | Partial — post-count is checkable, reply-SLA is not | Child loop defines the SLA-monitor output artifact |
| 5. Tools exist OR flagged TO-BUILD | No — no Reddit MCP; PRAW requires a dev-app we haven't created | Child loop makes the tool decision + registers Reddit dev app if PRAW route |
| 6. Escalation triggers | Partial — Synth-final §7 has "post removed <6h" trigger but no ban-detection path | Child loop adds account-health monitor |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** `_meta-prd-attribution-schema.md` (Reddit post link must carry a valid UTM — can't land the PRD until attribution schema names `utm_source=reddit` shape + per-sub `utm_content` slugs).
- **Depends on:** `PRD-GTM-instagram-reels-001` (landing URL the Reddit post links to).
- **Blocks:** the T1a executor PRD (`prds/PRD-GTM-instagram-reels-002.md` — to be created once this meta resolves).
- **Informs:** `_meta-prd-ig-posting-pipeline.md` — pattern overlap on "post via aged personal handle, not brand handle" (same shape as T2b).

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.8: posts originate from Jim's personal aged account, never a fresh @brushquest handle. Child loop cannot propose a new brand-handle post here.
- §8.9: Jim's 60-min daily window is the only non-escalation touchpoint. Any "Jim checks Reddit at 2pm" design is out of bounds; use `tg send` escalation.
- §8.11: Day-3 zero-install gate applies — this PRD cannot be the sole source of installs, it must be part of the stacked lanes.

## Rough size estimate for the child loop

Small. ~3–5 hrs agent time. Likely one round of L3 + L4 research (Reddit PRAW pros/cons, similar founder posts that did and didn't survive), then a single synth. Shouldn't need A/B/C evals — mostly operational, low-controversy if Option C (pure manual) is picked.
