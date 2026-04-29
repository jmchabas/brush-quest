# Apple App Store — Privacy Nutrition Labels Worksheet

> Drafted 2026-04-28. To be entered in App Store Connect → App Privacy. Apple's reviewers compare these declarations against actual runtime behavior, the privacy policy, and observed network calls. Mismatch = rejection.

**Submission target:** Apple App Store, Kids Category (Ages 6-8). iOS title: *Brush Quest: Space Rangers*.

**Architecture context for these answers:**
- iOS binary has Firebase Analytics + Crashlytics **stripped** at build time (Podfile post_install).
- iOS binary keeps Firebase Auth + Cloud Firestore for the optional cloud backup.
- Sign-in is optional and gated behind a parental gate (math problem). Children cannot sign in unaided.
- No advertising. No IAP. No social. No tracking. No IDFA.

## Section 1: Did you or your third-party partners collect data from this app?

**Answer: YES** (when the parent enables cloud backup, identifying data is collected for that purpose only).

If sign-in is never used → answer would be NO. But Apple wants the policy to reflect the maximum possible behavior, so we say YES and limit it.

---

## Section 2: Data Types

### Contact Info

| Data Type | Collected? | Linked to user? | Used for tracking? | Purpose | Notes |
|---|---|---|---|---|---|
| Name | **Yes** | Linked | No | App Functionality | Parent's name only, only when they sign in with Google or Apple. Persisted as `displayName` (`auth_service.dart:91-100`). Apple Hide-My-Email path: name still shared if user grants `fullName` scope. Never collected from children — sign-in is gated behind the math parental check. |
| Email Address | **Yes** | Linked | No | App Functionality | Parent's email from Google or Apple sign-in. Apple Hide-My-Email relay supported. |
| Phone Number | No | — | — | — | Never collected |
| Physical Address | No | — | — | — | Never collected |
| Other User Contact Info | No | — | — | — | — |

### Health & Fitness

All **No.** Brushing motion data never leaves the device; no health/fitness data is transmitted.

### Financial Info

All **No.** No IAP, no payment data.

### Location

All **No.** No GPS, no IP-based location, no approximate location.

### Sensitive Info

All **No.**

### Contacts

**No.**

### User Content

| Data Type | Collected? | Linked? | Tracking? | Purpose |
|---|---|---|---|---|
| Photos or Videos | **No** | — | — | — (camera produces motion score on-device, never recorded) |
| Audio | **No** | — | — | — |
| Gameplay Content | **Yes** | Linked | No | App Functionality (cloud backup) |
| Customer Support | No | — | — | — |
| Other | No | — | — | — |

### Browsing History

**No.**

### Search History

**No.**

### Identifiers

| Data Type | Collected? | Linked? | Tracking? | Purpose |
|---|---|---|---|---|
| User ID | **Yes** | Linked | No | App Functionality (Firebase UID, only when signed in) |
| Device ID (IDFA) | **No** | — | — | — — explicitly NOT collected; ATT framework not used |

### Purchases

**No.** No IAP.

### Usage Data

| Data Type | Collected? | Linked? | Tracking? | Purpose | Notes |
|---|---|---|---|---|---|
| Product Interaction | **No** (iOS) | — | — | — | Firebase Analytics is stripped from iOS binary. On Android, this is collected with COPPA child-directed treatment, but iOS app has zero analytics. |
| Advertising Data | **No** | — | — | — | No ads, ever |
| Other Usage Data | **No** | — | — | — | — |

### Diagnostics

| Data Type | Collected? | Linked? | Tracking? | Purpose |
|---|---|---|---|---|
| Crash Data | **No** (iOS) | — | — | — — Crashlytics stripped from iOS binary. App Store Connect's built-in basic crash reporting still applies, that's first-party Apple data. |
| Performance Data | **No** | — | — | — |
| Other Diagnostic Data | **No** | — | — | — |

### Surroundings

**No.**

### Body

**No.** Camera motion score is not biometric — it's a brightness-delta number, not a face/body measurement.

### Other Data

**No.**

## Section 3: Tracking declaration

**Apple's question:** Do you or your third-party partners use this app's data for tracking purposes?

**Answer: NO.**
- We do not link this app's data to data from other apps/websites/services for advertising or measurement.
- We do not share this app's data with data brokers.
- ATT is not requested. IDFA is not collected.

## Section 4: Third-party SDK declarations

For each third-party SDK that collects data, App Store Connect asks the same questions. Our list:

- **Firebase Authentication** (iOS): collects Email + User ID, both Linked, NOT used for Tracking, App Functionality.
- **Cloud Firestore** (iOS): collects User Content (gameplay) + User ID, both Linked, NOT used for Tracking, App Functionality.
- **Sign in with Apple** (iOS): collects Email + User ID. Apple is a first-party in this context; declarations are the same as above.
- **Google Sign-In** (iOS): collects Email + Name + User ID, all Linked, NOT used for Tracking, App Functionality.

(Firebase Analytics + Crashlytics are NOT listed because they are stripped from the iOS binary at build time.)

## Verification before submission

1. Run pre-submission grep: `grep -rE "NSUserTracking|AppTrackingTransparency|GADApplicationIdentifier" ios/` → must return zero. (PLAN.md task 3A-0.)
2. Confirm `Podfile.lock` has NO entries for `GoogleAppMeasurement`. (PLAN.md task 3A-1.)
3. Cross-check this worksheet against the live policy text at https://brushquest.app/privacy-policy.html — every declared "yes" here must match a section in the policy.
4. App Review Notes (PLAN.md task 2C-6) should explicitly state: "This app's iOS binary contains no third-party analytics or crash-reporting SDKs."

## Open questions

- **Children's data flag** — App Store Connect asks whether the data is from children. Answer: **YES**, app is directed at Kids 6-8.
- **Email collection trigger** — only when parent uses sign-in. Apple accepts conditional answers; we declare the maximum collection scenario.
