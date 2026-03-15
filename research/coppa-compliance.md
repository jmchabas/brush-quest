# COPPA Compliance — Implementation Guide
**Last updated**: 2026-03-14

## What COPPA Requires (2025 Amended Rule, effective June 23, 2025)

COPPA applies to Brush Quest unambiguously: it's a commercial app directed to children under 13 (ages 5-9).

### "Personal Information" Under COPPA (16 CFR 312.2)

11 categories. Brush Quest touches these:

| Category | Example | Brush Quest Status |
|----------|---------|-------------------|
| 3. Online contact info | Email | Parent Google Sign-In only (behind parental gate) |
| 7. Persistent identifiers | Cookies, device IDs, Firebase installation IDs | Firebase Analytics collects automatically |
| 8. Photos/video/audio containing child | Camera frames | Processed locally, not stored/transmitted |
| 10. Biometric identifiers | Facial templates, voiceprints | Camera does NOT create facial templates — motion detection only |

### What Brush Quest Currently Collects (Audit)

| Data | COPPA Category | Where | Risk |
|------|---------------|-------|------|
| Camera frames (motion detection) | 8 (photos/video) | Local only, not stored | MEDIUM — see camera analysis below |
| Google Sign-In (email, name) | 3 (contact info) | Firebase Auth + Firestore | LOW — parent-operated |
| Firebase installation IDs | 7 (persistent identifiers) | Google servers | HIGH — automatic from children |
| SharedPreferences (game progress) | Not personal info | Local device | NONE |
| Firestore cloud save | Tied to Google UID (cat 7) | Google servers | MEDIUM — after parent sign-in only |

---

## The Camera Question

### Strong argument it does NOT trigger COPPA biometric requirements:
- `_processFrame` in `camera_service.dart` downsamples to 32x32 grayscale grid, computes pixel luminance differences between consecutive frames. Output: single float 0.0-1.0.
- No facial recognition. No facial template extraction. No biometric identification.
- Data never leaves the device. Frames are discarded immediately after processing.
- COPPA targets **online collection**. Data that never leaves the device is not "collected."
- The 2025 definition requires biometric identifiers "that can be used for the automated or semi-automated recognition of an individual." A motion float cannot identify anyone.

### Conservative approach (recommended):
- Make camera **opt-in** by default (currently defaults ON — change this)
- Show consent notice when parent toggles camera ON
- Document local-only processing clearly in privacy policy
- Never frame motion detection as "verification" or "proof" of anything

---

## Implementation Checklist

### P1: BLOCKING — Must Do Before Publishing

#### P1.1: Camera default → OFF
- **File**: `lib/screens/settings_screen.dart`
- Change `bool _cameraEnabled = true` to read SharedPreferences with default `false`
- **Effort**: 30 minutes

#### P1.2: Parental consent before Google Sign-In
- **File**: `lib/screens/settings_screen.dart`
- Before Google Sign-In, show notice: "By signing in, you consent to storing your child's game progress in Google's cloud. This includes brush counts, streaks, stars, and unlocked items. No personal information about your child is collected."
- Include link to privacy policy
- Require explicit "I Consent" tap
- **Effort**: 1-2 hours

#### P1.3: Consent notice before camera toggle ON
- When parent toggles camera ON, show: "The camera detects brushing motion only. No images are stored, recorded, or sent anywhere."
- Require confirmation
- **Effort**: 1 hour

#### P1.4: Privacy policy link inside app
- Add "Privacy Policy" link in Settings under OTHER section
- Opens `https://jmchabas.github.io/brush-quest/privacy-policy.html`
- **Effort**: 30 minutes

#### P1.5: Update privacy policy
Missing COPPA 312.4 required elements:
- [ ] Operator physical mailing address (can be PO Box) + phone number (currently email only)
- [ ] Specific data retention timeframes (currently vague)
- [ ] List of all operators collecting data (Firebase/Google as service provider)
- [ ] Description of parental consent mechanism
- [ ] Description of parental rights with specific mechanisms (review, delete, refuse)
- **Effort**: 2-4 hours

