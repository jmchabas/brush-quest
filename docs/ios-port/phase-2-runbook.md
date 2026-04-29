# Day-of Phase 2 Runbook

> **Last verified:** 2026-04-29
> **Trigger:** the moment Apple's "authority verified — pay $99 to enroll" email arrives in `appledev@anemosgp.com` (Apple Developer Program enrollment ID `CLMXUSFBV2`).
> **Source of truth for tasks:** [`PLAN.md`](./PLAN.md) — this runbook is execution scaffolding only. If a task ID below disagrees with `PLAN.md`, `PLAN.md` wins; fix the runbook.

## Time budget

- **Active work:** ~2–4 hours (most of it is portal clicking and waiting for short upload/process loops).
- **Apple build processing wait:** 5–30 min after TestFlight upload (decoupled — start a new task).
- **First Apple build review:** typically 24–48 hr (the slot between 2D-3 and 2E-1; Jim does TestFlight install during this window, but external public review is later in Phase 3).

## Owner legend

- **J** — Jim (manual portal / Xcode / payment / human decisions)
- **C** — Claude (script, code, automation; runs from this repo)

---

## Step-by-step

### 2A — Apple Developer Program enrollment

#### 2A-1 (J, ~10 min) — Pay the $99 enrollment

1. Open the verified email from Apple. Click the activation link.
2. Sign in to https://developer.apple.com/account with `appledev@anemosgp.com`.
3. Confirm enrollment details (Organization, AnemosGP LLC, D-U-N-S `144980774`).
4. Pay $99/yr with the Mercury card.

**Acceptance:** Apple Account portal shows "Account Holder" role; the membership status flips to "Active"; **a 10-character Team ID is assigned and visible in the upper-right of developer.apple.com** ("Membership details" → "Team ID").

**Pitfall:** the Team ID Apple shows on the welcome screen sometimes contains spaces or is formatted with a hyphen — it is always exactly 10 alphanumeric characters with no separators. Strip any whitespace before passing to the capture script.

#### 2A-2 (C, ~30 sec) — Capture the Team ID

Once the Team ID is visible on screen:

```bash
bash scripts/capture_team_id.sh ABC1234567
```

