# Brush Quest — Cross-Platform GTM (Timeline C)

> **Read this first when both iOS and Android are at Production simultaneously.** Single source of truth for the synchronized public launch — the moment Brush Quest is available on both stores and the high-leverage parent network channels can finally fire.

**Goal:** Convert the cross-platform Production launch into a measurable acquisition + retention event. Activate the high-leverage channels that were deliberately held back during Android-only Phase 1 (Nicole's Alameda parent network, Substack pitches, eventual paid acquisition).

**Approach:** Coordinated launch over a 4-week window. Pre-launch week stages all assets and channel relationships. Launch week fires Nicole's network + neighborhood + dentist channels. Post-launch weeks add Substack pitches + paid amplification + press.

**Trigger criteria (ALL must be true to start this plan):**
- Android Production live (or Public Beta if Android decided to coordinate launch)
- iOS Production live OR App Store review approval imminent (≤ 7 days)
- Crashlytics + Analytics flowing on both platforms
- Listing on both stores reviewed and live
- ≥ 1 testimonial-grade quote captured from Phase 1 (Android Public Beta)

**Authoritative references:**
- Android plan: [`../android-launch/PLAN.md`](../android-launch/PLAN.md)
- iOS plan: [`../ios-port/PLAN.md`](../ios-port/PLAN.md)
- Substack pitches drafted Apr 21: PRD-007 in GTM v4 factory (`docs/gtm-v4/`)
- GTM engine reference: memory `reference_gtm_v4_factory.md`

---

## Phase 0 — Brand defense (URGENT, do NOW, in parallel with everything else)

> **Why URGENT:** A "Brush Quest" name conflict surfaced on Apple App Store (2026-04-28). Without immediate action, we risk: (a) trademark dispute later from prior user, (b) Apple Store review rejection on iOS submission, (c) market confusion on launch, (d) losing defensive ownership of social handles + domains. Triage decisions here gate iOS submission and full GTM amplification — but most tasks can run in parallel with Android Phase 1.

### Z — Conflict investigation (do first, all 5 in parallel — can finish in ~1 hour)

- [ ] (T1·C) **Z-1.** Apple App Store search for "Brush Quest" + variants ("BrushQuest", "Brush Quest Kids", etc.) — capture: app name, developer, category, age range, last updated, country availability, install count if visible, screenshots. Save findings at `docs/brand/conflict-apple.md`.
- [ ] (T1·C) **Z-2.** Google Play Store search for same terms — same data. Save at `docs/brand/conflict-play.md`.
- [ ] (T1·C) **Z-3.** USPTO TESS trademark search at https://tmsearch.uspto.gov/ for "Brush Quest" + similar marks. Capture: filing serial, owner, classes (especially 9 software/apps + 41 entertainment), status (live/dead/abandoned), filing date. Save at `docs/brand/uspto-tess.md`.
- [ ] (T1·C) **Z-4.** WIPO Global Brand Database for international filings (https://branddb.wipo.int/). Capture similar data, note Madrid Protocol coverage. Save at `docs/brand/wipo.md`.
- [ ] (T1·C) **Z-5.** Domain + social handle check — run namechk.com (or knowem.com) for "brushquest" across major networks. Capture which are taken, by whom, last activity. Save at `docs/brand/handles.md`.

### Y — Lock available assets (start as soon as Z findings arrive — don't wait for full triage)

- [ ] (T1·J) **Y-1.** Register domain variants Jim doesn't own yet — recommended priority: `brushquest.com` (highest), `brushquest.io`, `brushquest.co`, `brushquest.games`. Skip `.app` (already owned). Use Cloudflare Registrar or Namecheap (cheapest). ~$50-100/yr total.
  - Acceptance: list of registered domains saved at `docs/brand/domains-owned.md`.
- [ ] (T1·J) **Y-2.** Reserve social handles `@brushquest` on: Twitter/X, Instagram, TikTok, YouTube channel, Threads, Bluesky. Even if not posting yet — defensive holds. Use a profile placeholder + link to `brushquest.app`.
  - Acceptance: list saved at `docs/brand/handles-owned.md` with login credentials in 1Password / your password manager.
- [ ] (T1·J) **Y-3.** Reserve Facebook Page name "Brush Quest" + Reddit username `u/brushquest` + Discord server "Brush Quest" (private for now). Discord/Reddit are stricter on inactive holds, so do this only if you'll use them within 30 days.
- [ ] (T1·J) **Y-4.** Verify ownership of `brushquest.app` and capture renewal date in calendar (avoid letting it lapse).

### X — Trademark filing (sequential to Z — depends on findings)

- [ ] (T1·J) **X-1.** Based on Z-3 / Z-4 findings, decide trademark strategy:
  - (a) **No prior filing exists:** file ASAP — first-to-file gives priority. Standard route.
  - (b) **Prior filing exists, abandoned/dead:** file ours; the prior abandonment doesn't block.
  - (c) **Prior filing live in same class (9/41) for similar goods:** consult IP attorney before filing — possible rebrand decision.
  - (d) **Prior filing live in different class:** likely safe to file in 9/41; document the analysis.
- [ ] (T3·C) **X-2.** Draft trademark application content (per `Y-1` / `Y-2` decision):
  - Word mark: "BRUSH QUEST"
  - Possibly design mark: app icon + wordmark combination (for stronger protection)
  - Classes: 9 (downloadable mobile app software for children's hygiene games), 41 (entertainment services — providing online games)
  - Specimen of use: live Play Store / App Store listing screenshot (once iOS Production live)
  - First use date: Internal Testing launch, Apr 2026
  - Save at `docs/brand/tm-application-draft.md`.
- [ ] (T1·J) **X-3.** Filing decision: DIY USPTO TEAS Plus (~$250/class × 2 = $500) vs. attorney-filed (~$1500-2500). **Recommendation: at least one consultation given the conflict exists.** A 30-min IP attorney consult ($200-400) significantly de-risks the filing.
- [ ] (T1·J) **X-4.** File the application (yourself or via attorney). Track serial number + USPTO status updates in `docs/brand/tm-status.md`.
- [ ] (T1·J) **X-5.** Calendar reminder: USPTO examination typically takes 8-12 months. Set a 6-month check-in. If office action issued (request for amendment), respond within 6-month deadline.

### W — Decision gate based on conflict severity

> Run this gate after Z investigation completes. The output determines whether we proceed with the "Brush Quest" name or rebrand.

- [ ] (T3·C) **W-1.** Summarize Z findings into a one-pager at `docs/brand/conflict-decision.md` — table form: source (Apple/Play/USPTO/etc.), entity, similarity (1-5), risk (low/med/high), recommended action.
- [ ] (T1·J) **W-2.** Decision matrix:

  | Conflict severity | Action |
  |---|---|
  | Low (different category, small/inactive, no trademark) | Proceed with Brush Quest; file our trademark for defensive priority |
  | Medium (same category, small competitor, no trademark) | Proceed but expedite trademark filing; monitor competitor monthly |
  | High (similar product, active, has filed trademark) | Pause launch; consult IP attorney within 7 days; rebrand decision within 30 days |
  | Existential (clear infringement claim already in motion) | Cease all "Brush Quest" branding immediately; rebrand before next public action |

- [ ] (T1·J) **W-3.** Document decision + reasoning in `docs/brand/conflict-decision.md`. If proceeding: update STATUS.md and continue plan. If rebranding: this becomes a separate workstream that blocks iOS launch + Cross-Platform GTM Phase 1+.

---

## Status legend

- `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
- **T1** Claude executes autonomously · **T2** Claude executes, Jim reviews via PR · **T3** Claude proposes, Jim approves first
- **C** Claude (code, scripts, automation) · **J** Jim (manual UI / portal / console)
- **N** Nicole (her direct channels — drafts go through Jim for review first)

Format per task: `- [status] (tier·owner) ID. Title — short note`

---

## Pre-launch week (T-7 to T-1, both stores about to be live)

> Stage everything in advance. The actual launch week shouldn't have any "create asset from scratch" work — only execute and respond.

### A — Asset finalization

- [ ] (T2·C) **A-1.** Update STATUS.md, all memory files, and landing page with both Production install URLs (iOS App Store + Google Play).
- [ ] (T2·C) **A-2.** Refresh promo video description on YouTube with both store URLs.
- [ ] (T2·C) **A-3.** Update privacy policy + COPPA disclosures with iOS-specific language (no Firebase Analytics on iOS, etc.).

### B — Nicole's Facebook campaign prep

- [ ] (T3·C) **B-1.** Draft 2 Nicole-Facebook variants:
  - **Short post (300 chars)**: low-stakes, casual Alameda parent group share. Focus on outcome ("my kid actually wants to brush now").
  - **Long story post (700 chars)**: photo-friendly, dad-built-for-his-kid narrative, specific moment of transformation.
  - Both end with both store URLs side by side.
  - Save at `docs/launch/copy/nicole-facebook-variants.md`.
- [ ] (T1·J) **B-2.** Jim reviews drafts; refines tone with Nicole.
- [ ] (T1·J/N) **B-3.** Nicole identifies the 5-8 Alameda parent Facebook groups she's most active in. Maps each group to one of the variants (short for casual groups, long for engaged ones).
  - Acceptance: list saved at `docs/launch/copy/nicole-target-groups.md` with group name + which variant.
- [ ] (T2·C) **B-4.** Coordinate with Nicole on posting cadence: 1 group per day for 5-8 days (avoids spam-flag), or all in one day if she prefers. Recommendation: spaced.

### C — NextDoor amplification

- [ ] (T2·C) **C-1.** Update Phase 1 NextDoor draft (from Android plan 1C-3) to include both URLs and "now available on iPhone too" language.
- [ ] (T1·J) **C-2.** Re-post (or boost) on Alameda + adjacent NextDoor neighborhoods.

### D — Substack pitch revival

- [ ] (T2·C) **D-1.** Pull the 3 Substack pitches drafted 2026-04-21 in PRD-007. Refresh dates, update install URLs, add testimonial quote from Phase 1.
- [ ] (T2·C) **D-2.** Identify 5-10 additional parenting-focused Substacks (kids' tech, dental health, modern parenting). Build pitch list with editor name + email + recent post topic to reference.
  - Acceptance: list saved at `docs/launch/copy/substack-targets.md`.
- [ ] (T1·J) **D-3.** Jim sends pitches in 3 batches: top 3 day 1, next 4 day 3, remaining day 5. Spaced sending lets early responses inform later pitches.
  - Trigger: T+0 (launch day), not pre-launch.

### E — Press list (parent-tech / kids-app blogs)

- [ ] (T2·C) **E-1.** Build press contact list: parent-tech blogs, kids-app coverage, dental-parent blogs, mommy-blogger network. Editor name + recent post + relevance angle.
  - Acceptance: list saved at `docs/launch/copy/press-list.md`.
- [ ] (T2·C) **E-2.** Draft 1-pager press kit (PDF): logo, screenshots, founder quote, key stats, both store URLs, contact email.
  - Acceptance: PDF generated, version-controlled in `docs/launch/assets/`.

### F — Paid acquisition decision gate

> Default: skip paid for first 4 weeks. Re-evaluate at T+30 with organic data.

- [ ] (T1·J) **F-1.** Review at T+0 launch readiness check: any reason to fire paid acquisition immediately? Default = no, validate organic first.
- [ ] (T1·J) **F-2.** At T+30 review, decide: paid yes/no? Budget? Channels (Google Play UAC vs. Meta vs. Apple Search Ads)? See decision criteria in section "Paid acquisition decision matrix" below.

---

## Launch week (T+0 to T+7)

### G — Day T+0 (launch day)

- [ ] (T1·C) **G-1.** Send Telegram notification: "🚀 Brush Quest cross-platform launch live on both stores."
- [ ] (T1·J/N) **G-2.** Nicole posts variant in first Alameda Facebook group.
- [ ] (T1·J) **G-3.** Jim sends top 3 Substack pitches.
- [ ] (T1·J) **G-4.** Jim posts NextDoor re-post.
- [ ] (T1·J) **G-5.** Update landing page banner: "Now available on iPhone and Android."

### H — Day T+1 to T+7

- [ ] (T1·J/N) **H-1.** Nicole posts to next Facebook group(s) per cadence plan.
- [ ] (T1·J) **H-2.** Daily Crashlytics + Reviews check on both stores. Respond to all reviews within 24h.
- [ ] (T1·J) **H-3.** Day T+3: Jim sends batch 2 of Substack pitches (4 newsletters).
- [ ] (T1·J) **H-4.** Day T+5: Jim sends batch 3 of Substack pitches (remaining).
- [ ] (T2·C) **H-5.** End of week: snapshot of metrics — installs per channel (UTM-tagged URLs), Facebook engagement, Substack open rates if shared.
  - Acceptance: snapshot at `docs/launch/metrics/launch-week.md`.

---

## Post-launch (T+8 to T+30)

### I — Channel iteration

- [ ] (T1·J/N) **I-1.** Nicole completes remaining Facebook group posts.
- [ ] (T1·J) **I-2.** Follow up with Substack editors who responded; decline-thank others.
- [ ] (T1·J) **I-3.** Press list outreach: send press kit to top 5 from list E-1.
- [ ] (T2·C) **I-4.** Identify 3-5 parent-blogger/influencer micro-collabs (5K-50K followers, kids' tech focus). Pitch product trial.

### J — T+30 review + paid acquisition decision

- [ ] (T2·C) **J-1.** Compile T+30 metrics dashboard: installs, retention, reviews avg, organic vs. referred breakdown, channel ROI.
  - Acceptance: dashboard at `docs/launch/metrics/T30-review.md`.
- [ ] (T1·J) **J-2.** Decision review: organic acquisition pace + retention sufficient to defer paid? OR fire paid acquisition? See decision matrix.
  - Acceptance: decision documented in `docs/launch/decisions/2026-XX-XX-paid-acquisition.md`.

---

## Paid acquisition decision matrix

> Default = defer paid until organic data is in. Fire paid only if specific signals trigger.

**Fire paid IF:**
- Day-7 retention ≥ 30% (good unit economics — you're not just pouring users into a leaky bucket)
- Average rating ≥ 4.5 on both stores (paid acquisition without high rating = bad ROI)
- Organic acquisition has plateaued or declined for ≥ 14 consecutive days
- ≥ 1 channel has produced unit economics (CPI estimate from organic-test campaigns) that justifies paid

**Defer paid IF:**
- Day-7 retention < 30% — fix the product before scaling spend
- ≥ 1 P1 bug open — paid acquisition during instability burns money
- Organic still ramping — paid would just substitute for free installs

**Channels (when firing):**
1. **Google Play UAC** (Android) — best CPI but limited targeting. Start here.
2. **Apple Search Ads** (iOS) — high intent (parents searching "brushing app"), good for kids category. Expensive but tight match.
3. **Meta (Facebook + Instagram)** — broadest reach, parent demographic strong. Test with $5-10/day, optimize on install events.

**Initial budget if firing:** $50-100/day for 14 days, split across 1-2 channels max. Re-evaluate at $1.5K-3K spend.

---

## What's NOT in this plan (handled elsewhere)

- Android-specific Production gates → [`../android-launch/PLAN.md`](../android-launch/PLAN.md) Phase 2
- iOS App Store submission + review → [`../ios-port/PLAN.md`](../ios-port/PLAN.md)
- App development cycles → `/cyclepro`
- Monetization (in-app purchases, subscriptions) → memory `decision_product_strategy_2026_03.md`. Not part of launch.
