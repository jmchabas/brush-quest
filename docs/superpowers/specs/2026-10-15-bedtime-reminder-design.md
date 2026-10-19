# Parent bedtime reminder — design (v1.1)

**Status:** approved by Jim on 2026-09-28 (Game Evaluation & Stickiness Plan, bet 3), and on 2026-10-15 brought into the v1.1 sticker-card work. The full research behind it, including usage data, lives in the local notes (`.remember/v29-launch/product-questions/notification-permission.md`). Copy changes for the sticker card come from `2026-10-15-sticker-card-design.md` §4.7.

## 1. What and why
- **What:** one local notification to the parent each evening (optionally each morning), at a time the parent sets, only if that slot hasn't been brushed yet.
- **Why:** on a parent's phone, the parent usually starts the brushing. Since the sticker card puts no loss pressure on the child, the every-day push is the reminder's job. Target, from the product plan: day-7 brushing retention up and at least half of parents opting in.
- **Never:** guilt, streak threats, anything addressed to the child, "we miss you" nudges, badges, or more than one per slot per day.

## 2. When we ask
| Offer | When | Conditions |
|---|---|---|
| 1 | After the **first completed brush**, when DONE is tapped (after the closing line, before Home) | Reminders not on; the OS permission not permanently denied |
| 2 | After the **3rd completed brush**, on a later calendar day than offer 1 | Offer 1 ended in a skip, a timeout, or a cancelled gate. Not after "Not now" on the parent screen, and not after an OS denial |
| Never again | After offer 2, or after any parent decision (enabled, "Not now", OS denied) | The Parent Zone card stays |

State in prefs: `reminder_offer_count`, `reminder_offer_last_date`, `reminder_decided`. These keys are per device and stay out of `SyncService._syncKeys`.

## 3. The screens

