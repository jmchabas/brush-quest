# Meta-PRD — Buttondown ↔ Firebase/Firestore bridge

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bet:** T1c — brushquest.app/rangers landing (component: email-capture → Firestore sync)
**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

How does an email captured on `brushquest.app/rangers` get simultaneously added to Buttondown (so it can be re-emailed later) AND written to Firestore `parents/{parent_id}` (so it can be joined to install + brush events for the qualified-install query), in a way that doesn't lose data if either system is down, doesn't double-add, and is compliant with consent/marketing rules?

## Why this isn't PRD-executable now

Missing criterion 3 (inputs + tools) and 5. The landing PRD (-001) can't ship until this bridge is designed.

- **No existing Buttondown webhook integration.** Buttondown supports outbound webhooks (subscriber created / updated / unsubscribed events) but we haven't registered one.
- **No Cloud Function** currently receives Buttondown events and writes to Firestore. Must be built.
- **Consent state** is captured on the landing but must be reconciled with Buttondown's own opt-in model. Buttondown may double-opt-in (confirmation email) by default — does that block the parent from completing the early-access flow while waiting to confirm? Probably needs confirmation disabled for this flow OR the landing must surface "check your email" as a UX step.
- **Dual-write race condition:** if landing writes to Buttondown first, then Firestore, and Firestore write fails, we have a Buttondown subscriber with no Firestore row (can't attribute). Need a transactional pattern OR a single source-of-truth-then-sync pattern.
- **Unsubscribe handling:** when a parent unsubscribes in Buttondown, Firestore must be updated too (`consented_marketing=false`) — requires the webhook in reverse direction.
- **Rate limits:** Buttondown API limits + Cloud Function cold-start latency could break the landing's submit UX if the bridge is synchronous.

## What the child loop must produce

1. **Architecture decision — which system is source of truth?**
   - Option A: **Firestore-first**, Buttondown second via a Cloud Function webhook FROM Firestore. Cleanest for attribution; Buttondown sync is eventually consistent. Single-write on the critical path.
   - Option B: **Landing hits Cloud Function**, which writes Firestore AND calls Buttondown API in the same function. Dual-write with retries on failure. More code, more failure modes.
   - Option C: **Buttondown-first**, Firestore second via Buttondown's outbound webhook to a Cloud Function. Leaves Firestore briefly out-of-sync; breaks the "show user their parent_id immediately" UX.
   - Recommendation + reasoning.
2. **Cloud Function spec** — the HTTPS function(s) that handle:
   - `/capture-parent` — inbound from landing. Writes Firestore, triggers Buttondown add.
   - `/buttondown-webhook` — inbound from Buttondown. Handles subscriber.unsubscribed event, updates Firestore.
3. **Buttondown configuration checklist:**
   - Disable double-opt-in for the `/rangers` signup source? OR keep it and update landing UX to say "check email."
   - Tag new subscribers with source tag (`rangers_landing`) so Buttondown segments are clean.
   - Outbound webhook URL registered + secret configured.
4. **Failure-mode matrix:**
   - Firestore down → landing shows retry prompt; submission stored in localStorage until retry succeeds.
   - Buttondown down → Firestore row still written; background sync retries Buttondown; parent still enters the funnel.
   - Cloud Function cold start >3s → landing shows spinner with "1 sec…" copy; hard-fails after 10s to `tg send` escalation.
   - Webhook replay attack → Cloud Function validates Buttondown webhook signature.
5. **Privacy + compliance:**
   - Parent consent checkbox → `consented_marketing` flag → only `true` parents are added to Buttondown's general list (`false` ones are Firestore-only for attribution).
   - GDPR/CCPA delete request → one endpoint fans out to both systems.
6. **Testing plan:**
   - Unit tests on Cloud Functions (happy path, Buttondown down, Firestore down, replay).
   - Integration test: submit email on staging landing → row appears in Firestore + Buttondown within 30s.
   - Burner-email round trip test that's the preamble to PRD-005's burner-phone UTM round-trip.

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Partial — "emails end up in both systems" is informal | Child loop defines success rate (≥99% over 100 submissions) |
| 2. Context fully specified | No — Cloud Function code, Buttondown config, failure modes undefined | Child loop produces all of these |
| 3. Every input named + located | No — no webhook URL, no secret, no function endpoint | Child loop names each |
| 4. Acceptance criteria checkable | No — converts to a test plan with numeric success thresholds | Child loop writes the tests |
| 5. Tools exist OR flagged TO-BUILD | Partial — Firebase exists, Buttondown API exists, Cloud Function TO-BUILD | Child loop scopes the build |
| 6. Escalation triggers | No | Child loop adds "webhook dead >1h" / "Buttondown<>Firestore drift >5%" |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** `_meta-prd-attribution-schema.md` — `parents/` schema must be defined first; this bridge writes to it.
- **Blocks:** `PRD-GTM-instagram-reels-001` (the landing can't submit-and-sync without this bridge live).
- **Informs:** `PRD-GTM-instagram-reels-005` (UTM round-trip test relies on this bridge working end-to-end; the burner-phone test includes verifying the email lands in both Firestore + Buttondown).
- **Informs:** `PRD-GTM-instagram-reels-006` (warm sweep's Buttondown email send benefits from the `rangers_landing` tag created here).

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.3: T1c gates all other lanes. This bridge is part of T1c; it must be live before Day 3.
- §8.4: banned words apply to the Buttondown welcome/confirmation email too — review that copy during setup.
- §8.11: Day-3 zero-install kill-gate — if this bridge is quietly failing, we'd see a zero. The bridge must have a health dashboard OR a daily cron reporting drift.
- §8.15: Firestore schema changes + money-out (Buttondown is free at current scale but worth knowing) = Jim-approval.

## Rough size estimate for the child loop

Medium. ~6–10 hrs agent time. Mostly engineering spec work; the hard questions are failure-mode ordering (dual-write semantics, eventual-consistency direction) and the Buttondown double-opt-in UX call. One or two rounds of L3/L4 research on production dual-write patterns (outbox pattern, saga, eventual-consistency-first). Probably does not need a full A/B/C eval; evaluator would mostly flag missing failure modes, which we can list explicitly.
