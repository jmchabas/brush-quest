# Meta-PRD — Attribution schema: Firestore shape + UTM taxonomy + Play Install Referrer

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bet:** T1c — brushquest.app/rangers landing + UTM attribution + CSV-to-inbox tester pipeline (ROOT of this node)
**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

What is the deterministic Firestore schema + UTM taxonomy + Play Install Referrer wiring that makes the "qualified install" query (`parent_email_captured=true AND play_tester_enrolled=true AND first_brush_timestamp IS NOT NULL within 72h`) joinable across email-capture, tester-CSV-upload, and first-brush — for both internal-testing and public-install modes — and survives a mid-sprint Play review clearance?

## Why this isn't PRD-executable now

Missing criterion 3 (inputs named + located) and 5 (tools exist/flagged) at the foundational level. Without this schema, every other PRD in the node is narrative-only.

- **Firestore collections don't exist yet** for `parents/` and `testers/` as separate logical entities. Current app writes `users/{uid}` (post-sign-in). The attribution schema must cover the PRE-install flow (email captured on landing, before any Firebase Auth uid exists) and later stitch to the post-install uid.
- **UTM round-trip path is not wired.** Landing needs JS that (a) reads `utm_source/medium/campaign/content` from query string, (b) writes them to the `parents/{parent_id}` doc with the email, (c) echoes a `parent_id` into localStorage or a hidden Buttondown field so re-clicks don't double-count.
- **Play Install Referrer API** (Google's official channel for joining Play installs back to click-source) is NOT wired in the Flutter app. Requires a native Android plugin or a Flutter package (`install_referrer` exists but has maintenance risk). Needs to be integrated + tested in dev before the landing assumes it works.
- **Play Console internal-tester CSV format** — the actual columns Jim uploads each morning — is not yet documented for agent consumption. What field is the email in, what's the date format, what triggers the "tester enrolled" state in Play Console (accept vs. invited).
- **Public-install mode vs. internal-testing mode:** two attribution paths. When Play review clears mid-sprint, the landing flips from "join early access" (email → CSV → Play Console add → Play Store link) to "install now" (direct Play Store link with install-referrer). Schema must support both shapes without a migration.
- **Privacy/COPPA:** UTM + parent email stored in Firestore. Must not accidentally capture child data. Retention policy? GDPR delete-request handling if a parent asks?

## What the child loop must produce

1. **Firestore schema document** for:
   - `parents/{parent_id}` — shape: `email` (string, indexed), `utm` (map: source/medium/campaign/content/term), `landing_session` (timestamp), `ios_waitlist` (bool), `consented_marketing` (bool), `created_at`, `locale`.
   - `testers/{parent_id}` — shape: `play_tester_enrolled_at` (timestamp, null until Jim runs the CSV upload), `play_console_status` (string: invited/accepted/unknown), `parent_id` (ref).
   - `install_events/{event_id}` — shape: `parent_id` (best-effort match), `install_referrer_raw` (string, from Play Install Referrer API), `utm_source/medium/campaign/content` (parsed from referrer), `first_brush_timestamp` (timestamp), `firebase_uid` (if/when user signs in), `linked_to_parent_at` (timestamp when the match closes).
   - Join key and linking rules: how does `install_events.install_referrer_raw` connect back to `parents.utm`? Pick one: (a) match on the `parent_id` baked into the UTM's `content` field (my recommendation); (b) match on email if user signs in with the same email; (c) probabilistic match on UTM tuple within 7-day window.
2. **UTM taxonomy document** — the canonical list of allowed values.
   - `utm_source`: `{buttondown, pta, reddit, ig_creator, ig_cold, jim_personal_ig, substack, dentist_poster, qr_offline, direct, unknown}` (union of Tier-1/2/3 + unknown).
   - `utm_medium`: `{email, sms, social_post, social_bio_link, qr, manual}`.
   - `utm_campaign`: pattern — `<channel>_<YYYY_MM>` (e.g. `warm_sweep_2026_04`, `creator_proxy_2026_04`).
   - `utm_content`: per-channel slug (writer name, creator handle, subreddit, pta-cohort, etc.).
   - **Strict allowlist** enforced at landing-JS write time. Unknown values write to `utm_raw` but don't match the canonical fields.
3. **Landing-JS attribution flow** (pseudocode + endpoint spec):
   - On page load: read query params → persist to localStorage with timestamp.
   - On email submit: POST to a Cloud Function `/capture-parent` with `{email, utm, client_session_id}` → Cloud Function writes `parents/{parent_id}`, returns `parent_id` → landing stashes `parent_id` in localStorage.
   - Consent surface: checkbox "I'm okay with you emailing me about Brush Quest updates" — unchecked = `consented_marketing=false` but row still written for attribution.
4. **Play Install Referrer wiring plan:**
   - Which Flutter package (or native plugin) do we use? `install_referrer` package? Custom?
   - Version + dependency review against the Flutter 3.10.4 floor.
   - Dev-build + test plan on a burner Android device.
   - Mapping: raw referrer string → parsed UTM fields → Firestore `install_events` doc.
5. **The "qualified install" query — literal Firestore query code:**
   ```
   SELECT parent_id FROM parents
   WHERE parent_email_captured = true
     AND parent_id IN (SELECT parent_id FROM testers WHERE play_tester_enrolled = true)
     AND parent_id IN (SELECT parent_id FROM install_events WHERE first_brush_timestamp IS NOT NULL
                        AND first_brush_timestamp - landing_session <= 72h)
   ```
   Written as actual Firestore composite-query code (Firestore doesn't do IN/JOIN like SQL — needs a Cloud Function or denormalized `qualified_install` boolean on `parents`).
6. **Privacy + retention rules:**
   - Parents can request deletion via email. Delete fires a Cloud Function that removes `parents/{parent_id}` + `testers/{parent_id}` + `install_events` where parent_id matches. Email is the only PII; no child data stored on these docs.
   - 24-month retention; scheduled delete for `consented_marketing=false` rows older than 24 months.
7. **Public-install-mode switch design:** a config flag (`landing_mode: "early_access" | "public"`) that controls copy + CTA target. Schema stays identical — both modes write to `parents/` → `install_events/`.

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Yes — Synth-final §8.2 pins the Firestore query | Child loop writes the literal query |
| 2. Context fully specified | No — schema, landing-JS, Cloud Function all undefined | Child loop produces all three |
| 3. Every input named + located | No — Firestore collection names, Cloud Function endpoints, Play Install Referrer package not chosen | Child loop names each |
| 4. Acceptance criteria checkable | No — "attribution works" is not a checkbox; need the literal query | Child loop converts to code-level acceptance |
| 5. Tools exist OR flagged TO-BUILD | Partial — Firebase exists; Play Install Referrer plugin is TO-BUILD-integrate | Child loop specifies package + integration plan |
| 6. Escalation triggers | Partial — Day-3 kill-gate exists but query-break escalation not wired | Child loop adds Firestore health-check triggers |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** nothing within this node (this is the root).
- **Blocks:** everything. `PRD-GTM-instagram-reels-001` (landing), `PRD-GTM-instagram-reels-005` (UTM round-trip test), AND indirectly all other PRDs that need UTM-tagged links (-002 Reddit, -003 creator brief, -006 warm sweep, -007 Substack).
- **Sibling:** `_meta-prd-buttondown-firebase-bridge.md` — Buttondown webhook handoff into this same Firestore schema.

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.2: the "qualified install" definition is LOCKED. Any child-loop schema must make this query deterministic, or it's failing the charter.
- §8.11: Day-3 zero-install kill-gate needs a real-time dashboard OR a daily cron reporting install-counts to Jim.
- §8.12: Play Install Referrer MUST ship on Day 1 with the landing. Retrofitting post-public-review is not allowed.
- §8.13: iOS waitlist capture is part of the same schema (add `ios_waitlist: bool` to `parents/{parent_id}`).
- §8.15: any Firestore schema change is a Jim-approval item; the child loop produces the proposed schema, Jim signs off once.

## Rough size estimate for the child loop

Large. ~16–24 hrs agent time. This is real engineering — Firestore schema decisions, Cloud Function code, Play Install Referrer native integration, landing-JS. Almost certainly needs a round of A/B/C evals on the `parent_id` linking rule (option A/B/C in §Child loop produces point 1). Probably produces multiple PRDs out the other side: the landing-JS PRD, the Cloud Function PRD, the Play Install Referrer integration PRD, the schema-doc-as-single-source-of-truth reference file.
