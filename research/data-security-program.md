# Children's Personal Information Security Program
**AnemosGP LLC (Brush Quest)**
**Effective Date: March 20, 2026**
**Annual Review Due: March 2027**

This document satisfies the requirement under COPPA (16 CFR 312.8) to maintain a written children's personal information security program.

---

## 1. Designated Personnel

**Data Protection Lead:** Jim Chabas, Founder & Sole Operator
- Email: privacy@brushquest.app
- Phone: (510) 214-6383

As a single-operator company, Jim Chabas is responsible for all data protection decisions, incident response, and annual review of this program.

---

## 2. Scope of Children's Data

Brush Quest collects the following data that may relate to children:

| Data Type | Storage Location | Contains PII? |
|-----------|-----------------|---------------|
| Game progress (brush count, streaks, stars, unlocks) | Local device (SharedPreferences) | No |
| Game progress (cloud backup) | Google Cloud Firestore (US) | No (tied to parent's Google UID) |
| Anonymous usage events | Google Firebase Analytics (US) | No |
| Anonymous crash reports | Google Firebase Crashlytics (US) | No |
| Camera motion scores | Device memory only (not stored) | No |

**No personal information is collected directly from children.** The only PII collected is the parent's email and display name, obtained via Google Sign-In with explicit consent.

---

## 3. Risk Assessment

### Internal Risks
| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Accidental inclusion of PII in analytics events | Low | All analytics events are reviewed before deployment. No user-identifiable fields are logged. |
| Unauthorized access to Firestore data | Low | Firestore security rules enforce per-user access (`/users/{uid}`). No admin SDK used in client app. |
| Source code leak exposing API keys | Low | Firebase API keys are restricted by app signature (SHA-1). Keys alone cannot access user data. `.gitignore` excludes sensitive files. |
| Accidental data retention beyond policy | Low | Firestore TTL policy: auto-delete after 12 months inactivity. Analytics: 14-month Firebase default. Crashlytics: 90-day Firebase default. |

### External Risks
| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Firebase service compromise | Very Low | Google maintains SOC 2/3, ISO 27001 certifications. Data encrypted in transit (TLS) and at rest. |
| Man-in-the-middle attack on cloud sync | Very Low | All Firebase communication uses HTTPS/TLS. Certificate pinning handled by Firebase SDK. |
| Device theft exposing local data | Low | Local data is non-personal (game progress only). Device-level encryption (Android FBE) protects SharedPreferences. |
| Malicious app impersonation | Low | Firebase API keys restricted to app's SHA-1 signature. Google Sign-In validates app identity. |

---

## 4. Safeguards

### Technical Safeguards
- **Encryption in transit:** All data sent to Firebase uses TLS encryption
- **Encryption at rest:** Firestore data encrypted at rest using Google's default encryption (AES-256)
- **Access control:** Firestore security rules restrict each user to their own document only
- **No server-side code:** No custom backend. All server interactions go through Firebase SDKs with built-in security
- **Minimal data collection:** Only anonymous events for analytics. No PII from children. Camera processes locally and discards immediately
- **Child-directed Firebase configuration:** Advertising IDs disabled, ad personalization disabled, child-directed treatment flag enabled
- **Parental gates:** Math verification problem gates access to Settings, cloud save, and camera toggle

### Operational Safeguards
- **Code review:** All code changes reviewed before commit
- **Static analysis:** `dart analyze` runs on every code change (automated via CI and local hooks)
- **Security scanning:** `semgrep` and `gitleaks` run periodically to detect vulnerabilities and accidental secret exposure
- **Dependency monitoring:** Flutter and Dart dependencies kept up to date; `pub outdated` checked regularly
- **No third-party data sharing:** Firebase services configured as service providers only. No advertising SDKs, no social media SDKs, no third-party tracking

---

## 5. Testing & Monitoring

| Activity | Frequency | Method |
|----------|-----------|--------|
| Automated test suite (593+ tests) | Every code change | `flutter test` via CI (GitHub Actions) |
| Static analysis | Every code change | `dart analyze` via CI and local hook |
| Security scan | Before each release | `semgrep --config auto lib/` |
| Secret detection | Before each release | `gitleaks detect --source .` |
| Firebase security rules review | Before each release | Manual review of `firestore.rules` |
| Analytics event audit | Before each release | Review all logged events for PII leakage |
| Manual audio/UX checklist | Before each APK upload | `test/MANUAL_AUDIO_CHECKLIST.md` (122 items) |

---

## 6. Incident Response

In the event of a data breach or suspected unauthorized access to children's data:

1. **Contain:** Immediately disable affected Firebase services (revoke keys, disable sign-in, pause analytics)
2. **Assess:** Determine what data was affected, how many users impacted, and the attack vector
3. **Notify:** If personal information was compromised:
   - Notify affected parents by email within 72 hours
   - Notify the FTC if the breach involves children's personal information
   - Notify the California Attorney General if 500+ California residents affected (CA Civil Code 1798.82)
4. **Remediate:** Fix the vulnerability, update security measures, document lessons learned
5. **Review:** Update this security program based on findings

---

## 7. Annual Review

This program will be reviewed and updated at least annually (next review: **March 2027**) or sooner if:

- A security incident occurs
- The app's data collection practices change
- New COPPA regulations or FTC guidance are issued
- New third-party services are added

**Review checklist:**
- [ ] All risk assessments still accurate?
- [ ] All safeguards still in place and effective?
- [ ] Any new data collection since last review?
- [ ] Firebase security rules still restrictive?
- [ ] All third-party services still compliant?
- [ ] Test suite coverage adequate?
- [ ] Incident response plan still current?

---

*This document is an internal operational document and is not required to be publicly posted. It is referenced in the Brush Quest Privacy Policy (Section 3: How We Protect Your Data).*
