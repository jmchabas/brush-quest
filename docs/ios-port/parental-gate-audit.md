# Parental Gate Audit — Apple Guideline 1.3

**Date:** 2026-04-28
**Source of truth:** Apple App Store Review Guideline 1.3 (Kids Category) + plan task 1F-4.

## Summary

**Result: PASS.** Every code path that opens an external URL, sends an email, starts an account-creation/login flow, or performs an irreversible/destructive action sits behind the math parental gate at `lib/screens/settings_screen.dart:1962`. There are zero unguarded surfaces in the rest of `lib/`.

The audit was done by exhaustive `grep` over `lib/**/*.dart` for `url_launcher` / `launchUrl` / `mailto:` / `Intent` / `signIn` / Apple/Google sign-in entry points / external HTTP calls.

## Audit method

```bash
grep -rn "url_launcher\|launchUrl\|launchUrlString\|mailto:\|http://\|https://" lib/
grep -rn "openEmail\|sendEmail\|share\|Intent\|canLaunchUrl" lib/
grep -rn "rate\|share\|review\|credit\|about\|@brushquest\|support\|contact" lib/
```

## Surfaces found

| Surface | Location | Gating mechanism | Status |
|---|---|---|---|
| Privacy Policy link → `brushquest.app/privacy-policy.html` | `settings_screen.dart:867` (method `_openPrivacyPolicy`), wired at `:262` and `:1555` | Inside Settings, behind `_parentUnlocked` math gate at `:1962` | ✅ Gated |
| Terms of Service link → `anemosgp.com/terms.html` | `settings_screen.dart:874` (method `_openTermsOfService`), wired at `:1568` | Inside Settings, behind `_parentUnlocked` | ✅ Gated |
| Google Sign-In | `settings_screen.dart` (Account section) → `AuthService().signInWithGoogle()` | Inside Settings, behind `_parentUnlocked` | ✅ Gated |
| Apple Sign-In (iOS only) | `settings_screen.dart:1242` → `AuthService().signInWithApple()`, gated by `AuthService().isAppleSignInAvailable` | Inside Settings, behind `_parentUnlocked` (iOS additionally hides on non-iOS devices) | ✅ Gated |
| Save to Cloud (Firestore upload) | Settings → Account section | Inside Settings, behind `_parentUnlocked` | ✅ Gated |
| Restore from Cloud | Settings → Account section | Inside Settings, behind `_parentUnlocked` | ✅ Gated |
| Reset All Progress (irreversible) | Settings → Other section, with confirmation dialog | Inside Settings, behind `_parentUnlocked` | ✅ Gated |
| Replay Tutorial | Settings → Other section | Inside Settings, behind `_parentUnlocked` | ✅ Gated |

## Surfaces explicitly NOT in the codebase (verified absent)

These would have required separate gating if present, but are not implemented:

- ❌ "Rate the App" link (App Store deeplink) — not present
- ❌ "Share with friend" link — not present
- ❌ "Email support" / `mailto:` link — not present (support email is in the privacy policy + App Store listing only)
- ❌ "Credits" / "About" screen with external links — not present
- ❌ In-app purchases — not implemented (free, no IAP for v1)
- ❌ Ads SDK — not present (Kids Category)
- ❌ Web view embedding external content — not present

## Gating mechanism

`SettingsScreen` (`lib/screens/settings_screen.dart`) renders one of two states:

- `_parentUnlocked == false` → `_buildParentGate()` shown (math challenge: `$_mathA × $_mathB = ?`, `_mathA` ∈ [4,9], `_mathB` ∈ [3,7], product range 12–63 — beyond what a 6–8 year old can trivially solve).
- `_parentUnlocked == true` → full Settings UI (all the surfaces in the table above).

State transitions:
1. App resumes Settings → `_parentUnlocked` reset to `false` and a fresh math challenge generated.
2. Wrong answer → field cleared, new challenge generated, `_mathError = 'Try again!'`.
3. Correct answer → `_parentUnlocked = true`, inactivity timer started.
4. Inactivity timeout or app backgrounding → re-locks (returns to step 1 on resume).

## Open follow-up

Plan task **1F-5** (math gate widget test) closes the testing gap by exercising:
- wrong answer rejected, fresh challenge generated;
- correct answer unlocks the rest of Settings;
- input filtering (digits only).

## Re-run instruction

Re-run this audit before any pre-submission build by repeating the three `grep` commands above. If a new surface appears outside `settings_screen.dart` that opens an external URL, sends an email, or starts an account/sign-in flow, it MUST be wrapped in its own parental gate or moved into Settings before submission.
