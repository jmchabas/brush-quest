# Meta-PRD — Play Publishing API tester-list auto-enroll (replace manual CSV)

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bet:** T2g — replace Jim's daily CSV-to-inbox upload with service-account API write
**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

Can a Google Cloud service account, via the Play Publishing API (`androidpublisher.v3`), edit the internal-testing tester-email list on the `com.brushquest.brush_quest` app in a way that reliably replaces Jim's nightly CSV upload — within the 14-day sprint — and if not, what's the honest scope reduction?

## Why this isn't PRD-executable now

Missing criterion 3 (inputs named) and 5 (tools exist/flagged). Also, this bet is INTENTIONALLY Tier-2 because it's a "nice to have" that de-risks Jim-hours on T1c. Synth-final §2 explicitly demoted auto-enroll from T1c and made it T2g, with a park-trigger if it throws or the service account can't write.

- **Service account provisioning** on Google Play Console is not currently done. Needs linking a GCP project (probably the existing Firebase/`brush-quest` project), granting the service account Play Console access, and confirming the scope allows `androidpublisher.v3.edits.testers` or equivalent.
- **Play Publishing API's tester-list endpoint** semantics are non-obvious. Does it accept individual email adds, or only full-list replace? If replace-only, we need to pull current list, diff, re-upload — more brittle than CSV.
- **Permission model:** the Play Console org is VERIFIED under jim@anemosgp.com. Service-account access might require elevated role that conflicts with least-privilege.
- **Quotas:** the API has per-day edit quotas. At 2–10 testers/day scale we're fine, but we need to know.
- **"Throws before Day 7" kill criterion** (Synth-final §4 T2g) — we need a specific failure signal, not just "felt flaky."
- **Testing path:** can we test this safely without polluting the real tester list? Probably needs a sandbox app OR acceptance of "write once to real list, verify, rollback if bad."

## What the child loop must produce

1. **Feasibility assessment:**
   - Does `androidpublisher.v3` expose a tester-list-edit endpoint? Confirm from Google's API reference + changelog.
   - What's the minimum scope needed? (`androidpublisher` root vs. finer-grained?)
   - Is the endpoint rate-limited in a way that breaks our 2–10 adds/day use case? (Almost certainly fine.)
2. **Service account setup checklist:**
   - Which GCP project hosts the service account? (Existing `brush-quest` Firebase project.)
   - What IAM role + Play Console role does it need?
   - Key rotation policy.
3. **Code spec** — a Cloud Function or local script that:
   - Reads the nightly Firestore CSV-export (produced by T1c — the same data that currently feeds Jim's inbox).
   - Filters for new emails since last run (dedup).
   - Calls `androidpublisher.v3.edits.testers.update` (or equivalent) to add each.
   - Writes a confirmation row to Firestore `testers/{parent_id}.play_tester_enrolled_at`.
4. **Fallback path:** if the API edits succeed, update `testers.play_console_status = "accepted-via-api"`. If it throws, update `testers.play_console_status = "api-failed-fallback-csv"` and cc the nightly CSV email to Jim as before.
5. **Acceptance test:**
   - One dry-run add of a burner email to the internal-tester list via the API.
   - Verify it appears in Play Console UI.
   - Verify burner device can accept the invitation and install.
6. **"Throws before Day 7" specification:**
   - 3 consecutive failed API calls in 24h OR any auth-scope denial response → park T2g, fall back to CSV.
   - Log to `_data/t2g_status.yaml`.

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Partial — "replace CSV" is the goal; need quantitative acceptance | Child loop: "100% of Firestore email-capture rows reach Play Console tester list within 12h, for 7 consecutive days" |
| 2. Context fully specified | No — service account not set up, endpoint not confirmed | Child loop produces setup doc + endpoint confirmation |
| 3. Every input named + located | No — no service account key, no IAM role | Child loop names each |
| 4. Acceptance criteria checkable | Partial | Child loop formalizes |
| 5. Tools exist OR flagged TO-BUILD | No — Play Publishing API client integration is TO-BUILD | Child loop scopes |
| 6. Escalation triggers | Partial — Synth-final §4 T2g has kill criterion | Child loop adds in-flight triggers (quota hit, auth revoked) |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** `PRD-GTM-instagram-reels-001` (landing + nightly CSV export exist and are stable). Without that data source, T2g has nothing to consume.
- **Depends on:** `_meta-prd-attribution-schema.md` (`testers/{parent_id}` collection exists).
- **Blocks:** nothing critical. T2g is explicitly a Jim-hours-optimization play. If it doesn't ship, the sprint still works via CSV.
- **Informs:** post-sprint automation — if T2g works, it makes future campaigns (post-public-review) much cheaper to run.

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.3: T2g does NOT gate T1c; T1c's CSV-to-inbox is the baseline and must ship regardless.
- §8.11: Day-3 zero-install kill-gate applies to the landing funnel, not to T2g. If T2g is broken on Day 3, the CSV path covers.
- §8.15: any service-account or Play Console permission change = Jim-approval. Jim logs into Play Console to grant permissions; agent does not.

## Rough size estimate for the child loop

Small. ~4–6 hrs agent time. This is a well-scoped engineering task. The main unknowns are (a) does the API support individual-add vs. replace-all, and (b) does the service-account permission model cooperate. Most of the loop is research + a dry-run acceptance test. Does not need A/B/C evals; a single synth + test is enough.