(replace `ABC1234567` with the real Team ID — script validates the format and refuses anything that isn't exactly 10 chars `[A-Z0-9]`).

The script does three patches (idempotent — safe to re-run):

1. Updates `/Users/jimchabas/Projects/anemosgp-business/REGISTRY.md` §4 "Apple Developer Program" → swaps `_pending_` for the real ID.
2. Inserts `DEVELOPMENT_TEAM = <ID>;` into the three Runner-target build configs in `ios/Runner.xcodeproj/project.pbxproj` (Debug, Release, Profile). Project-level configs are deliberately untouched (Xcode resolves settings via the target).
3. Replaces `PLACEHOLDER_REPLACE_AT_2A-2` in `ios/fastlane/Matchfile` with the real ID.

**Acceptance:** script exits 0; the printed diff summary shows three files changed; `git diff -- ios/Runner.xcodeproj/project.pbxproj` shows exactly **three** new `DEVELOPMENT_TEAM = <ID>;` lines and zero changes elsewhere.

**Manual cleanup (J, ~30 sec):** REGISTRY.md §8 "Future / pending" still has `- **Apple Developer Team ID** — pending (after CLMXUSFBV2 approves)`. Delete that bullet by hand — the script intentionally leaves §8 alone so it doesn't unilaterally edit Jim's todo list.

**Then commit (J):** inspect `git diff` in both `brush-quest` and `anemosgp-business` repos, commit if clean.

#### 2A-3 (J + C, ~20 min) — Sign in with Apple key + Cloud Function secret

This is the day's biggest pitfall — the `.p8` file is **only downloadable once**. If you close the page or refresh before saving, you must revoke and regenerate.

**J — generate (5 min):**

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles** → **Keys** → **+**.
2. Name: "Brush Quest SIWA". Tick **Sign In with Apple**. Under "Configure", primary App ID = `com.brushquest.brushQuest`.
3. **Continue** → **Register** → **Download** the `.p8` file. **Save it to `~/Documents/credentials/apple/AuthKey_<KEY_ID>.p8` immediately.** Note the **Key ID** (10 chars) and your **Team ID** — both are needed for the JWT.
4. Note the **Services ID** for SIWA on the Identifier list (or create one if absent — pattern `com.brushquest.brushQuest.siwa`).

**C — wire into Cloud Function (15 min):**

1. Set Firebase Functions secrets (Firebase CLI, run from `functions/`):
   ```bash
   firebase functions:secrets:set APPLE_PRIVATE_KEY < ~/Documents/credentials/apple/AuthKey_<KEY_ID>.p8
   firebase functions:secrets:set APPLE_KEY_ID --data-stdin <<< "<KEY_ID>"
   firebase functions:secrets:set APPLE_TEAM_ID --data-stdin <<< "<TEAM_ID>"
   firebase functions:secrets:set APPLE_CLIENT_ID --data-stdin <<< "com.brushquest.brushQuest"
   ```
2. Replace the stub in `functions/src/index.js` with the real revoke implementation. Outline (full code is the commented block already in the stub):
   - JWT signed with ES256 over `{iss: TEAM_ID, iat, exp, aud: "https://appleid.apple.com", sub: CLIENT_ID}`.
   - `POST https://appleid.apple.com/auth/revoke` with form-encoded body `client_id`, `client_secret` (the JWT), `token`, `token_type_hint=refresh_token`.
   - Auth-gate the callable with `request.auth.uid`.
3. `firebase deploy --only functions:revokeAppleToken`.
4. Smoke-test: call from `AuthService.deleteAccount()` with a throwaway test Apple account.

**Acceptance:** function returns `{revoked: true}` for a valid token; `{revoked: false, reason: "<apple_error>"}` for invalid; logs in Firebase Console show no exceptions.

**Pitfall:** Apple's revoke endpoint returns HTTP 200 with no body on success — don't parse for a JSON success flag. Treat 200 as success.

**Reference:** [Apple SIWA revoke endpoint — auth/revoke](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens).

---

### 2B — Code signing setup (Fastlane Match)

#### 2B-1 (closes itself — handled in 2A-2)

`DEVELOPMENT_TEAM` was set by `capture_team_id.sh`. No additional work.

#### 2B-2 (J, ~3 min) — Create the private match repo

1. https://github.com/new → owner `jmchabas` (or AnemosGP org if migrated by then), repo name `brush-quest-match`, **Private**, no README, no .gitignore, no license.
2. After creation, copy the **SSH** URL: `git@github.com:jmchabas/brush-quest-match.git`.

**Acceptance:** empty private repo exists at `https://github.com/jmchabas/brush-quest-match`.

**Pitfall:** Fastlane Match must use the SSH URL (`git@github.com:...`), NOT the HTTPS URL. Match commits encrypted certificates; HTTPS would prompt for credentials on every run.

#### 2B-3 (C, ~5 min) — Configure Match + create development cert

1. Edit `ios/fastlane/Matchfile` — replace `PLACEHOLDER_REPLACE_AT_2B-3` with the SSH URL from 2B-2:
   ```ruby
   git_url("git@github.com:jmchabas/brush-quest-match.git")
   ```
2. Provide an encryption password the first time match runs. **Store it in Jim's password manager under "Brush Quest — Match passphrase"** — Codemagic will need it as `MATCH_PASSWORD` env var in 2D-1.
3. From `ios/`:
   ```bash
   bundle install
   bundle exec fastlane match init   # if it asks; usually skipped because Matchfile is pre-filled
   bundle exec fastlane match development
   ```

**Acceptance:** `git ls-remote git@github.com:jmchabas/brush-quest-match.git` shows commits; `~/Library/MobileDevice/Provisioning Profiles/` contains a `match Development com.brushquest.brushQuest.mobileprovision`.

**Pitfall:** if Match prompts for an Apple ID, use `appledev@anemosgp.com` (Account Holder). If it asks for an app-specific password, generate one at https://appleid.apple.com → Sign-In and Security → App-Specific Passwords.

#### 2B-4 (C, ~3 min) — Create distribution cert + profile

```bash
cd ios && bundle exec fastlane match appstore
```

**Acceptance:** match repo now contains both `certs/development/` and `certs/distribution/` directories.

---

### 2C — App Store Connect listing creation

(All J — paste from existing reviewed docs. Bring the pre-approved files up on a second monitor: `docs/ios-port/store-listing.md`, `docs/ios-port/privacy-labels.md`, `docs/ios-port/screenshots.md`, `docs/ios-port/review-notes.md`.)

#### 2C-1 (J, ~5 min) — Create app record

1. https://appstoreconnect.apple.com → **My Apps** → **+** → **New App**.
2. Platforms: iOS. Name: `Brush Quest: Space Rangers` (per 1S-2). Primary language: English (U.S.). Bundle ID: select `com.brushquest.brushQuest` (it appears in the dropdown only after 2A-2 + first build registration).
3. SKU: `BRUSHQUEST-IOS-001`. User Access: Full Access.
4. **Primary Category: Kids → Ages 6-8.** Secondary Category: Education.

**Acceptance:** app record exists in App Store Connect with status "Prepare for Submission".

**Pitfall:** the bundle ID dropdown is empty until you've registered an explicit App ID at developer.apple.com → Identifiers. If `com.brushquest.brushQuest` isn't there, register it (Identifiers → + → App ID → Bundle ID exact = `com.brushquest.brushQuest`; capabilities: Sign In with Apple, Push Notifications off).

#### 2C-2 (J, ~10 min) — Paste listing copy

Source: `docs/ios-port/store-listing.md` (already approved in 1L-2).

Fields to fill on the App Information + Pricing and Availability pages:
- Subtitle, Promotional Text, Description, Keywords, Support URL (`https://brushquest.app/`), Marketing URL (same), Privacy Policy URL (`https://brushquest.app/privacy-policy.html`).
- Pricing: Free; all territories.

**Acceptance:** Save button enabled and clean (no red field warnings).

#### 2C-3 (J, ~10 min) — Upload screenshots

Source: `marketing/screenshots/ios/{6.9,6.7,6.5}/captioned_NN_*.png` (already approved in 1M-3).

**Acceptance:** at minimum the 6.9" set is uploaded (required); 6.7" and 6.5" recommended.

#### 2C-4 (J, ~5 min) — Privacy nutrition labels

Open `docs/ios-port/privacy-labels.md`. Click through App Privacy → "Get Started" and answer each section per the worksheet. Every Tracking question = NO.

**Acceptance:** App Privacy page shows the data summary; no red "incomplete" badges.

#### 2C-5 (J, ~3 min) — Age rating questionnaire

Apple updated the questionnaire 2026-01-31. Answer all medical/wellness, violence, in-app controls questions = NO. Default rating: **4+**.

**Acceptance:** age rating shows 4+; questionnaire saved.

#### 2C-6 (C, already prepped) — App Review Notes

Already drafted; the body lives at `docs/ios-port/review-notes.md` (per PLAN 2C-6). If that file doesn't yet exist when you reach this step, write it now from the spec in `PLAN.md` task 2C-6 — it's a 2-paragraph note covering Kids Category compliance, no analytics/ads, parental gate, optional sign-in, on-device camera.

#### 2C-7 (J, ~2 min) — Paste review notes

Copy `docs/ios-port/review-notes.md` body → App Information → App Review Information → Notes textarea. Add a test Apple ID (Jim creates a sandbox tester at App Store Connect → Users and Access → Sandbox Testers).

**Acceptance:** Review Information page shows the notes + test account credentials.

---

### 2D — First TestFlight build

#### 2D-1 (C, ~10 min) — Update `codemagic.yaml` Phase 2 block

The `ios_release` workflow in `codemagic.yaml` is currently scaffolded as a commented block. Day-of:

1. Uncomment the block.
2. Set environment variables:
   - `APP_STORE_CONNECT_PRIVATE_KEY` (Codemagic UI: paste contents of an App Store Connect API key `.p8`. Generate at App Store Connect → Users and Access → Keys → +. Role: App Manager.)
   - `APP_STORE_CONNECT_KEY_IDENTIFIER` (10-char ID printed next to the key).
   - `APP_STORE_CONNECT_ISSUER_ID` (UUID at top of the Keys page).
   - `MATCH_PASSWORD` (the passphrase you stored in 2B-3).
   - `APPLE_ID` = `appledev@anemosgp.com`.
   - `MATCH_GIT_URL` = `git@github.com:jmchabas/brush-quest-match.git`.
   - SSH key: Codemagic UI → SSH keys → generate a deploy key, upload its **public** half to `brush-quest-match` repo Settings → Deploy Keys.
3. Verify the build step uses `flutter build ipa --release --export-options-plist=...` with match-generated profile.

**Acceptance:** committed `codemagic.yaml` change builds a `.ipa` artifact.

**Pitfall:** Codemagic encrypts secrets with its own key — `MATCH_PASSWORD` and the SSH key must be entered through Codemagic's UI, not committed to the repo.

#### 2D-2 (C, ~15 min build + waits) — Trigger first signed iOS build

1. Push the branch with the codemagic.yaml change. Codemagic auto-runs `ios_release` on tag pushes; for the first manual try, kick it from the Codemagic UI → Start new build → workflow `ios_release`.
2. Watch the build. First failure pattern: SSH key auth on the match repo. If you see `Permission denied (publickey)`, double-check the deploy key is added to `brush-quest-match` (NOT the main repo).
3. Second common failure: missing entitlement. The Runner.entitlements already has `com.apple.developer.applesignin`; no other entitlements are needed for v1.

**Acceptance:** green build, downloadable signed `.ipa` in the artifacts panel.

#### 2D-3 (J, ~10 min, plus 5–30 min Apple processing) — Upload to TestFlight

Either:
- Codemagic auto-publish to TestFlight (if `app_store_connect.submit_to_testflight: true` is in the workflow — preferred), or
- Download the `.ipa` and upload via Transporter.app.

**Acceptance:** App Store Connect → TestFlight → Builds shows the new build. Status moves through "Processing" → "Ready to Submit". Wait for the "Ready" state (typically 5–30 min) before doing 2D-4.

**Pitfall:** if Apple rejects the upload with `ITMS-91061: Missing API declaration` or similar privacy-manifest errors, fall back to PLAN tasks 1H-* — but this should not happen since the privacy manifest audit (1H-3) shipped a Runner-level `PrivacyInfo.xcprivacy`.

#### 2D-4 (J, ~5 min) — Add internal testers

App Store Connect → TestFlight → Internal Testing → + → create group "Founder + Family" → add:
- jim@anemosgp.com
- Jim's personal Apple ID
- Jim's spouse's Apple ID (Oliver's parent)
- Up to ~5 invited friends

Send invites. Each tester gets a TestFlight email; install the TestFlight app, redeem, install Brush Quest.

**Acceptance:** at least one tester (Jim) has the build installed and launching on a real iPhone.

---

### Reference links

- [Apple Developer account portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple SIWA revoke tokens API](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens)
- [Fastlane Match docs](https://docs.fastlane.tools/actions/match/)
- [Codemagic — code signing iOS apps](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Apple support — offering account deletion (Guideline 5.1.1(v))](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

---

## Pitfall callouts (consolidated, for skim-reading the day-of)

1. **2A-3 — SIWA `.p8` is downloadable ONCE.** If the page closes, you re-revoke and regenerate. Save to `~/Documents/credentials/apple/` immediately, before clicking anything else.
2. **2B-2 / 2B-3 — Match URL must be `git@`, not `https://`.** HTTPS forces a credential prompt every Codemagic run; SSH uses the deploy key.
3. **2A-2 — capture_team_id.sh leaves §8 of REGISTRY alone on purpose.** Manually delete the "Apple Developer Team ID — pending" bullet under "Future / pending" before committing.
4. **2C-1 — bundle ID won't appear in the "New App" dropdown** until you register the explicit App ID at Identifiers. Do that immediately after 2A-1 if it's missing.
5. **2C-5 — Apple replaced the age rating questionnaire 2026-01-31.** Do not paste answers from the Android Play Store questionnaire — questions and answer shapes differ.
6. **2D-3 — first TestFlight build review can take 24–48 hr** before Apple "approves it for TestFlight" (a separate gate from the App Store review). Internal testers can install during this period; external testers (TestFlight public link) cannot.
7. **General — versioning monotonicity.** `pubspec.yaml` build number must strictly increase across every iOS upload. Per `docs/ios-port/versioning.md`: baseline `1.0.0+20`, next iOS upload `1.0.0+21`.
