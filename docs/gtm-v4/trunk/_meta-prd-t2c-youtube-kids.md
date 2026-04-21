# Meta-PRD — T2-C: Cavity Monster song via YouTube Kids / Ms. Rachel-adjacent creators

**Loop kind:** Tier-2 experiment child loop (content / IP branch)
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §4 T2-C + §8 #24 (YouTube Kids replaces TikTok)
**Tier:** 2
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**E2 said "if the song ends up on a Ms. Rachel-style channel, different story." So: does a well-produced 45-second "Plaque Attack" song + clip, pitched without a product pitch (character-IP-first), actually move for any Ms. Rachel-adjacent / YouTube Kids creator? Which creators are in the Ms-Rachel-adjacent tier that are reachable by a zero-relationship agent, what's the pitch frame (license-it / co-produce / here's-a-gift), and can ≥3 creator responses land inside 21 days on ≤$150 of Fiverr production?**

---

## Why this needs a child loop (not a direct PRD)

- **Song doesn't exist yet.** 45-second "Plaque Attack" must be produced (Fiverr singer + lyrics + minor beat). Lyrics must be COPPA-safe, child-appropriate, catchy, and Ms-Rachel-tone (toddler-speak, gentle cadence) while still kids-4-8 approachable.
- **Creator list does not exist.** "Ms. Rachel-adjacent" is a tier — Songs for Littles (Ms. Rachel herself — unreachable), Yo Gabba Gabba YouTube, Blippi channels, Dave and Ava, Super Simple Songs, Cocomelon (unreachable), Little Baby Bum. Plus indie: "Bounce Patrol," "The Singing Walrus," dental-focused kids channels. Scoring needed.
- **Pitch frame is undecided.** Co-produce? License? Gift-with-no-strings? Each has different legal/brand exposure.
- **COPPA risk if the song goes viral with a real kid singing it.** Must use adult vocalist or synthesized voice; must be brand-safe.
- **Attribution is soft.** Views don't equal installs. Need a bridge (QR on-screen? "find Brush Quest on Play" end-card?) that creators would actually include.

5 of 6 gate criteria unresolved — song asset alone blocks 3 leaves.

---

## What the child loop must produce

### Leaf PRDs expected (4)

1. **PRD-GTM-t2c-song-production-001** — produce the song + clip. Scope:
   lyrics (45 sec, COPPA-safe, brushing-themed, adult vocalist), Fiverr
   vocalist $50–80, Fiverr backing track $20–40, visual clip
   (space + cavity monsters, hero-proxy, 45 sec, 9:16 + 16:9), end-card
   with `brushquest.app/rangers?utm_source=creator_{channel}_{video}`.
   Budget cap: $150. Jim approves lyrics once before vocal recording.

2. **PRD-GTM-t2c-creator-shortlist-001** — Ms-Rachel-adjacent creator
   shortlist. Scope: 10–15 creators in target tier (excludes top-5
   unreachables like Ms. Rachel herself + Cocomelon). Mix of: big
   YouTube Kids (Dave & Ava, Bounce Patrol), mid-tier (Kids TV 123,
   Little Baby Bum adjacent), indie dental-focused (Story Bots dental
   episode creators). Scoring: subscriber count, audience parent skew,
   historical receptiveness to guest content, contact availability.
   Output: `trunk/_data/t2c_creators.yaml`.

3. **PRD-GTM-t2c-creator-outreach-001** — outreach with 2 pitch frames.
   Scope: email + DM each creator with 2 variants:
   (A) "here's a free song + clip you can use — no strings" (gift),
   (B) "we'd love to sponsor a video featuring this song" (paid — held
   back; agent flags any $-ask for Jim approval as >$100 = escalation).
   21-day response window.

4. **PRD-GTM-t2c-views-attribution-001** — measure. Scope: if any
   creator posts, monitor views (manual + scraped where possible),
   measure UTM clicks on any end-card or description-link, log outcome.
   Kill clock: <3 responses in 21 days OR <5K combined views in 45 days.
   Promote: ≥25K views or any creator feature.

### Design artifacts (non-PRD)

- Lyrics draft (2 variants — Jim picks)
- Clip storyboard
- End-card / watermark rules (COPPA-safe)

### Data artifacts

- `trunk/_data/t2c_creators.yaml`
- `trunk/_data/t2c_outreach_log.yaml`
- `trunk/_data/t2c_views_attribution.yaml`
- `trunk/prds/_t2c_postmortem.md`

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (kill <3 responses in 21d or <5K views in 45d; promote ≥25K views) | Trunk |
| 2. Context brief complete | Partial — creator tier TBD | Leaf 2 |
| 3. Inputs required enumerable | **Missing** — song does not exist; creator list does not exist | Leaves 1, 2 |
| 4. Outputs concrete | **Missing** — song, clip, creator list all TBD | Leaves 1, 2 |
| 5. Acceptance criteria binary | Present (thresholds named) | Trunk |
| 6. No blocking dependencies | **Pillar 1 attribution** needed for UTM measurement; otherwise independent | Pillar 1 Week 1 |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency:** `PRD-GTM-trunk-instrumentation-aso-001.md` — UTM
  attribution required before any creator posts.
- **No dependency on TikTok infra** — synth-final §8 #27 explicitly
  routes T2-C away from TikTok (no API MCP, audience mismatch).
- **Cross-feed:** if a creator mentions dental partnerships, route to
  `_meta-prd-pillar-2-dentists.md`.

## Budget + agent shape (inherited from trunk)

- Budget: $150 (song + clip production).
- Agent: `experiment-runner` generalist.
- Jim hours: ~2 total (approve lyrics, approve clip).
- Escalation: `tg send` on any $-ask beyond $100, any COPPA flag on
  song/clip, kill-clock hit, promote-trigger hit.

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- NOT TikTok (§8 #24).
- YouTube Kids / Ms-Rachel-adjacent is the channel (§4 T2-C).
- COPPA strict — adult vocalist only, hero-proxy visuals only
  (§8 #10, CLAUDE.md).
- `utm_source=creator_{channel}_{video}` (§8 #15).
- `brushquest.app/rangers` end-card (§8 #14).
- Zero CPI (§8 #6); song is production-priced.

## Child loop sequencing (recommended)

1. **Week 2:** leaf 1 (song production) + leaf 2 (creator shortlist) in
   parallel.
2. **Week 3:** leaf 3 (outreach) launches once song clip is ready.
3. **Week 3–5:** response window.
4. **Week 4–7:** views measurement if any creator posts.
5. **Week 7:** postmortem + gate decision.

## Charter termination criteria

- Did song production come in at/under $150?
- How many creator responses?
- Combined views if any posted?
- Promote / kill decision + reasoning.
- If promote: does this become a T1 IP/content loop?

---

**END META-PRD.** Charter frozen.
