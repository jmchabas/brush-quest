# Brush Quest — Brand Defense Workstream

> **Read this first at the start of every brand-defense session.** This is the single source of truth for what's done, in flight, and blocked. Update as tasks complete. Don't re-derive state from `git`, `grep`, or memory files — trust the plan.

**Goal:** Defend the "Brush Quest" brand against the existing Apple App Store conflict (Mitchell Pothitakis, released 2025-07-18), establish trademark priority, and lock all brand assets — without alerting Mitchell or paying him.

**Approach:** Quiet first-mover defense. File USPTO trademark in our own name, snap up available brand assets (domains, social handles), differentiate market positioning (Kids Category, different visual identity), and outpace him in public presence. Set up a `.com` snipe for when his squatted variant expires. Operate in parallel with Android Phase 1 and iOS launch — does NOT block them unless conflict severity escalates.

**Authoritative references:**
- Conflict findings: [`conflict-apple.md`](conflict-apple.md), [`handles.md`](handles.md), [`uspto-tess.md`](uspto-tess.md)
- W-1 strategic decision pager: [`conflict-decision.md`](conflict-decision.md) — read this for the full reasoning
- Cross-Platform GTM Phase 0: [`../launch/CROSS-PLATFORM-GTM.md`](../launch/CROSS-PLATFORM-GTM.md) (this workstream is the elaboration of Phase 0)
- Android plan: [`../android-launch/PLAN.md`](../android-launch/PLAN.md)
- iOS plan: [`../ios-port/PLAN.md`](../ios-port/PLAN.md)

---

## Status legend

