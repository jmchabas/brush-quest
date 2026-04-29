# Cross-Platform Account Linking — Decision

**Plan task:** 1Q-1
**Status:** APPROVED 2026-04-28.
**Date:** 2026-04-28

## The question

When a child uses Brush Quest on Android (signed in with Google) and the same family later installs on iOS (signs in with Apple), should the two sign-ins resolve to **the same Firebase user** (account linking) or **two separate Firebase users** (no linking)?

## Decision

**No linking for v1.** Rely on Firebase Auth's stable per-provider UID: same Google account on iOS and Android resolves to the same Firebase user automatically (no code needed). Same Apple ID across iPhones — same Firebase user. The cross-provider case (Apple on iOS + Google on Android, same person) is rare in our target audience and is not promised in v1.

### Why this turned out simple

The original framing assumed "Apple-on-iOS + Google-on-Android" would be the dominant cross-platform pattern, with linking required to bridge them. In practice:

- Most users don't own both an iPhone AND an Android — single-OS households are the norm.
- iOS users frequently choose Google Sign-In as the primary because Google is their everyday account; Apple Sign-In is offered to satisfy Apple Policy 4.8 but isn't typically picked by users who care about cross-device.
- Apple Sign-In on Android is technically possible but UX-painful — users who chose Apple on iOS generally stay in iOS.

So the realistic happy path is Google-on-both → Firebase UID stable → "just works" with zero linking code.

### iOS button order

Google appears FIRST on iOS, Apple Sign-In second. Both are visible to satisfy Apple Policy 4.8, but Google is presented as the primary because it serves the dominant cross-device pattern. Implemented at `lib/screens/settings_screen.dart:1240`.

### Settings copy

No new cross-device-mechanics note added. The existing subtitle "Save your progress to the cloud" stays — it's a passive call-to-action without making cross-platform claims that would mislead users in the rare cross-provider case.

## Why no linking

| Concern | No linking (recommended) | Linking |
|---|---|---|
| **Implementation complexity** | None — Firebase default | Requires `linkWithCredential` flow + email verification UX + conflict-resolution UI when both accounts already have data |
| **Apple Kids Category review** | Simple — no extra UX surface to justify | More UX surface = more reviewer questions |
| **Email collisions** | Apple's "Hide my Email" relay (`@privaterelay.appleid.com`) makes email-based linking unreliable | Linking by email breaks if user picks Hide-my-Email |
| **Parental consent** | Each sign-in is a discrete consent event | Linking implicitly merges identities — needs additional disclosure |
| **Data loss risk** | None — both users persist independently | If linking conflict resolution picks "wrong" account, kid's progress can vanish |
| **Save sync experience** | Parent picks one method per child; works fine if used consistently | "Just works" cross-platform IF the linking succeeds; broken UX when it doesn't |
| **Future flexibility** | Easy to ADD linking in v1.1+ if real users complain | Hard to REMOVE linking once parents rely on it |

## What "no linking" looks like to the user

1. **Onboarding (existing):** parents see Settings explanation that signing in is optional and only needed for cross-device sync.
2. **Settings UX (proposed minor copy add):** below the Apple/Google sign-in buttons, add a 1-line note:
   > Sign in with the same method on each device (Apple on iPhone/iPad, Google on Android) for cloud save sync.
3. **No "merge" or "link" UI** anywhere in the app for v1.

## Cross-platform sync test (deferred to 1Q-2 / Phase 2)

Once a TestFlight build is in hand:

1. On Android: sign in with Google account `acct-A`. Earn a few stars. Verify Firestore `/users/<acct-A-uid>` reflects the progress.
2. On iPhone Simulator: install via TestFlight. Sign in with the **same** Google account (Google Sign-In is available on iOS too, just less common in Kids Category UX). Verify the same `/users/<acct-A-uid>` document is read and progress matches within ~2 seconds.
3. Do NOT test Apple-on-iOS + Google-on-Android with the "same person" expectation. That's the case our v1 doesn't promise to handle.

## Data model implication

`/users/{uid}` Firestore path stays one-doc-per-Firebase-user. No schema change. The only thing we tell parents in copy is "use the same sign-in method on each device."

## Open follow-ups (post-v1)

- If TestFlight users complain about cross-platform progress not syncing → revisit linking in v1.1 with a proper consent flow and conflict resolution UX.
- If a child genuinely needs progress to follow them across Android Google → iOS Apple, the v1 workaround is: parent signs in with **Google** on the iPhone too (Google Sign-In works on iOS via `google_sign_in_ios`).

## Sign-off

Jim approved 2026-04-28. iOS Settings button order swapped to Google-first; no new copy added; 1Q-2 (cross-platform sync test) runs on first TestFlight build.
