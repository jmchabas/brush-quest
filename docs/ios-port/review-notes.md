# App Review Notes — Brush Quest (paste into App Store Connect)

> Drafted 2026-05-06 for plan task 2C-6; corrected 2026-09-28 for v29
> (release/v29). The text below `--- BEGIN ... ---` is the verbatim copy for
> App Store Connect's "App Review Information → Notes" field. Everything
> else is internal context.
>
> Keep it true to the build being submitted. Before pasting:
> - Run `scripts/check_ios_kids_binary.sh` on the final IPA (item 5).
> - If the onboarding GROWN-UP CHECK changes (it is still a fixed "7 × 8"
>   with three tap answers), rewrite item 2's last bullet to match.
> - The "Cloud Save — Data Notice" dialog shown before Sign in with Apple
>   must no longer name Firebase Analytics/Crashlytics on iOS, or it
>   contradicts item 5.
> - Account deletion needs the `revokeAppleToken` Cloud Function live
>   (Blaze plan) for the "Apps Using Apple ID" check in item 4.
> - "Alameda CA" is intentional: it is the operations address on the Apple
>   Developer account / D-U-N-S. The privacy policy shows the Sacramento
>   registered-agent address (REGISTRY.md → Addresses).

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

2. PARENTAL GATES. Everything meant for parents sits behind a
   multiplication problem a young child cannot solve:
   - Settings (the PARENTS lock button, top-left of the home screen) opens a
     "Parent Check" screen: type the answer to a problem such as
     "6 × 4 = ?" (one factor 4-9, the other 3-7) on the number keypad and
     tap UNLOCK. A wrong answer shows a new problem. Settings locks again
     after 60 seconds without interaction.
   - Sign-in, Delete Account, reset progress ("Start fresh") and the
     privacy policy link are all inside Settings. Delete Account and
     "Start fresh" also ask a second typed multiplication after a warning
     dialog.
   - The camera page at the end of the first-launch tutorial ("ASK A
     GROWN-UP" → TURN ON CAMERA) shows a "GROWN-UP CHECK": tap the answer
     to "What is 7 × 8?" (56).

3. SIGN-IN IS OPTIONAL. In Settings → Settings tab → Account, tap
   "Sign in with Apple" or "Sign in with Google". A data notice explains
   what is stored; tap I CONSENT. Signing in enables cloud backup of the
   child's progress only.

4. ACCOUNT DELETION (Guideline 5.1.1(v), Sign in with Apple):
   Settings → Settings tab → Account → "Delete Account" → CONTINUE →
   solve the second multiplication. The app:
     a. Calls our Cloud Function, which calls Apple's
        https://appleid.apple.com/auth/revoke endpoint to revoke the
        Sign in with Apple token.
     b. Deletes the user's Firestore document (cloud progress).
     c. Deletes the Firebase Auth user.
     d. Clears local app state (except the onboarding-completed flag,
        so the child isn't sent through the tutorial again).
   Please delete within a few minutes of signing in with Apple: the
   authorization used for the revoke is short-lived. If the app shows
   "Please sign out, sign in again, then try deleting.", sign out, sign
   in with Apple again, then delete. Afterwards Brush Quest disappears
   from the Apple ID's "Apps Using Apple ID" list in iOS Settings.

5. KIDS CATEGORY COMPLIANCE. We submit to Kids → Ages 6-8.
   - No analytics, crash-reporting or advertising SDK is in the iOS app.
     The Android build uses Firebase Analytics and Crashlytics, but in
     this app those plugins have no iOS implementation, so neither
     Google App Measurement nor Crashlytics is compiled into the iOS
     binary. We check every build by scanning the main executable and
     every embedded framework for these SDKs.
   - The Google/Firebase components on iOS are Firebase Auth, Cloud
     Firestore and Cloud Functions (optional cloud save and account
     deletion) and Google Sign-In, with their supporting libraries.
   - No advertising identifier, no App Tracking Transparency prompt.
   - No social features, no chat, no in-app purchases, no
     subscriptions, no external links reachable by children.

6. CAMERA (optional, off by default). The front camera can drive an
   optional motion detector that matches the in-game attack pace to
   brushing. Frames are compared on the device only; nothing is
   recorded, stored or sent, and no faces are detected. A parent turns
   it on in either of two places:
   - Last page of the first-launch tutorial: TURN ON CAMERA →
     GROWN-UP CHECK → "Brushing Detection" notice → ENABLE.
   - Settings (Parent Check) → Settings tab → "Brushing detection"
     switch → the same notice → ENABLE.
   The iOS camera permission prompt appears right after ENABLE, while the
   parent still holds the phone. When the camera is in use, a small
   camera icon shows in the top bar of the brushing screen. Without the
   camera (declined, or "Maybe later") the game runs on a timer instead.

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
3. Each gate is described exactly as built, with an example, so the
   reviewer doesn't get stuck on it (a known cause of unnecessary
   rejections for kids apps) and doesn't find notes that disagree with
   the app.
