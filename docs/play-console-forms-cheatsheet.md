# Google Play Console Forms -- Answer Sheet for Brush Quest

Prepared: 2026-04-01
App: Brush Quest (com.brushquest.brush_quest)

---

## 1. Content Rating (IARC Questionnaire)

**Path:** Play Console > Policy and programs > App content > Content rating > Start

**Step 1 -- App Information**
- Email address: jim@anemosgp.com
- Category: Select **Game** (it's a gamified brushing timer)
- Confirm this is an app/game (not just a streaming service)

**Step 2 -- Violence**
- Does the app contain violence? **No**
  - Rationale: Cartoon monsters are "defeated" by brushing teeth. There is no depiction of harming humans/animals, no blood, no gore, no death animations. Monsters dissolve with particle effects.
- Does violence involve humans or human-like characters? **No**
- Is violence rewarded? **No**
- Does the app contain graphic or realistic violence? **No**

**Step 3 -- Sexual Content**
- Does the app contain sexual content or nudity? **No**

**Step 4 -- Language**
- Does the app contain profanity or crude humor? **No**
  - All voice lines are kid-friendly encouragements ("Great brushing!" etc.)

**Step 5 -- Drugs, Alcohol, and Tobacco**
- Does the app contain references to drugs, alcohol, or tobacco? **No**

**Step 6 -- Gambling**
- Does the app contain simulated gambling? **No**
- Does the app contain real-money gambling? **No**
  - Note: The app has a star economy and treasure chests, but these are earned through brushing only -- no randomized loot boxes with real-money purchases.

**Step 7 -- User Interaction**
- Does the app allow users to interact or communicate with each other? **No**
- Does the app share user-generated content? **No**
- Does the app share the user's current location with other users? **No**
- Does the app allow users to purchase digital goods? **No** (no in-app purchases currently)
- Does the app contain unrestricted internet access? **No** (internet used only for Firebase sync behind authentication)

### Expected Rating

| Rating System | Expected Rating |
|---------------|----------------|
| ESRB (North America) | **Everyone (E)** |
| PEGI (Europe) | **3** |
| USK (Germany) | **0** |
| ClassInd (Brazil) | **L (Livre)** |
| GRAC (South Korea) | **All** |
| IARC Generic | **3+** |

---

## 2. Target Audience and Content

**Path:** Play Console > Policy and programs > App content > Target audience and content > Start

### Step 1 -- Target Age Group

Select the following age groups:

- [x] **Ages 5 and under**
- [x] **Ages 6-8**
- [x] **Ages 9-12**
- [ ] Ages 13-15
- [ ] Ages 16-17
- [ ] Ages 18 and over

Rationale: Primary user is ages 4-8. Selecting "Ages 5 and under" through "Ages 9-12" covers the 3-10 range. Do NOT select older age groups -- it is unnecessary and complicates compliance.

### Step 2 -- Families Policy Compliance

Because you selected age groups that include children, the app MUST comply with Google Play's Families Policy. Confirm the following:

- [x] App content is appropriate for children
- [x] App does not contain ads (no ads at all)
- [x] If the app does show ads in the future, only Google Play Families self-certified ad SDKs will be used
- [x] App complies with COPPA and applicable child privacy laws
- [x] App has a privacy policy that addresses children's data

### Step 3 -- App Appeal

- "Is this app specifically designed for children?" **Yes**
  - The UI uses large icons, voice-over (no reading required), a space/monster theme designed for young children
- "Does the app appeal to children but is not specifically designed for them?" Not applicable -- select "designed for children"

### Step 4 -- Additional Families Details

- **Category:** Select **Education** or **Entertainment** (whichever is available and fits best -- Education is recommended since it teaches a health habit)
- **Interactive elements:** Select "Shares info" only if prompted (Firebase cloud sync is optional, user-initiated)
- **Privacy policy URL:** https://brushquest.app/privacy-policy.html
- **Teacher Approved program:** Skip for initial submission (can opt in later)

### Families Policy Requirements Checklist

These are NOT form fields -- but Google will review your app against these. Verify compliance:

- [x] No behavioral advertising (firebase_analytics has ad personalization DISABLED in code)
- [x] No ad ID collection (disabled in AndroidManifest.xml: `google_analytics_adid_collection_enabled = false`)
- [x] COPPA compliant (no personally identifiable information collected from children without parental action)
- [x] Google Sign-In requires parent to set up (parent gate: math problem for destructive actions)
- [x] All content appropriate for the selected age groups
- [x] App is usable without reading (voice-over + icons throughout)
- [x] Privacy policy is accessible and addresses children's data
- [x] No links out of the app that are not behind a parent gate (URL launcher for privacy policy is in settings, behind parent-gated area)

---

## 3. Data Safety Form

**Path:** Play Console > Policy and programs > App content > Data safety > Start

### Section 1 -- Overview / Data Collection and Security

**"Does your app collect or share any of the required user data types?"**
- Answer: **Yes**
  - Firebase Analytics collects app usage events
  - Firebase Crashlytics collects crash logs
  - Firebase Auth collects email/name (when user opts in to Google Sign-In)
  - Cloud Firestore stores game progress (when user opts in)

**"Is all of the user data collected by your app encrypted in transit?"**
- Answer: **Yes**
  - All Firebase communication uses HTTPS/TLS

**"Do you provide a way for users to request that their data be deleted?"**
- Answer: **Yes**
  - In-app: Settings > "Delete child's data" (deletes local + cloud data)
  - Firebase Auth account can be deleted
  - Deletion URL (if asked): https://brushquest.app/privacy-policy.html (or provide a dedicated deletion page)

### Section 2 -- Data Types Collected or Shared

For each category, here is what to select:

#### Location
- [ ] Approximate location -- **NOT collected**
- [ ] Precise location -- **NOT collected**

#### Personal Info
- [x] Name -- **Collected** (only if user signs in with Google; comes from Google account)
- [x] Email address -- **Collected** (only if user signs in with Google; comes from Google account)
- [x] User IDs -- **Collected** (Firebase Auth UID, Crashlytics installation UUID)
- [ ] Address -- NOT collected
- [ ] Phone number -- NOT collected
- [ ] Race and ethnicity -- NOT collected
- [ ] Political or religious beliefs -- NOT collected
- [ ] Sexual orientation -- NOT collected
- [ ] Other info -- NOT collected

#### Financial Info
- All sub-types: **NOT collected** (no in-app purchases)

#### Health and Fitness
- [ ] Health info -- **NOT collected**
- [ ] Fitness info -- **NOT collected**
  - Note: Toothbrushing data could theoretically be "health info" but it is not medical/health data in Google's taxonomy. It is game progress (stars, streaks). If Google asks, it's "App activity."

#### Messages
- All sub-types: **NOT collected**

#### Photos and Videos
- [ ] Photos -- **NOT collected**
- [ ] Videos -- **NOT collected**
  - Note: Camera is used for LOCAL motion detection only. Frames are processed on-device as 32x32 luminance samples. No images are stored, transmitted, or saved.

#### Audio Files
- All sub-types: **NOT collected**

#### Files and Docs
- **NOT collected**

#### Calendar
- **NOT collected**

#### Contacts
- **NOT collected**

#### App Activity
- [x] App interactions -- **Collected** (Firebase Analytics tracks events: brush_session_start, brush_session_complete, hero_unlock, etc.)
- [ ] In-app search history -- NOT collected
- [ ] Installed apps -- NOT collected
- [ ] Other user-generated content -- NOT collected
- [ ] Other actions -- NOT collected

#### Web Browsing
- **NOT collected**

#### App Info and Performance
- [x] Crash logs -- **Collected** (Firebase Crashlytics)
- [x] Diagnostics -- **Collected** (Firebase Crashlytics collects device state, stack traces)
- [ ] Other app performance data -- NOT collected

#### Device or Other IDs
- [x] Device or other IDs -- **Collected** (Firebase installation ID, Crashlytics installation UUID)

### Section 3 -- Data Usage and Handling (per selected data type)

For each data type you selected above, you will be asked:

---

#### Personal Info > User IDs

**Is this data collected, shared, or both?**
- [x] Collected
- [ ] Shared

**Is this data processed ephemerally?**
- No (stored in Firebase)

**Is this data required, or can users choose whether it's collected?**
- User IDs from Crashlytics: Required (auto-generated, not personally identifiable)
- User IDs from Auth: Optional (only when user signs in)
- Select: **Data collection is required** (Crashlytics UUID is automatic)

**Why is this data collected?**
- [x] App functionality (authentication, cloud sync)
- [x] Analytics
- [ ] Developer communications
- [ ] Advertising or marketing
- [x] Fraud prevention, security, and compliance
- [ ] Personalization
- [x] Account management

---

#### Personal Info > Name (if prompted -- declare only if Google Sign-In sends it)

**Is this data collected, shared, or both?**
- [x] Collected
- [ ] Shared

**Is this data required?**
- Optional (user must opt in to Google Sign-In)

**Why is this data collected?**
- [x] App functionality (display name in account section)
- [x] Account management

---

#### Personal Info > Email Address (same as Name -- from Google Sign-In)

**Is this data collected, shared, or both?**
- [x] Collected
- [ ] Shared

**Is this data required?**
- Optional (user must opt in to Google Sign-In)

**Why is this data collected?**
- [x] App functionality
- [x] Account management

---

#### App Activity > App Interactions

**Is this data collected, shared, or both?**
- [x] Collected
- [ ] Shared
  - Note: Firebase Analytics data goes to Google's servers but this is "collection" not "sharing" because Google processes it on your behalf (first-party analytics). However, some interpretations say this IS sharing with Google. The conservative answer is:
- [x] Shared (with Google/Firebase for analytics processing)

**Is this data required?**
- Required (Firebase Analytics runs automatically)

**Why is this data collected?**
- [x] Analytics

---

#### App Info and Performance > Crash Logs

**Is this data collected, shared, or both?**
- [x] Collected
- [x] Shared (with Google/Firebase for crash reporting)

**Is this data required?**
- Required (Crashlytics runs automatically)

**Why is this data collected?**
- [x] App functionality (crash reporting to improve stability)
- [x] Analytics

---

#### App Info and Performance > Diagnostics

**Is this data collected, shared, or both?**
- [x] Collected
- [x] Shared (with Google/Firebase)

**Is this data required?**
- Required (Crashlytics collects automatically)

**Why is this data collected?**
- [x] App functionality
- [x] Analytics

---

#### Device or Other IDs

**Is this data collected, shared, or both?**
- [x] Collected
- [x] Shared (Firebase installation ID sent to Google servers)

**Is this data required?**
- Required (Firebase generates automatically)

**Why is this data collected?**
- [x] App functionality
- [x] Analytics
- [x] Fraud prevention, security, and compliance

---

### Section 4 -- Preview and Submit

Review the preview. It should show something like:

**Data collected:**
- Personal info (User IDs, Name*, Email*)
- App activity (App interactions)
- App info and performance (Crash logs, Diagnostics)
- Device or other IDs

*Name and Email only collected when user opts in to Google Sign-In

**Data shared:**
- App activity (with Google for analytics)
- App info and performance (with Google for crash reporting)
- Device or other IDs (with Google/Firebase)

**Security practices:**
- Data is encrypted in transit
- You can request that data be deleted

---

## 4. App Access

**Path:** Play Console > Policy and programs > App content > App access > Start

**"Are all features in your app available without any special access, such as login credentials, memberships, location, or other authentication?"**

- Answer: **All functionality is available without special access**

Rationale: All core features (brushing timer, heroes, shop, achievements, worlds) work without login. Google Sign-In is optional and only used for cloud backup. No features are gated behind authentication.

If Google requires login credentials anyway (unlikely given the above):
- Name: Test Account
- Username: (provide a test Google account if needed)
- Password: (provide password)
- Instructions: "Google Sign-In is optional. All features are accessible without signing in. To test cloud sync, tap the Settings gear > Account section > Sign in with Google."

---

## Summary Checklist

Before submitting, verify:

- [ ] Content rating questionnaire completed (expect: Everyone / PEGI 3)
- [ ] Target audience set to Ages 5 and under + Ages 6-8 + Ages 9-12
- [ ] Families Policy compliance confirmed
- [ ] Data Safety form completed with all Firebase data types declared
- [ ] Privacy policy URL entered: https://brushquest.app/privacy-policy.html
- [ ] App access marked as "All functionality available without special access"
- [ ] Ads declaration: No ads in this app
- [ ] Government apps: Not a government app
- [ ] Financial features: No financial features
- [ ] Health apps: Not a health app

---

## Important Notes

### Firebase Analytics Disclosure

The app uses Firebase Analytics with COPPA-compliant settings:
- Ad ID collection DISABLED (`google_analytics_adid_collection_enabled = false` in AndroidManifest.xml)
- Ad storage consent DENIED in code
- Ad user data consent DENIED in code  
- Ad personalization signals DENIED in code
- Only analytics storage consent is granted

This means you must still declare analytics data collection in the Data Safety form, but you can truthfully state that no advertising identifiers are collected and no data is used for advertising purposes.

### Firebase Crashlytics Disclosure

Crashlytics automatically collects:
- Crash stack traces
- Device metadata (OS version, device model, RAM -- point-in-time, not tracked)
- Crashlytics installation UUID (not personally identifiable)
- Application state at crash time

All of this must be declared in the Data Safety form under "App info and performance" and "Device or other IDs."

### Camera Disclosure

The camera is used ONLY for local motion detection (processing 32x32 luminance frames on-device). No images are captured, stored, or transmitted. You do NOT need to declare "Photos and videos" in the Data Safety form. If Google asks about the CAMERA permission in a separate permissions declaration, explain: "Camera is used for local motion detection during the toothbrushing game to detect if the child is moving their arm. Processing happens entirely on-device. No images are captured, stored, or transmitted."

### Account Deletion Requirement

Google requires apps with account creation to provide account deletion. Brush Quest satisfies this:
- In-app: Settings > "Delete child's data" (deletes all local data + Firestore document)
- The deletion is behind a parent gate (math problem)
- Consider adding a web-based deletion request option at brushquest.app if Google requests it

## Sources

- [Content Ratings -- Play Console Help](https://support.google.com/googleplay/android-developer/answer/9898843)
- [Content Rating Requirements](https://support.google.com/googleplay/android-developer/answer/9859655)
- [Target Audience and Content Settings](https://support.google.com/googleplay/android-developer/answer/9867159)
- [Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Data Safety Form](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Firebase Play Data Disclosure](https://firebase.google.com/docs/android/play-data-disclosure)
- [Firebase Analytics Data Disclosure](https://support.google.com/analytics/answer/11582702)
- [Data Practices in Families Apps](https://support.google.com/googleplay/android-developer/answer/11043825)
- [App Access Requirements](https://support.google.com/googleplay/android-developer/answer/15748846)
- [Families Program](https://play.google.com/console/about/programs/families/)
- [Declare Your App's Data Use (Android Developers)](https://developer.android.com/privacy-and-security/declare-data-use)