#### P1.6: Firebase Analytics child-directed configuration
- Ensure ad IDs disabled (already done in `analytics_service.dart`)
- Tag Firebase property as child-directed in Firebase Console
- Consider: disable Analytics entirely by default, enable only after parent sign-in
- Document "internal operations" exception if keeping Analytics active
- **Effort**: 1-2 hours

### P2: IMPORTANT — Before Google Play Submission

#### P2.1: Google Play Console configuration
- Set target audience: "Children" (ages 5-9)
- Complete Families Policy questionnaire
- Include privacy policy URL in store listing
- Declare COPPA compliance
- Declare no ads
- **Effort**: 1 hour

#### P2.2: Data deletion capability
- Existing "Reset All Progress" is good but should be labeled "Delete My Child's Data"
- Ensure `deleteCloudData()` removes all Firestore documents
- Document deletion process in privacy policy
- **Effort**: 1 hour

#### P2.3: Data retention timeframes (in privacy policy)
| Data Type | Retention |
|-----------|-----------|
| Local game progress | Until app uninstall or manual reset |
| Cloud save data | While account exists; auto-deleted after 12 months of inactivity |
| Firebase Analytics | 14 months (Firebase default, configurable to 2 months) |
| Firebase Crashlytics | 90 days (Firebase default) |

### P3: RECOMMENDED — For Future iOS

#### P3.1: Apple Kids Category requirements
- **Third-party analytics BANNED** in Kids Category. Firebase Analytics must be removed for iOS, or don't list in Kids Category.
- No PII to third parties without parental consent
- Parental gates for: IAP, external links, settings affecting data
- Accurate privacy nutrition label
- Recommendation: Conditional compilation to exclude Firebase Analytics from iOS build

### P4: NICE-TO-HAVE

#### P4.1: COPPA Safe Harbor enrollment
- Programs: kidSAFE ($600-$1,500/yr for small apps), PRIVO, iKeepSafe
- Provides compliance seal + protection from direct FTC enforcement
- Consider once generating revenue

---

## Verifiable Parental Consent Methods

Acceptable under 16 CFR 312.5(b):

| Method | Practical for Solo Dev? | Notes |
|--------|------------------------|-------|
| Credit/debit card transaction | YES — best | Subscription purchase itself serves as consent |
| Email plus (email + confirmatory follow-up) | YES | For free users wanting cloud sync. Must not disclose to third parties. |
| Knowledge-based authentication | MAYBE | Current math problem likely too easy for 10-year-olds. Would need harder questions. |
| Government ID check | NO | Overkill |
| Video conference | NO | Not scalable |

**Recommendation**: Credit card via subscription = primary method. Email plus = fallback for free users.

---

## Do You Need a Lawyer?

| Stage | Recommendation | Cost |
|-------|---------------|------|
| Now | Template service (iubenda $27/yr, TermsFeed $50 one-time) | $27-$50 |
| At $5K MRR | Lawyer review of privacy policy | $500-$1,500 |
| At $20K MRR | Full legal audit | $3,000-$5,000 |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| FTC enforcement | Very Low | High ($53K/violation) | Complete P1 items |
| Play Store rejection | Medium | High | Complete P1 + P2 |
| Camera usage questioned by reviewers | Low | Medium | Opt-in + document local processing |
| Parent complaint | Low | Medium | Full privacy policy + in-app controls |
| Apple rejection (Firebase Analytics) | Medium-High | Medium | Remove Analytics from iOS build |

---

## Sources
- FTC: COPPA Rule (16 CFR Part 312)
- FTC: COPPA FAQ (2025 updated)
- Loeb & Loeb: COPPA 2025 Amendments Analysis
- Promise Legal: COPPA Compliance Practical Guide
- Apple: App Review Guidelines (Kids Category)
- Google Play: Families Policy
- Firebase: Configure Analytics for child-directed treatment
