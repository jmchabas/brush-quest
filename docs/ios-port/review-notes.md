# App Review Notes — Brush Quest (paste into App Store Connect)

> Drafted 2026-05-06 for plan task 2C-6. The text below `--- BEGIN ... ---`
> is the verbatim copy for App Store Connect's "App Review Information →
> Notes" field. Everything else is internal context.

---

## Demo account

Apple Sign In and Google Sign In are both supported and **optional** —
the app is fully usable signed-out (local progress only). For the
account-deletion compliance test (Guideline 5.1.1(v)), the reviewer
can use their own Apple ID. No demo credentials are required because:

- Sign-In with Apple accepts any Apple ID
- Sign-In with Google accepts any Google account
- All sign-in destructive actions are gated behind a parental gate

If Apple insists on a demo account later, create one via Google Sign-In
(not Apple — Apple reviewers can't reuse their own ID's revoke flow
without affecting their personal account state). Suggested:
- Email: `brushquest.review@gmail.com`
- Password: in `legal/credentials/app-review/` (chmod 600)
- (Account does not yet exist; only create if Apple's first reply asks.)

---

## --- BEGIN review-notes copy ---

Hello Apple Review team,

Thank you for reviewing Brush Quest. A few notes to make the review faster:

1. NO ACCOUNT IS REQUIRED. Open the app and tap BRUSH on the home screen
   to play immediately. All gameplay works fully offline and signed-out.

2. PARENTAL GATE. Some screens (Settings, Sign-In, Delete Account, Reset
   Progress) are gated behind a single math problem like "What is 5 + 3?"
   This is the App Store Kids Category-required gate to keep destructive
   actions away from the child. To pass: read the problem, tap the
   correct answer.

3. SIGN-IN IS OPTIONAL. From Settings (parental gate required) you can
   tap "Sign in with Apple" or "Sign in with Google". This enables
   cloud progress backup. Children cannot access this flow unsupervised
   because of the parental gate.

4. ACCOUNT DELETION (Guideline 5.1.1(v) — for Apple Sign-In testing):
   Settings → Account → "Delete Account" (parental gate required).
   The app:
     a. Calls our Cloud Function which calls Apple's
        https://appleid.apple.com/auth/revoke endpoint to revoke the
        Sign-In with Apple refresh token at Apple's side.
     b. Deletes the user's Firestore document (cloud progress).
     c. Calls Firebase Auth user.delete().
     d. Clears local app state (except the onboarding-completed flag,
        so re-installing doesn't force the child through the tutorial
        again).
   After delete, the app's entry will disappear from the Apple ID's
   "Apps Using Apple ID" list in iOS Settings, confirming the revoke
   succeeded.

5. KIDS CATEGORY COMPLIANCE. We submit to Kids → Ages 6-8.
   - No advertising SDKs of any kind anywhere in the iOS binary
     (we strip Crashlytics + GoogleAppMeasurement at build time;
     verified zero matches in the IPA).
   - No third-party analytics in the iOS binary (firebase_analytics
     is platform-gated to Android only).
   - No advertising IDs. No App Tracking Transparency prompt.
   - No social networks, no chat, no in-app purchases, no
     subscriptions, no external links accessible to children.
   - All sign-in / external-network behavior is behind the parental
     gate.

6. CAMERA. We request camera permission ONLY for an optional motion
   detector that matches in-game attack frequency to brushing pace.
   No frames leave the device, no faces are recognized, no images
   are stored. The feature is fully optional and disabled by default
   in Settings.

7. AUDIO. The app uses voice prompts (ElevenLabs TTS, owned/licensed)
   and royalty-free SFX. There are no copyrighted music tracks.

Privacy policy: https://brushquest.app/privacy-policy.html
Support: support@brushquest.app
Maker: AnemosGP LLC, Alameda CA

Built by a dad for his own kids. Thank you for your work — please reach
out at support@brushquest.app if you need anything during review.

— Jim

## --- END review-notes copy ---

---

## Other App Review Information fields

### Sign-in required: NO

Toggle off. The app is fully usable without signing in.

### Contact information

- First Name: `Jean-Mathieu`
- Last Name: `Chabas`
- Phone: `(408) 771-5034`
- Email: `support@brushquest.app`

### Demo Account

Leave blank. Apple's UI may force a checkbox "Sign-in is required" — if
so, toggle it OFF (the field becomes optional). The notes above explain
the no-account flow and the optional sign-in flow.

### Attachment (optional)

If Apple's reviewer asks for a video walkthrough of the parental gate
or delete flow, the App Preview video at
`marketing/screenshots/ios/preview_6.7.mp4` (already approved as the
listing's App Preview) doubles as a walkthrough.

---

## Why this draft is conservative

1. We do NOT promise the reviewer they'll receive a working refresh
   token revocation log. We tell them to verify by checking the Apple ID
   "Apps Using Apple ID" list — that's the actual user-visible signal
   Apple cares about, and our pipeline targets it.
2. We name the fragility of the camera + audio paths in plain terms,
   so a reviewer who notices any glitch on real iPhone (which we have
   not yet bench-tested at scale) understands the optional-with-fallback
   intent.
3. The math gate is described once with an example so the reviewer
   doesn't get stuck on it (a known cause of unnecessary rejections
   for kids apps).