### 3.1 Screen A: the hand-off (child-facing, once or twice ever)
- A one-time screen between the victory screen and Home. **Home is not changed.**
- Shows an illustration only: the hero, an arrow, a grown-up with a phone.
- Buddy: "Great mission! Grown-ups, tap the lock for a bedtime reminder." (new line, needs Jim's OK as Tier 3 audio; without it the screen still works, but more children will skip).
- A big lock button opens the existing parent gate (math check, `barrierDismissible: false`). A skip arrow, or 15 s with no tap, goes to Home as usual.
- The 15 s timer is a `Timer?` field cancelled in `dispose`.

### 3.2 Screen B: the parent pre-permission screen (behind the gate)
- Title: "Want a bedtime brushing reminder?" Text: "One reminder on this phone each evening, only if brushing hasn't happened yet. Your reminder times stay on this phone." (Jim, 2026-10-19: was "It stays on this device; nothing is sent to us.", untrue next to the Android analytics)
- "Remind me at" a time picker. The default is 7:30 pm. If the first brush was between 5:30 and 9:30 pm, the default is that time minus 30 minutes, rounded to the quarter hour and kept between 6:30 and 9:00 pm.
- "Morning reminder too", unticked by default, 7:00 am.
- **TURN ON:**
  1. Request the OS permission: Android 13+ `POST_NOTIFICATIONS`; iOS alert and sound, no badge, never provisional.
  2. If granted: save the times, schedule, and show "Reminder set for 7:45 PM".
  3. If denied: save nothing as enabled and set `reminder_decided`.
- **Not now:** set `reminder_decided` and go Home.
- The line "Change or turn off anytime: Parents > Settings > Reminders".

### 3.3 Parent Zone
- A new REMINDERS card in Settings with the same toggles and times.
- If the OS has blocked notifications: "Notifications for Brush Quest are off in your phone settings." and an **Open phone settings** button. This link out is allowed because the Parent Zone is behind the gate.
- A matching paragraph in the Guide tab.

## 4. The notification
- **For the parent:** the app icon as the large icon, a monochrome tooth-and-moon small icon. No hero picture.
- **Evening copy** (rotates by day):
  - "Brushing time!" / "Tonight's cavity monsters are waiting."
  - "Bedtime brush: 2 minutes, one monster battle."
  - On a gift night (the next sticker is the 3rd or the 7th): "Brushing time! Tonight's brush opens a gift on the sticker card."
- **Morning copy:** "Morning brush: 2 minutes before the day starts."
- **Rules:**
  - At most one per enabled slot per day; skipped when that slot is already brushed (morning is before noon), and while the parent Pause is on.
  - Not shown while the app is in the foreground.
  - Scheduled 7 days ahead, so a week without opening the app means at most 7 reminders, then silence.
- **Tap:** opens the app to Home with its usual greeting. No deep link.
- **Off switches:** the Parent Zone toggles; the OS settings; the Android channel "Brushing reminders". "Reset all progress" cancels everything.
- **Dropped from the March design:** the 7/14/30-day milestone notifications, and the "3 nights in a row" line (with grace days, its count could be false).

## 5. How it works
- **Package:** `flutter_local_notifications` ^22 (works with Flutter 3.41.4) and `timezone`. No FCM, no remote config, no server.
- **Scheduling:** rolling one-shot notifications, not a repeating trigger, so a brushed day can be skipped.
  - Each of the next 7 days gets its own instant, built in local time, so daylight-saving changes are handled.
  - IDs: evening 1xx, morning 2xx; at most 14 pending.
- `ReminderService.reschedule()` runs:
  - at app start and resume;
  - after every recorded brush (which cancels today's instance for that slot);
  - when the Pause or a setting changes.
- **Android:**
  - `inexactAllowWhileIdle`, channel `brush_reminders`.
  - `RECEIVE_BOOT_COMPLETED` and the plugin's boot and scheduled receivers (`exported=false`).
  - No exact-alarm permission: Play allows it only for alarm and calendar apps. Inexact alarms can be up to about an hour late, so the default sits before the usual brush time; if they run late in practice, move the default earlier.
  - Core library desugaring (a plugin requirement); a new monochrome `ic_stat_` icon.
- **iOS:**
  - No permission request at start-up.
  - Set the notification-centre delegate in `AppDelegate`, separately from the audio-session observers.
  - Re-run `scripts/check_ios_kids_binary.sh`, since the plugin adds a pod. The privacy manifest must still declare no tracking and no collected data.
- **Privacy:**
  - The App Store label is unchanged ("Data Not Collected").
  - Add one sentence to the privacy policy (legal copy, Jim's review): "Optional bedtime reminders are scheduled and shown on your device; apart from the anonymous usage analytics described below (Android only), no information about them is sent to us."

## 6. Analytics (Android only)
- Events:
  - `reminder_offer_shown {offer: 1|2|parent_zone}`
  - `reminder_offer_result {result: gate_opened|skipped|timeout|not_now|os_denied|enabled}`
  - `reminder_enabled {morning}` (evening_hour dropped 2026-10-19)
  - `app_open_from_reminder {slot}`
- User property `reminder_on`.
- Nothing identifying.

## 7. Testing
- **Structural gate test** (the camera-flow pattern): gate, then consent screen, then OS request, then the flag is saved only if granted.
- **Unit tests for the schedule:**
  - a daylight-saving weekend;
  - cancelling today after a brush;
  - the Pause window;
  - the 7-day horizon;
  - the personalised default time;
  - the gift-night copy.
- **Widget test:** Screen A advances after 15 s and cancels its timer.
- **Device:**
  - three evenings on Jim's Android phone at the set time, to check lateness;
  - one hand-off test with Oliver: does he give the phone to a parent or tap the arrow? (Hard Block.)

## 8. Decisions for Jim
1. The new Buddy line for Screen A: "Great mission! Grown-ups, tap the lock for a bedtime reminder." *Recommend yes.*
2. The privacy-policy sentence in §5. *Recommend yes.*