- `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
- **T1** Claude executes autonomously · **T2** Claude executes, Jim reviews · **T3** Claude proposes, Jim approves first
- **C** Claude (research, scripts, automation, browser driving) · **J** Jim (account login, payment, USPTO submission)

Format: `- [status] (tier·owner) ID. Title — short note`

---

## Pre-flight: already done (do not redo)

- [x] Z-1 Apple App Store search — Mitchell's "Brush Quest" identified, captured in `conflict-apple.md`
- [x] Z-2 Google Play Store search — no name conflict found (we are unique on Android)
- [x] Z-3 USPTO TESS preliminary — no public mentions of "Brush Quest" filing (manual verification still required, see Phase 1)
- [x] Z-4 WIPO preliminary — no public mentions; manual verification deferred
- [x] Z-5 Domain + social handle scan — captured in `handles.md`
- [x] W-1 strategic decision pager — captured in `conflict-decision.md`. Direction: do not contact Mitchell, file our own trademark, lock assets, differentiate positioning.

---

## Phase 1 — Lock available brand assets (do TODAY)

> Cheap, fast, parallel. Buy / reserve everything available before any further public action that might tip Mitchell off.

### 1A — Domain registrations ✅ COMPLETED 2026-04-28 (registered via Squarespace, $100 total — see [`domains-owned.md`](domains-owned.md))

- [x] (T1·J/C) **1A-1.** `brushquest.io` registered via Squarespace ($60 first year, renews 2027-04-28). Redirect to `.app` pending DNS config.
- [x] (T1·J/C) **1A-2.** `brushquest.games` SKIPPED — TLD adoption low, redirect-only ROI doesn't justify cost.
- [x] (T1·J/C) **1A-3.** `brushquest.co` registered via Squarespace ($40, renews 2027-04-28). Redirect to `.app` pending DNS config.
- [x] (T1·J/C) **1A-4.** `.net`, `.org`, `.xyz` skipped (defensive only, low priority).
- [x] (T1·C) **1A-5.** ✅ 2026-04-28: 301 redirects configured for `brushquest.io` and `brushquest.co` → `brushquest.app` via Squarespace Domain Forwarding (Permanent Redirect, paths removed). Propagation 24-48h. Auto-renew confirmed ON for all 3 domains.

### 1B — Social handle reservations (free)

- [x] (T1·J/C) **1B-1.** YouTube `@brushquest` ✅ created 2026-04-28 under jim@anemosgp.com (Workspace) — channel ID `UCbUHw1KTsUp_I36RKlhEKyA`. Recorded in REGISTRY §5b. Profile content + brushquest.app link still TODO.
- [x] (T1·J/C) **1B-2a.** GitHub `anemosgp` org ✅ created 2026-04-28 under Jim's GitHub account. Recorded in REGISTRY §5b. Org README + repo migration plan still TODO.
- [ ] (T1·J) **1B-2b.** GitHub `brushquest` username — DEFERRED. Requires separate GitHub account; defensive value only matters if we ship public OSS. Revisit post-USPTO grant when reclaim via trademark dispute is available.
- [ ] (T1·J/C) **1B-3.** LinkedIn: create `linkedin.com/company/anemosgp` company page (studio level, parent company of all products). Brush Quest does NOT need its own LinkedIn page yet.

### 1C — Visual audit of taken `@brushquest` social handles

> Quiet observation only — do NOT follow, like, comment, or otherwise reveal interest. Use logged-out browsers or incognito.

- [ ] (T2·C) **1C-1.** Audit `instagram.com/brushquest` profile in incognito. Capture: bio, post count, follower count, last post date, linked website. Save findings in `handles.md`.
- [ ] (T2·C) **1C-2.** Same for `twitter.com/brushquest`, `tiktok.com/@brushquest`, `threads.net/@brushquest`, `reddit.com/user/brushquest`, `facebook.com/brushquest`.
- [ ] (T2·C) **1C-3.** Update `handles.md` with owner identification for each. If any handle clearly belongs to Mitchell Pothitakis, flag for special handling (don't engage; document for trademark dispute leverage if needed later).
- [ ] (T1·J) **1C-4.** Decision: do we attempt Twitter handle reclaim ($1099 trademark-based release process — only available after our trademark grants)? Defer to post-Phase-2.

---

## Phase 2 — Trademark filing (DIY, USPTO TEAS Plus)

> ~$500 total ($250 × 2 classes). 30-min IP attorney consult deferred at Jim's preference — relying on online research + careful execution. **Do NOT file until 2A-1 (manual TESS verification) confirms no prior filing.**

### 2A — Pre-filing verification (Jim, ~10 min total)

- [ ] (T1·J) **2A-1.** Manual USPTO TESS search at https://tmsearch.uspto.gov/. Search for `brush quest` (with and without space). Save screenshot of results page in `docs/brand/uspto-tess-manual.png`. If any prior filings exist, capture serial number(s) and update `uspto-tess.md` before proceeding.
  - Acceptance: confirmed zero existing filings, OR existing filings documented and re-evaluated against W-1 decision.
- [ ] (T1·J) **2A-2.** Manual WIPO Global Brand Database search at https://branddb.wipo.int/. Same drill, save findings to `wipo.md`.

### 2B — Application content drafting

- [ ] (T2·C) **2B-1.** Draft trademark application content at `docs/brand/tm-application-draft.md`:
  - **Mark:** Standard character "BRUSH QUEST" (word mark, no design — gives broadest protection and easiest to file DIY).
  - **Owner:** AnemosGP LLC (LLC ownership > individual; consult `business-context.md` cross-project for legal-name conventions).
  - **Address:** AnemosGP LLC registered address.
  - **Class 9:** "Downloadable mobile applications for promoting children's dental hygiene; downloadable game software for children featuring toothbrushing instruction; downloadable educational software for children featuring oral hygiene"
  - **Class 41:** "Entertainment services, namely, providing online non-downloadable computer games for children featuring oral hygiene education; providing educational entertainment information in the field of children's dental hygiene via a global communication network"
  - **First use date:** Internal Testing launch (2026-04-21 = first public availability). Use "intent to use" basis if more conservative — but actual first use gives stronger position if challenged.
  - **Specimen of use:** Play Store listing screenshot (live since 2026-04-21 in Internal Testing); update with Production listing screenshot once available.
  - Acceptance: draft saved, all fields complete, ready for USPTO TEAS Plus form entry.
- [ ] (T1·J) **2B-2.** Jim review draft; raise any factual corrections (LLC name spelling, address, dates).

### 2C — File the application

- [ ] (T1·J/C) **2C-1.** Open USPTO Trademark Center at https://trademarkcenter.uspto.gov/. Sign in with myUSPTO account (create if needed — free).
  - Acceptance: signed in, dashboard visible.
- [ ] (T1·J/C) **2C-2.** Start TEAS Plus application. Select word mark format. Enter "BRUSH QUEST". Use draft content from 2B-1.
  - Acceptance: application form complete and validated.
- [ ] (T1·J) **2C-3.** Pay filing fee ($250 × 2 classes = $500). Submit. Save the confirmation email + serial number to `tm-application-receipt.md`.
  - Acceptance: serial number captured, status retrievable at https://tsdr.uspto.gov/.
- [ ] (T1·C) **2C-4.** Update STATUS.md and `tm-status.md` (new file) with filing serial, classes, expected examination date (typically 8-12 months out).

### 2D — Post-filing watch

- [ ] (T1·J) **2D-1.** Calendar reminder: 6-month USPTO check-in. If "Office Action" issued, respond within 6 months (deadline appears on TSDR).
- [ ] (T1·J) **2D-2.** Calendar reminder: 12-month checkpoint. Trademark typically grants ~12 months from filing if no oppositions.
- [ ] (T1·C) **2D-3.** Monthly automated check via TSDR API (or manual login) — note any status changes.

---

## Phase 3 — `brushquest.com` strategy (REVISED 2026-04-28: passive watch, no backorder)

> **2026-04-28 finding:** brushquest.com is actively listed for sale at $2,795 on GoDaddy aftermarket as a "PREMIUM DOMAIN" by the current squatter. Squatters with active listings auto-renew indefinitely (the ~$15/yr renewal is trivial vs. the $2,795 listing). Backorder strategy abandoned — the domain will not drop.

### 3A — Quarterly price monitoring

- [x] (T1·C) **3A-1.** ✅ 2026-04-28: Google Calendar recurring quarterly event created (next: 2026-07-28 09:00 PT, FREQ=MONTHLY;INTERVAL=3). Each check: visit GoDaddy listing, note price, compare to $500 cap.
- [ ] (T1·J) **3A-2.** Decision rule per check: if price ≤ $500, acquire via GoDaddy "Buy It Now". If price > $500, do nothing, wait next quarter.

### 3B — Acquisition (if/when price drops to cap)

- [ ] (T1·J) **3B-1.** Buy domain via GoDaddy aftermarket. AnemosGP LLC account/payment.
- [ ] (T1·C) **3B-2.** Configure 301 redirect `brushquest.com` → `brushquest.app` (Squarespace if transferred there, or wherever it lives post-purchase).
- [ ] (T1·J) **3B-3.** Update marketing assets to reference `.com` as primary OR keep `.app` canonical and `.com` as redirect (Jim's call when it happens).

---

## Phase 4 — Differentiation reinforcement

> Reduce "likelihood of confusion" with Mitchell's app — a legal standard that protects us if a dispute ever arises.

- [ ] (T2·C) **4A-1.** Verify Brush Quest is in Google Play "Education" or "Education > Pretend Play" category, NOT "Health & Fitness" (Mitchell's category). Check current listing; document in `category-positioning.md`.
- [ ] (T2·C) **4A-2.** Same for iOS — confirm Kids Category submission with Education or Games genre, not Health & Fitness.
- [ ] (T2·C) **4A-3.** Audit our public copy for any phrase overlap with Mitchell's. (His app description per `conflict-apple.md`: "transforms the daily brushing routine into an interactive adventure", "character companions", "2-minute timer dividing brushing into six zones", "stars earned per session", "interactive calendar"). Where we have copy similarity, slightly rephrase to lean on our distinctive elements (Space Rangers, Cavity Monsters, etc.).
  - Acceptance: copy audit results saved at `copy-differentiation.md`. Any rephrase recommendations flagged.
- [ ] (T3·C) **4A-4.** If 4A-3 surfaces overlap risks, make Play Store listing edits via the standard Play Console flow — this is a Tier 3 user-facing change requiring Jim's approval.

---

## What's NOT in this plan (handled elsewhere)

- App development, dev cycles, UX iteration → `/cyclepro` workflow
- Production launch decisions → [`../android-launch/PLAN.md`](../android-launch/PLAN.md) Phase 2
- Cross-platform GTM (Nicole-Facebook, Substack) → [`../launch/CROSS-PLATFORM-GTM.md`](../launch/CROSS-PLATFORM-GTM.md)
- Monetization decisions → memory `decision_product_strategy_2026_03.md`

---

## Open questions for Jim

- **Domain registrar preference?** Recommend Cloudflare Registrar (at-cost, no markup, best DNS UI). Alternative: Namecheap (slightly cheaper for some TLDs, separate account).
- **AnemosGP LLC vs. personal for trademark filing?** Recommend LLC — separates personal liability and aligns with Play Console / Apple Business org enrollments. Confirms ownership consolidation.
- **Backorder service for `.com`?** GoDaddy Backorder is simplest for non-pros; SnapNames/DropCatch are for serious domain pros. Recommend GoDaddy.

Trigger to revisit this plan at higher urgency: any signal that Mitchell is reactivating the project (App Store update, social activity, public mention).
