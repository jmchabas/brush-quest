# Delete Account UX — Proposal (Apple Guideline 5.1.1(v))

**Plan task:** 1G-1
**Status:** Proposal awaiting Jim approval (Tier 3).
**Date:** 2026-04-28

## Why

Apple Guideline 5.1.1(v): apps that support account creation MUST also support in-app account deletion. The deletion path must be reachable inside the app, NOT routed to an email-the-support-team workflow. Reviewers explicitly check this in the Kids Category.

## Proposed UX

### Placement

Settings → Account section (already gated by the math parental gate at `_buildParentGate`). New `Delete Account` button below the existing **Save to Cloud** / **Restore from Cloud** / **Sign Out** buttons.

```
ACCOUNT
─ Signed in as: parent@example.com
─ [Save to Cloud]    [Restore from Cloud]
─ [Sign Out]
─ [Delete Account]   ← new (only visible when signed in)
```

Visual treatment: red text + outlined border (existing destructive-action style — same as **Reset All Progress**). Hidden entirely when not signed in (no Firebase user → nothing to delete on the auth side, and Reset All Progress already covers local-only data).

### Confirmation dialog

Two-step. Single tap on a destructive action is not enough.

**Step 1** — first tap shows AlertDialog:

> **Delete your account?**
>
> This will permanently delete:
> • Your saved heroes and weapons
> • Your stars and Ranger Rank
> • Your brushing streak history
>
> Your child's local progress on this device WILL ALSO BE CLEARED.
> This action cannot be undone.
>
> [Cancel]   [Delete Account]

**Step 2** — second tap (on `Delete Account`) shows a loading spinner overlay with text "Deleting account…" while the deletion runs. No additional confirmation needed at this point — Apple's guidance is one explicit confirmation, not two.

### Success state

After successful deletion:

- Show a SnackBar: **"Account deleted. Your data has been removed."**
- Auto-navigate to home screen (with the child seeing onboarding-or-home depending on `seen_onboarding` SharedPreferences key — which we KEEP, so the child doesn't have to re-do tutorial).
- The child can keep using the app as a "guest" (not signed in) and earn fresh progress.

### Failure modes

| Failure | Detection | UX response |
|---|---|---|
| Apple SIWA token revoke fails (network or key-config error) | `revokeAppleToken` Cloud Function returns non-200 | SnackBar: "Couldn't reach Apple to revoke sign-in. Try again on a stable connection." Local data NOT deleted. |
| Firestore document delete fails | `delete()` throws | SnackBar: "Couldn't delete cloud data. Try again." Local data NOT deleted. |
| Firebase `deleteUser()` fails | throws | SnackBar: "Account couldn't be deleted. Try again or contact support@brushquest.app." Local data NOT deleted. |
| Local `shared_preferences` clear fails | throws (rare) | Continue silently — user is signed out and Firebase user gone, local artifacts are minor inconvenience |

**Ordering of the deletion pipeline matters.** Apple revoke first (we can't recover this if later steps fail; better to leave Firebase user in place and let the user retry). Then Firestore doc. Then Firebase Auth user. Then local prefs.

### What does NOT get deleted

- `seen_onboarding` flag (we keep so the child isn't forced through tutorial again).
- App-level CYCLE-PROTECT or analytics state on Android (analytics already runtime-gated to `Platform.isAndroid` and is not user-attributable).
- Anonymous brushing telemetry (we don't collect any).

### Apple Sign-In specific

For users signed in with Apple, the SIWA refresh token MUST be revoked at Apple's side (`https://appleid.apple.com/auth/revoke`) — Firebase `deleteUser()` does NOT do this on its own. The `revokeAppleToken` Cloud Function (1G-3, currently a stub) handles the call. Without revocation, the user keeps appearing in **Settings → Apple ID → Apps Using Apple ID** with our app listed, which is exactly the Guideline 5.1.1(v) failure pattern.

## Out of scope (for v1)

- "30-day grace period" / soft-delete with restore. Apple does not require this; Firebase doesn't support it natively. Keep deletion immediate + permanent.
- Multi-device sync of deletion (other signed-in devices will detect the absent user document on next launch and reset to guest state — this is fine).
- Email-the-user-a-confirmation. We don't email at all from this app.
- Child-initiated deletion. The math parental gate prevents this — only an adult who can solve `8 × 7 = ?` can reach this button.

## What we need before shipping (sequencing)

1. **Jim approves this UX** (you, reading this).
2. **1G-2** wires up `AuthService.deleteAccount()` calling: `revokeAppleToken` (if Apple) → Firestore `/users/{uid}` delete → Firebase `deleteUser()` → local `shared_preferences` clear.
3. **1G-4** wires the Settings button to call `deleteAccount()` and shows the dialogs above.
4. **2A-3** replaces the `revokeAppleToken` stub with the real Apple-side call (after Apple Developer Program enrollment).
5. **1V-5** integration test exercises the full flow with mocked Firestore + Auth + HTTP.
6. Jim does a hand-walk on TestFlight before the App Store submission (mandatory — destructive flow needs human verification).

## Open questions for Jim

1. **Wording of the destructive-action button:** "Delete Account" (clinical) vs "Delete My Account" (more personal) vs "Erase Everything" (more honest about scope) — pick one.
2. **Should we KEEP the local heroes/weapons after Firebase deletion?** Current proposal: clear them. Reasoning: aligns with "permanently delete" promise; otherwise the child would be confused why their stars persist after the parent said "delete account".
3. **Should the button be visible to parents of UN-signed-in users?** Currently hidden — there's nothing to delete. Alternative: show but route to "Reset All Progress" (which exists). This would clutter Settings; recommend NOT doing it.
