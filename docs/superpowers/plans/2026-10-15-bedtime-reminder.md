# Parent Bedtime Reminder Implementation Plan (v1.1 rework 2, Part C)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the first finished brush (and once more after the 3rd, on a later day), a one-time hand-off screen sends the child to a grown-up. Behind the GROWN-UP CHECK, the parent can turn on one local notification each evening (and, if wanted, each morning). It fires only if that brush hasn't happened yet. A REMINDERS card in Parents > Settings manages it.

**Architecture:** Three layers.
- `lib/services/reminder_plan.dart` holds the rules as pure functions: the week's one-shot reminders, the copy, the offers, the default time.
- `lib/services/reminder_platform.dart` is the only file that touches `flutter_local_notifications`. It sits behind a `ReminderPlatform` interface that tests fake.
- `ReminderService` (a singleton, like the other services) joins them. It keeps the parent's settings and the offer state in SharedPreferences (never synced), and owns a guarded, serialised `reschedule()` plus the analytics. `reschedule()` runs at start, on resume and pause, after every brush, and on every setting change.

The UI adds two screens (the child's hand-off, the parent's pre-permission screen), the shared GROWN-UP CHECK (moved out of onboarding) and a Parent Zone card. Home is not changed.

**Tech Stack:** Flutter 3.41.4 / Dart 3.11.1; `flutter_local_notifications` 22.3.2 and `timezone` 0.11.2; SharedPreferences; very_good_analysis 7; flutter_test with `FakeAudioService` / `TimedFakeAudioService`, a fake `ReminderPlatform` and `AnalyticsService.forTesting(isAndroid: true)`.

**Spec:** `docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md` (approved 2026-09-28, brought into v1.1 on 2026-10-15).
- Both §8 decisions are **yes** (Jim): the hand-off Buddy line, and the privacy-policy sentence.
- What the reminder says about the card comes from `docs/superpowers/specs/2026-10-15-sticker-card-design.md` §4.7.
- The approved research behind it is the local file `.remember/v29-launch/product-questions/notification-permission.md`. It is never committed. Read it for the platform rules, but don't copy its usage data anywhere.

**Checked while planning:** every task below was applied, as written, to a clean export of commit 8f6872d (outside the repo).
- All 1393 tests pass (41 of them also under `TZ=Europe/Paris`).
- `dart analyze`, DCM and `dart format` are clean; semgrep reports 0 findings.
- The Android debug build and the iOS release build succeed, and the iOS Kids Category gate passes.

Where a step's text and the real code ever disagree, trust the code you read and report it.

**Gift nights, before the sticker card exists:** the card (Part B) isn't built yet.
- `ReminderService` asks for one plain boolean through a function type, `GiftNightCheck`: does the next sticker the card places open a gift (is it the 3rd or the 7th)?
- Until Part B ships, the default `noStickerGifts` always answers false, so no reminder carries the gift line.
- Part B wires the real answer with a one-line change in `ReminderService._instance` (Task 3, Step 6).
- `planReminders` turns that boolean into "is tonight a gift night", night by night. Tonight counts only if nothing was brushed yet today, because the first finished brush of a day places that day's sticker. Every later night counts.

## Global Constraints

- **Packages**, pinned exactly in `dependencies`: `flutter_local_notifications: 22.3.2` and `timezone: 0.11.2`.
  - 22.3.2 needs Flutter >= 3.38.1 and Dart ^3.10.0. 23.0.0-dev needs Dart 3.12, so not that.
  - No `firebase_messaging`, no `flutter_timezone`, no server.
  - `audioplayers` stays exactly as pinned (`test/audio/audioplayers_pin_test.dart`).
- **Platform floors**, already met: Android minSdk 24, compileSdk 36, AGP 8.11.1, JDK 17; iOS deployment target 15.0 (the plugin needs 13); CocoaPods, not Swift Package Manager.
- **Prefs keys**: per device, never added to `SyncService._syncKeys`.
  - `reminder_evening_enabled` (bool), `reminder_evening_time` (int, minutes after midnight)
  - `reminder_morning_enabled`, `reminder_morning_time`
  - `reminder_offer_count` (int 0–2), `reminder_offer_last_date` ('yyyy-mm-dd'), `reminder_decided` (bool)
- **Offers** (spec §2):
  - Offer 1: the first finished brush with no offer made yet.
  - Offer 2: after offer 1 ended in a skip, a timeout or a cancelled gate; from the 3rd finished brush, on a later date.
  - Never: after `reminder_decided` (TURN ON allowed or refused, or Not now), while a reminder is on, or after offer 2.
- **Times:**
  - Evening default: 7:30 PM. If the first brush was between 5:30 and 9:30 pm, it is that time minus 30 min, rounded to the nearest quarter hour and clamped to 6:30–9:00 PM.
  - Morning: 7:00 AM, off by default.
  - Choices are quarter hours: evening 5:00 PM–10:00 PM, morning 5:30 AM–10:00 AM. Shown as "7:45 PM".
- **Schedule:** rolling one-shots for 7 calendar days, today included.
  - Each is built in local time for its own date and passed as an absolute instant: `tz.TZDateTime.from(local, tz.UTC)`, never `matchDateTimeComponents`.
  - Ids follow the date: evening `100 + dayNumber % 7`, morning `200 + dayNumber % 7`.
  - Skipped: a time not after now; today's slot if already brushed (morning = before noon); anything today while the app is in the foreground; anything before `streak_pause_until`.
- **Notification copy** (title / text), exactly:
  - "Brushing time!" / "Tonight's cavity monsters are waiting."
  - "Bedtime brush" / "2 minutes, one monster battle."
  - Gift night: "Brushing time!" / "Tonight's brush opens a gift on the sticker card."
  - Morning: "Morning brush" / "2 minutes before the day starts."
  - The two evening lines alternate by date.
- **Screen A (the hand-off):**
  - No text at all.
  - Buddy plays `voice_reminder_handoff.mp3` ("Great mission! Grown-ups, tap the lock for a bedtime reminder.", 3.9 s) once, on entry.
  - The lock opens the shared GROWN-UP CHECK (`barrierDismissible: false`), then Screen B.
  - The arrow, the back gesture, or `ReminderHandoffScreen.idleTimeout` (15 s without any touch) go Home: `HomeScreen(skipGreeting: true)`, fading in, no route left behind.
  - The 15 s is a `Timer?` field cancelled in `dispose`. It is stopped while the gate or Screen B is up.
- **Screen B copy**, exactly:
  - "FOR GROWN-UPS", "Want a bedtime brushing reminder?"
  - "One reminder on this phone each evening, only if brushing hasn't happened yet. It stays on this device; nothing is sent to us."
  - "Remind me at", "Morning reminder too", "TURN ON", "Not now", "Change or turn off anytime: Parents > Settings > Reminders"
  - "Reminder set for 7:45 PM" or "Reminders set for 7:45 PM and 7:00 AM", held `ReminderParentScreen.confirmationHold` = 2.5 s, then Home.
- **Parent Zone copy**, exactly: the section "REMINDERS"; the rows "Bedtime reminder" and "Morning reminder"; "Only if that brush hasn't happened yet. Stays on this phone."; "Notifications for Brush Quest are off in your phone settings."; the button "Open phone settings".
- **The OS permission prompt** comes only from TURN ON (Screen B) or a Parent Zone switch turned on, through `ReminderService.turnOn`.
  - The reminder is saved only when the OS allows it. Any OS answer sets `reminder_decided`.
  - Android: `requestNotificationsPermission()` (POST_NOTIFICATIONS on 13+).
  - iOS: `requestPermissions(alert: true, sound: true, badge: false, provisional: false)`. The `DarwinInitializationSettings` request flags are all false, because the plugin's defaults would prompt at launch.
- **Android:**
  - `AndroidScheduleMode.inexactAllowWhileIdle`; channel `brush_reminders`, named "Brushing reminders", default importance.
  - Small icon `ic_stat_brush_reminder` (a monochrome tooth with a crescent moon); large icon `ic_reminder_large` (the app icon); accent `0xFF7C4DFF`.
  - `RECEIVE_BOOT_COMPLETED`, plus `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` with `android:exported="false"`.
  - Core library desugaring with `desugar_jdk_libs:2.1.4`; `res/raw/keep.xml` keeps both icons.
  - Never `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` or `USE_FULL_SCREEN_INTENT`.
- **iOS:**
  - The notification-centre delegate is set in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, apart from the audio-session observers.
  - Foreground presentation is off (`presentAlert/Banner/List/Badge: false`), but `presentSound: true`: the plugin gives the notification its sound only when this is true.
  - `scripts/check_ios_kids_binary.sh` must PASS, and the plugin's privacy manifest must declare no tracking and no collected data.
- **Analytics** (Android only; a no-op on iOS). Nothing identifying.
  - `reminder_offer_shown {offer: '1'|'2'|'parent_zone'}`
  - `reminder_offer_result {result: gate_opened|skipped|timeout|not_now|os_denied|enabled}`
  - `reminder_enabled {evening_hour: int, morning: 0|1}`
  - `app_open_from_reminder {slot: 'evening'|'morning'}`
  - User property `reminder_on`: 'true' or 'false'.
- **Plugin calls are guarded.**
  - Every call into the plugin goes through `ReminderService`'s guards (`on Object catch`). An unregistered plugin throws `LateInitializationError`, which is an `Error`.
  - Nothing is scheduled before `init()` succeeds, so tests that never call it touch no plugin.
- **Unchanged screens:** Home is not changed (no new element, no new start affordance), and pages opened from Home are unchanged. No new art: Material icons and the existing hero art only.
- **Delays:** every delay in a widget is a `Timer?` field cancelled in `dispose()`. No `Future.delayed` in new code.
- **Lints that bite here:**
  - `one_member_abstracts`: a one-method interface must be a function type.
  - `avoid_positional_boolean_parameters` (public members).
  - `no_default_cases`: use a switch expression with `_ =>`.
  - `only_throw_errors`, `avoid_setters_without_getters`, `unawaited_futures` (wrap in `unawaited(...)` from `dart:async`), `use_build_context_synchronously`, `comment_references`, `unintended_html_in_doc_comment`.
- **Before every commit:** `dart format lib test`. `dart analyze` must say "No issues found!", and `dart run dart_code_linter:metrics analyze lib` must say "no issues found!". `flutter test` must pass; run the full suite before each commit that touches shared code.
- **The repo is public:** never `git add` anything under `.remember/`; stage files by name, never `git add -A`; no usage numbers in committed docs.
- **Commit messages** end with these two lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M
  ```
- **Shared test setup** (Firebase mocks, the audioplayers channels, `AudioService.testInstance`) follows `test/screens/victory_goal_test.dart` and `test/screens/settings_copy_test.dart`.

**Rulings (spec ambiguities resolved, for Jim's plan review):**
- **R-1 Players from before this version** get offer 1 at their first finished brush on it ("no offer made yet"), then offer 2 by the usual rule. The spec only describes a new player's first brush; read literally, nobody already playing could ever be offered.
- **R-2 Gift nights:** one plain boolean, "the next sticker opens a gift", through `GiftNightCheck`; always false until Part B. A literal "tonight is a gift night" flag would never reach an evening brusher. His sticker lands after tonight's reminder time, and tomorrow's reminder is planned right after that brush.
- **R-3 Copy split:** each approved line is split at its natural break into the notification's title and text: "Bedtime brush" / "2 minutes, one monster battle." and "Morning brush" / "2 minutes before the day starts."
- **R-4 Not shown while the app is open:** Android has no switch for that. So today's reminders are held while the app is in the foreground, and planned again when it is left; iOS also hides foreground banners. Consequence: if the app is open at the reminder time and left after it without a brush, that night has no reminder.
- **R-5 Time picker:** a list of quarter hours (5–10 pm, 5:30–10 am), not the clock dialog. It keeps each reminder on its own side of noon, where the slot rule splits the day, and matches the research mock-up ("[ 7:45 PM v ]").
- **R-6 Analytics and "permanently denied":** `reminder_offer_shown {offer: parent_zone}` is sent when the parent turns a Parent Zone switch on, and is paired with its result. "OS permission permanently denied" is known only from our own flow, since the OS answer sets `reminder_decided`. Android 13+ can't tell "never asked" from "refused".
- **R-7 The gate:** the onboarding's GROWN-UP CHECK moves, unchanged, to `lib/widgets/parent_gate_dialog.dart`, so the hand-off uses the very same one.
- **R-8 Confirmation:** "Reminder set for …" stays on Screen B for 2.5 s, then Home. A SnackBar would land on Home, which must not change. After an OS refusal, straight Home.
- **R-9 Ids follow the date** (`dayNumber % 7`), not the day's index from today. Planning the week again then replaces the same night's reminder, and also clears it if it is still showing.
- **R-10 New parent copy to review:** the Guide's "Bedtime Reminder" paragraph and the Parent Zone card's lines (Task 8).

## Review Focus

1. The app is open (the child is brushing) at the reminder time: no sound or banner mid-brush. Pinned by Task 1 "while the app is open, today's reminders wait" and Task 3 "leaving the app brings tonight back; coming back holds it again".
2. The plugin fails with an `Error`, not an `Exception`. An unregistered plugin throws `LateInitializationError` (the repo's "`on Exception` misses StateError" lesson). Start-up, the victory screen and Settings must carry on. Pinned by Task 3 "a failing plugin never throws (an Error)" and "nothing touches the plugin before init".
3. The back gesture on the hand-off screen, which is the only route left: it must go Home, not close the app. Pinned by Task 6 "the back button goes Home, never out of the app".
4. The parent taps "Open phone settings", allows notifications there and comes back: the warning must go. Pinned by Task 8 "back from the phone's settings with notifications allowed: the note goes".
5. One instant fails to schedule (it became the past while planning, and the plugin throws ArgumentError): the rest of the week must still be scheduled. Pinned by Task 3 "one instant that fails to schedule does not stop the rest".

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/services/reminder_plan.dart` | Create | Pure rules: times, choices, ids, settings, copy, `planReminders`, offers, results, default time, confirmation |
| `lib/services/reminder_platform.dart` | Create | `ReminderPlatform` interface and `PluginReminderPlatform`, the only user of `flutter_local_notifications` |
| `lib/services/reminder_service.dart` | Create | `ReminderService`: prefs, guarded serialised `reschedule()`, offers, `turnOn`, reset, analytics; `GiftNightCheck` |
| `lib/services/analytics_service.dart` | Modify | Four reminder events and the `reminder_on` user property |
| `lib/services/streak_service.dart` | Modify | `dateKey()` and `getSlotsOn(day)` (`getTodaySlots()` delegates) |
| `lib/services/audio_service.dart` | Modify | Preload `voice_reminder_handoff.mp3` |
| `lib/widgets/parent_gate_dialog.dart` | Create | The GROWN-UP CHECK, moved from onboarding: `showParentGate()`, `ParentGateDialog` |
| `lib/screens/onboarding_screen.dart` | Modify | Uses the shared gate; its private copy is deleted |
| `lib/screens/after_brush_home.dart` | Create | `AfterBrushHome`: the fade to `HomeScreen(skipGreeting: true)`, with a test seam |
| `lib/widgets/reminder_time_dropdown.dart` | Create | `ReminderTimeDropdown` (quarter hours, tolerant of an odd saved time) |
| `lib/screens/reminder_parent_screen.dart` | Create | Screen B, the parent's pre-permission screen |
| `lib/screens/reminder_handoff_screen.dart` | Create | Screen A, the child's hand-off |
| `lib/screens/victory_screen.dart` | Modify | Replans after `recordBrush`; DONE goes to the hand-off when an offer is due |
| `lib/main.dart` | Modify | `ReminderService().init()`, plus resume and pause |
| `lib/widgets/reminder_settings_card.dart` | Create | The Parent Zone REMINDERS card |
| `lib/screens/settings_screen.dart` | Modify | REMINDERS section, Pause replans, Start fresh clears, Guide paragraph |
| `assets/audio/voices/buddy/voice_reminder_handoff.mp3` | Add | Copied from `.remember/v1.1/voice-staging/` |
| `android/app/build.gradle.kts` | Modify | Core library desugaring |
| `android/app/src/main/AndroidManifest.xml` | Modify | Boot permission and the two receivers |
| `android/app/src/main/res/drawable/ic_stat_brush_reminder.xml` | Create | Small monochrome icon |
| `android/app/src/main/res/drawable-nodpi/ic_reminder_large.png` | Add | Copy of the launcher PNG, as the large icon |
| `android/app/src/main/res/raw/keep.xml` | Create | Keeps both icons through resource shrinking |
| `ios/Runner/AppDelegate.swift` | Modify | The notification-centre delegate |
| `ios/Podfile.lock` | Modify | The new pod (written by `pod install`) |
| `pubspec.yaml`, `pubspec.lock` | Modify | The two packages |
| `docs/privacy-policy.html` | Modify | The one approved sentence (the live policy: GitHub Pages serves `main:/docs`) |
| `docs/ios-port/privacy-manifest-audit.md` | Modify | A row for the new plugin |
| `CLAUDE.md`, `STATUS.md` | Modify | Dependencies, architecture, game flow, settings, status |
| `test/services/reminder_plan_test.dart` | Create | Task 1 |
| `test/services/reminder_fakes.dart` | Create | `FakeReminderPlatform`, `RecordingAnalytics`, `installReminderService()` |
| `test/flows/reminder_platform_setup_test.dart` | Create | Structural: packages, manifest, Gradle, icons, plugin flags, AppDelegate, policy |
| `test/services/reminder_service_test.dart` | Create | Task 3 |
| `test/services/analytics_service_test.dart`, `test/services/streak_service_test.dart` | Modify | New methods |
| `test/widgets/parent_gate_dialog_test.dart` | Create | The shared gate |
| `test/flows/camera_mode_flow_test.dart` | Modify | Its gate check follows the gate to its new file |
| `test/widgets/reminder_time_dropdown_test.dart` | Create | Task 5 |
| `test/screens/reminder_parent_screen_test.dart` | Create | Task 5 |
| `test/screens/reminder_handoff_screen_test.dart` | Create | Task 6 |
| `test/audio/audio_assets_test.dart` | Modify | Registers the new voice |
| `test/flows/reminder_offer_flow_test.dart` | Create | Structural: gate, then consent, then OS prompt, then saved only if allowed; wiring |
| `test/screens/victory_reminder_offer_test.dart` | Create | DONE → hand-off or Home; replan after the brush |
| `test/widgets/reminder_settings_card_test.dart` | Create | Task 8 |
| `test/screens/settings_reminders_test.dart` | Create | Card placement; Pause and Start fresh wiring |
| `test/screens/settings_copy_test.dart` | Modify | The Guide paragraph, word for word |

---

### Task 1: The reminder's rules (pure Dart)

**Files:**
- Create: `lib/services/reminder_plan.dart`
- Create: `test/services/reminder_plan_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (every later task uses these exact names):
  - `typedef ReminderTime = ({int hour, int minute});`
  - `const ReminderTime kDefaultEveningTime` (19:30), `const ReminderTime kDefaultMorningTime` (7:00), `const kReminderHorizonDays = 7;`
  - `int reminderMinutes(ReminderTime time)`, `ReminderTime reminderTimeFromMinutes(int minutes)`, `String formatReminderTime(ReminderTime time)` ("7:45 PM")
  - `final List<ReminderTime> eveningReminderChoices` (5:00 PM–10:00 PM), `final List<ReminderTime> morningReminderChoices` (5:30 AM–10:00 AM)
  - `enum ReminderSlot { evening, morning }` with `final int idBase` (100, 200)
  - `int reminderIdFor(ReminderSlot slot, DateTime day)`, `List<int> allReminderIds()`, `bool isReminderId(int id)`
  - `class ReminderSettings` with `const ReminderSettings({bool eveningOn = false, ReminderTime evening = kDefaultEveningTime, bool morningOn = false, ReminderTime morning = kDefaultMorningTime})`, `bool get anyOn`, `ReminderSettings copyWith({bool? eveningOn, ReminderTime? evening, bool? morningOn, ReminderTime? morning})` and value equality
  - `typedef ReminderCopy = ({String title, String body});` and the constants `kEveningCopyMonsters`, `kEveningCopyBattle`, `kEveningCopyGift`, `kMorningCopy`
  - `class PlannedReminder` with `final int id; final ReminderSlot slot; final DateTime at; final String title; final String body;` and value equality
  - `List<PlannedReminder> planReminders({required DateTime now, required ReminderSettings settings, bool morningDoneToday = false, bool eveningDoneToday = false, DateTime? pauseUntil, bool nextStickerOpensGift = false, bool appInForeground = false})`
  - `enum ReminderOffer { first, second }` with `int get number` (1, 2)
  - `ReminderOffer? reminderOfferDue({required int offersShown, required String? lastOfferDate, required bool decided, required bool remindersOn, required int totalBrushes, required String today})`
  - `enum ReminderOfferResult { gateOpened, skipped, timeout, notNow, osDenied, enabled }` with `final String analyticsName` ('gate_opened', 'skipped', 'timeout', 'not_now', 'os_denied', 'enabled')
  - `ReminderTime defaultEveningTime(String? firstBrushTime)`, `String reminderConfirmation(ReminderSettings settings)`

- [ ] **Step 1: Write the failing tests**

Create `test/services/reminder_plan_test.dart`:

```dart
// test/services/reminder_plan_test.dart
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's rules (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§5).
/// Run this file under TZ=America/Los_Angeles and TZ=Europe/Paris as well:
/// the daylight-saving tests need a zone whose clocks change.
void main() {
  const evenings = ReminderSettings(eveningOn: true);
  const both = ReminderSettings(eveningOn: true, morningOn: true);
  // A Thursday, 9 am: this morning's 7:00 is gone, tonight's 7:30 is ahead.
  final thursday = DateTime(2026, 10, 15, 9);

  List<DateTime> times(Iterable<PlannedReminder> plan) => [
    for (final r in plan) r.at,
  ];
  List<PlannedReminder> only(List<PlannedReminder> plan, ReminderSlot slot) => [
    for (final r in plan)
      if (r.slot == slot) r,
  ];

  group('planReminders', () {
    test('nothing on: nothing planned', () {
      expect(
        planReminders(now: thursday, settings: const ReminderSettings()),
        isEmpty,
      );
    });

    test('a week of evenings at 7:30 pm, soonest first', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(times(plan), [
        for (var d = 0; d < 7; d++) DateTime(2026, 10, 15 + d, 19, 30),
      ]);
      expect(plan.every((r) => r.slot == ReminderSlot.evening), isTrue);
    });

    test('mornings too, in time order with the evenings', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(times(plan.take(4)), [
        DateTime(2026, 10, 15, 7),
        DateTime(2026, 10, 15, 19, 30),
        DateTime(2026, 10, 16, 7),
        DateTime(2026, 10, 16, 19, 30),
      ]);
      expect(plan, hasLength(14));
    });

    test('one id per night and per morning, each once a week', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.evening)) r.id},
        {100, 101, 102, 103, 104, 105, 106},
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.id},
        {200, 201, 202, 203, 204, 205, 206},
      );
      expect(allReminderIds(), [
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        200,
        201,
        202,
        203,
        204,
        205,
        206,
      ]);
      expect(isReminderId(100), isTrue);
      expect(isReminderId(206), isTrue);
      expect(isReminderId(107), isFalse);
      expect(isReminderId(42), isFalse);
    });

    test('a night keeps its id, whenever the week is planned', () {
      final night = DateTime(2026, 10, 19, 19, 30);
      int idOn(DateTime now) => planReminders(
        now: now,
        settings: evenings,
      ).firstWhere((r) => r.at == night).id;
      expect(idOn(DateTime(2026, 10, 18, 9)), idOn(thursday));
      expect(
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 22)),
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 15)),
      );
      expect(
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 16)),
        isNot(reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 15))),
      );
    });

    test('nothing a week or more ahead', () {
      final plan = planReminders(now: thursday, settings: both);
      expect(plan.every((r) => r.at.isBefore(DateTime(2026, 10, 22))), isTrue);
    });

    test('a time already gone today waits for tomorrow', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 19, 30),
        settings: evenings,
      );
      expect(plan.first.at, DateTime(2026, 10, 16, 19, 30));
      expect(plan, hasLength(6));
    });

    test('an evening brush today drops tonight only', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 18),
        settings: both,
        eveningDoneToday: true,
      );
      expect(times(only(plan, ReminderSlot.evening)), [
        for (var d = 1; d < 7; d++) DateTime(2026, 10, 15 + d, 19, 30),
      ]);
      expect(times(only(plan, ReminderSlot.morning)), [
        for (var d = 1; d < 7; d++) DateTime(2026, 10, 15 + d, 7),
      ]);
    });

    test('a morning brush drops this morning only', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        morningDoneToday: true,
      );
      expect(
        only(plan, ReminderSlot.morning).first.at,
        DateTime(2026, 10, 16, 7),
      );
      expect(
        only(plan, ReminderSlot.evening).first.at,
        DateTime(2026, 10, 15, 19, 30),
      );
    });

    test('the parent Pause: nothing before the day it ends', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 18),
      );
      expect(times(plan), [
        for (var d = 18; d <= 21; d++) DateTime(2026, 10, d, 19, 30),
      ]);
    });

    test('a Pause that has ended changes nothing', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        pauseUntil: DateTime(2026, 10, 1),
      );
      expect(plan, hasLength(7));
    });

    test("while the app is open, today's reminders wait; the rest stay", () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        appInForeground: true,
      );
      expect(plan.where((r) => r.at.day == 15), isEmpty);
      expect(plan, hasLength(12));
    });

    test('across the end of the year', () {
      final plan = planReminders(
        now: DateTime(2026, 12, 29, 9),
        settings: evenings,
      );
      expect(plan.last.at, DateTime(2027, 1, 4, 19, 30));
    });
  });

  group('daylight saving', () {
    // US clocks go back on Sun 1 Nov 2026 and forward on Sun 14 Mar 2027;
    // EU clocks on Sun 25 Oct 2026 and Sun 28 Mar 2027.
    for (final start in [
      DateTime(2026, 10, 22, 9),
      DateTime(2026, 10, 29, 9),
      DateTime(2027, 3, 10, 9),
      DateTime(2027, 3, 25, 9),
    ]) {
      test('from ${start.month}/${start.day}: every reminder at its own '
          "date's 7:30 pm and 7:00 am", () {
        final plan = planReminders(now: start, settings: both);
        final nights = only(plan, ReminderSlot.evening);
        expect(nights, hasLength(7));
        for (var i = 0; i < nights.length; i++) {
          final at = nights[i].at;
          expect(at, DateTime(start.year, start.month, start.day + i, 19, 30));
          expect((at.hour, at.minute), (19, 30));
          if (i > 0) {
            final before = nights[i - 1].at;
            // One day on the wall clock: 24 h, plus the hour the clocks went
            // back (or minus the hour they went forward) in between.
            expect(
              at.difference(before),
              const Duration(hours: 24) +
                  (before.timeZoneOffset - at.timeZoneOffset),
            );
          }
        }
        expect(
          {
            for (final r in only(plan, ReminderSlot.morning))
              (r.at.hour, r.at.minute),
          },
          {(7, 0)},
        );
      });
    }

    final usChange =
        DateTime(2026, 10, 31, 19, 30).timeZoneOffset !=
        DateTime(2026, 11, 1, 19, 30).timeZoneOffset;
    final euChange =
        DateTime(2026, 10, 24, 19, 30).timeZoneOffset !=
        DateTime(2026, 10, 25, 19, 30).timeZoneOffset;
    test(
      'the night the clocks go back comes 25 hours after the one before',
      () {
        final night = usChange
            ? DateTime(2026, 11, 1, 19, 30)
            : DateTime(2026, 10, 25, 19, 30);
        final plan = planReminders(
          now: DateTime(night.year, night.month, night.day - 3, 9),
          settings: evenings,
        );
        final i = plan.indexWhere((r) => r.at == night);
        expect(i, greaterThan(0));
        expect(
          plan[i].at.difference(plan[i - 1].at),
          const Duration(hours: 25),
        );
      },
      skip: usChange || euChange
          ? false
          : 'no clock change in this zone: run with '
                'TZ=America/Los_Angeles or TZ=Europe/Paris',
    );
  });

  group('the copy', () {
    test('evenings alternate between the two approved lines', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(
        {for (final r in plan) (r.title, r.body)},
        {
          (kEveningCopyMonsters.title, kEveningCopyMonsters.body),
          (kEveningCopyBattle.title, kEveningCopyBattle.body),
        },
      );
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].body, isNot(plan[i - 1].body));
      }
    });

    test('a night keeps its line, whenever the week is planned', () {
      final night = DateTime(2026, 10, 19, 19, 30);
      String bodyOn(DateTime now) => planReminders(
        now: now,
        settings: evenings,
      ).firstWhere((r) => r.at == night).body;
      expect(bodyOn(DateTime(2026, 10, 18, 9)), bodyOn(thursday));
    });

    test('mornings say the morning line', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.title},
        {kMorningCopy.title},
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.body},
        {kMorningCopy.body},
      );
    });

    test('the approved words, for the parent only', () {
      expect(kEveningCopyMonsters, (
        title: 'Brushing time!',
        body: "Tonight's cavity monsters are waiting.",
      ));
      expect(kEveningCopyBattle, (
        title: 'Bedtime brush',
        body: '2 minutes, one monster battle.',
      ));
      expect(kEveningCopyGift, (
        title: 'Brushing time!',
        body: "Tonight's brush opens a gift on the sticker card.",
      ));
      expect(kMorningCopy, (
        title: 'Morning brush',
        body: '2 minutes before the day starts.',
      ));
      for (final copy in [
        kEveningCopyMonsters,
        kEveningCopyBattle,
        kEveningCopyGift,
        kMorningCopy,
      ]) {
        final words = '${copy.title} ${copy.body}'.toLowerCase();
        for (final never in [
          'streak',
          'ranger',
          'miss',
          'lose',
          'lost',
          "don't",
          'hero',
        ]) {
          expect(words, isNot(contains(never)), reason: never);
        }
      }
    });
  });

  group('gift nights (the sticker card, Part B)', () {
    test('no gift coming: never the gift line', () {
      final plan = planReminders(now: thursday, settings: evenings);
      expect(plan.map((r) => r.body), isNot(contains(kEveningCopyGift.body)));
    });

    test('a gift next and nothing brushed today: tonight and every later '
        'night', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        nextStickerOpensGift: true,
      );
      expect({for (final r in plan) r.body}, {kEveningCopyGift.body});
    });

    test("brushed this morning: today's sticker is placed, so the gift is "
        'tomorrow night', () {
      final plan = planReminders(
        now: thursday,
        settings: evenings,
        morningDoneToday: true,
        nextStickerOpensGift: true,
      );
      expect(plan.first.at, DateTime(2026, 10, 15, 19, 30));
      expect(plan.first.body, isNot(kEveningCopyGift.body));
      expect({for (final r in plan.skip(1)) r.body}, {kEveningCopyGift.body});
    });

    test('mornings never carry it', () {
      final plan = planReminders(
        now: DateTime(2026, 10, 15, 6),
        settings: both,
        nextStickerOpensGift: true,
      );
      expect(
        {for (final r in only(plan, ReminderSlot.morning)) r.body},
        {kMorningCopy.body},
      );
    });
  });

  group('defaultEveningTime (the personalised default)', () {
    test('7:30 pm with no first brush, or an unreadable one', () {
      expect(defaultEveningTime(null), kDefaultEveningTime);
      expect(defaultEveningTime('oops'), kDefaultEveningTime);
      expect(defaultEveningTime('25:00'), kDefaultEveningTime);
      expect(defaultEveningTime('19:75'), kDefaultEveningTime);
    });

    test('a first brush outside 5:30 to 9:30 pm keeps 7:30 pm', () {
      expect(defaultEveningTime('07:10'), kDefaultEveningTime);
      expect(defaultEveningTime('17:29'), kDefaultEveningTime);
      expect(defaultEveningTime('21:31'), kDefaultEveningTime);
    });

    test('30 minutes before, on the nearest quarter hour', () {
      expect(defaultEveningTime('20:15'), (hour: 19, minute: 45)); // spec
      expect(defaultEveningTime('20:07'), (hour: 19, minute: 30));
      expect(defaultEveningTime('20:08'), (hour: 19, minute: 45));
      expect(defaultEveningTime('19:52'), (hour: 19, minute: 15));
    });

    test('kept between 6:30 and 9:00 pm', () {
      expect(defaultEveningTime('17:30'), (hour: 18, minute: 30));
      expect(defaultEveningTime('18:40'), (hour: 18, minute: 30));
      expect(defaultEveningTime('21:30'), (hour: 21, minute: 0));
    });
  });

  group('reminderOfferDue (spec §2)', () {
    ReminderOffer? due({
      int shown = 0,
      String? last,
      bool decided = false,
      bool on = false,
      int brushes = 1,
    }) => reminderOfferDue(
      offersShown: shown,
      lastOfferDate: last,
      decided: decided,
      remindersOn: on,
      totalBrushes: brushes,
      today: '2026-10-15',
    );

    test('offer 1 after the first finished brush', () {
      expect(due(), ReminderOffer.first);
    });

    test('offer 1 for a player from before this version (R-1)', () {
      expect(due(brushes: 40), ReminderOffer.first);
    });

    test('not before any brush', () {
      expect(due(brushes: 0), isNull);
    });

    test('offer 2: from the 3rd brush, on a later day', () {
      expect(
        due(shown: 1, last: '2026-10-14', brushes: 3),
        ReminderOffer.second,
      );
      expect(due(shown: 1, last: '2026-10-14', brushes: 2), isNull);
      expect(due(shown: 1, last: '2026-10-15', brushes: 9), isNull);
    });

    test(
      'never after a decision, while a reminder is on, or after offer 2',
      () {
        expect(due(decided: true), isNull);
        expect(
          due(shown: 1, last: '2026-10-01', brushes: 9, decided: true),
          isNull,
        );
        expect(due(on: true), isNull);
        expect(due(shown: 2, last: '2026-10-01', brushes: 9), isNull);
      },
    );

    test('the numbers and the analytics names', () {
      expect(ReminderOffer.first.number, 1);
      expect(ReminderOffer.second.number, 2);
      expect(
        [for (final r in ReminderOfferResult.values) r.analyticsName],
        [
          'gate_opened',
          'skipped',
          'timeout',
          'not_now',
          'os_denied',
          'enabled',
        ],
      );
    });
  });

  group('times and settings', () {
    test('formatReminderTime', () {
      expect(formatReminderTime((hour: 19, minute: 45)), '7:45 PM');
      expect(formatReminderTime((hour: 7, minute: 0)), '7:00 AM');
      expect(formatReminderTime((hour: 12, minute: 5)), '12:05 PM');
      expect(formatReminderTime((hour: 0, minute: 30)), '12:30 AM');
    });

    test('saved as minutes after midnight, kept inside the day', () {
      expect(reminderMinutes((hour: 19, minute: 30)), 1170);
      expect(reminderTimeFromMinutes(1170), (hour: 19, minute: 30));
      expect(reminderTimeFromMinutes(-5), (hour: 0, minute: 0));
      expect(reminderTimeFromMinutes(99999), (hour: 23, minute: 59));
    });

    test('the choices: quarter hours, 5 to 10 pm and 5:30 to 10 am', () {
      expect(eveningReminderChoices.first, (hour: 17, minute: 0));
      expect(eveningReminderChoices.last, (hour: 22, minute: 0));
      expect(eveningReminderChoices, hasLength(21));
      expect(morningReminderChoices.first, (hour: 5, minute: 30));
      expect(morningReminderChoices.last, (hour: 10, minute: 0));
      expect(morningReminderChoices, hasLength(19));
      expect(eveningReminderChoices, contains(kDefaultEveningTime));
      expect(morningReminderChoices, contains(kDefaultMorningTime));
      for (final firstBrush in ['17:30', '18:00', '19:00', '20:15', '21:30']) {
        expect(
          eveningReminderChoices,
          contains(defaultEveningTime(firstBrush)),
        );
      }
    });

    test('reminderConfirmation (spec §3.2)', () {
      const evening = (hour: 19, minute: 45);
      expect(
        reminderConfirmation(
          const ReminderSettings(eveningOn: true, evening: evening),
        ),
        'Reminder set for 7:45 PM',
      );
      expect(
        reminderConfirmation(
          const ReminderSettings(
            eveningOn: true,
            evening: evening,
            morningOn: true,
          ),
        ),
        'Reminders set for 7:45 PM and 7:00 AM',
      );
    });

    test('ReminderSettings: defaults, anyOn, copyWith, equality', () {
      const off = ReminderSettings();
      expect(off.anyOn, isFalse);
      expect(off.evening, kDefaultEveningTime);
      expect(off.morning, kDefaultMorningTime);
      expect(off.copyWith(morningOn: true).anyOn, isTrue);
      expect(
        off.copyWith(evening: (hour: 20, minute: 0)),
        const ReminderSettings(evening: (hour: 20, minute: 0)),
      );
      expect(off, isNot(off.copyWith(eveningOn: true)));
    });
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/services/reminder_plan_test.dart`
Expected: FAIL to compile, because `reminder_plan.dart` doesn't exist.

- [ ] **Step 3: Create `lib/services/reminder_plan.dart`**

```dart
// lib/services/reminder_plan.dart
//
// The parent bedtime reminder's rules (spec
// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§5), as
// plain functions and values: no plugin, no storage, no clock of their own.
// ReminderService feeds them; reminder_plan_test.dart pins them.
import 'package:flutter/foundation.dart';

/// A time of day, in the phone's local time.
typedef ReminderTime = ({int hour, int minute});

/// The evening reminder's time before the parent picks one (spec §3.2).
const ReminderTime kDefaultEveningTime = (hour: 19, minute: 30);

/// The morning reminder's time before the parent picks one (spec §3.2).
const ReminderTime kDefaultMorningTime = (hour: 7, minute: 0);

/// Days planned at a time, today included: a week without opening the app
/// means at most a week of reminders, then silence (spec §4).
const kReminderHorizonDays = 7;

/// Minutes after midnight: how a time is saved.
int reminderMinutes(ReminderTime time) => time.hour * 60 + time.minute;

/// The time [minutes] after midnight, kept inside the day.
ReminderTime reminderTimeFromMinutes(int minutes) {
  final m = minutes.clamp(0, 24 * 60 - 1);
  return (hour: m ~/ 60, minute: m % 60);
}

/// "7:45 PM": how the parent screens write a time.
String formatReminderTime(ReminderTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// Every quarter hour from [first] to [last], both included.
List<ReminderTime> _quarterHours(ReminderTime first, ReminderTime last) => [
  for (var m = reminderMinutes(first); m <= reminderMinutes(last); m += 15)
    reminderTimeFromMinutes(m),
];

/// The evening times a parent can pick: 5:00 PM to 10:00 PM.
final List<ReminderTime> eveningReminderChoices = _quarterHours(
  (hour: 17, minute: 0),
  (hour: 22, minute: 0),
);

/// The morning times a parent can pick: 5:30 AM to 10:00 AM. Both lists keep
/// a reminder on its own side of noon, where the brushing slots split.
final List<ReminderTime> morningReminderChoices = _quarterHours(
  (hour: 5, minute: 30),
  (hour: 10, minute: 0),
);

/// The two reminders, and the first of each one's notification ids.
enum ReminderSlot {
  evening(100),
  morning(200);

  const ReminderSlot(this.idBase);

  final int idBase;
}

/// Days since 1 Jan 1970 for [day]'s date. UTC arithmetic, so a
/// daylight-saving change can't move it.
int _dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The notification id of [slot]'s reminder on [day]'s date: evening 100–106,
/// morning 200–206 (spec §5), taken in turn by the days of a week. A date
/// keeps its id however often the week is planned, so planning again
/// replaces that night's reminder, and cancelling it also clears it if it is
/// still showing.
int reminderIdFor(ReminderSlot slot, DateTime day) =>
    slot.idBase + _dayNumber(day) % kReminderHorizonDays;

/// Every id the reminders use.
List<int> allReminderIds() => [
  for (final slot in ReminderSlot.values)
    for (var i = 0; i < kReminderHorizonDays; i++) slot.idBase + i,
];

/// Whether [id] is one of the reminders' ids.
bool isReminderId(int id) => ReminderSlot.values.any(
  (slot) => id >= slot.idBase && id < slot.idBase + kReminderHorizonDays,
);

/// What the parent chose: each reminder on or off, and its time.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.eveningOn = false,
    this.evening = kDefaultEveningTime,
    this.morningOn = false,
    this.morning = kDefaultMorningTime,
  });

  final bool eveningOn;
  final ReminderTime evening;
  final bool morningOn;
  final ReminderTime morning;

  bool get anyOn => eveningOn || morningOn;

  ReminderSettings copyWith({
    bool? eveningOn,
    ReminderTime? evening,
    bool? morningOn,
    ReminderTime? morning,
  }) => ReminderSettings(
    eveningOn: eveningOn ?? this.eveningOn,
    evening: evening ?? this.evening,
    morningOn: morningOn ?? this.morningOn,
    morning: morning ?? this.morning,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.eveningOn == eveningOn &&
      other.evening == evening &&
      other.morningOn == morningOn &&
      other.morning == morning;

  @override
  int get hashCode => Object.hash(eveningOn, evening, morningOn, morning);

  @override
  String toString() =>
      'ReminderSettings(evening: $eveningOn ${formatReminderTime(evening)}, '
      'morning: $morningOn ${formatReminderTime(morning)})';
}

/// One notification's words.
typedef ReminderCopy = ({String title, String body});

// The approved copy (spec §4; sticker-card spec §4.7), each line split at its
// natural break into the notification's title and text. Written to the
// parent: no streaks, no "we miss you", nothing addressed to the child.
const ReminderCopy kEveningCopyMonsters = (
  title: 'Brushing time!',
  body: "Tonight's cavity monsters are waiting.",
);
const ReminderCopy kEveningCopyBattle = (
  title: 'Bedtime brush',
  body: '2 minutes, one monster battle.',
);
const ReminderCopy kEveningCopyGift = (
  title: 'Brushing time!',
  body: "Tonight's brush opens a gift on the sticker card.",
);
const ReminderCopy kMorningCopy = (
  title: 'Morning brush',
  body: '2 minutes before the day starts.',
);

/// One reminder to schedule.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.slot,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final ReminderSlot slot;

  /// When it should show, in local time.
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.slot == slot &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, slot, at, title, body);

  @override
  String toString() => 'PlannedReminder($id ${slot.name} $at "$title")';
}

/// The reminders for the next [kReminderHorizonDays] days, soonest first
/// (spec §4–§5). Rolling one-shots, so a brushed day can be skipped:
///
/// * each instant is built in local time for its own date, so a
///   daylight-saving change needs nothing special;
/// * nothing for a time that has passed, nor for a slot already brushed
///   today ([morningDoneToday], [eveningDoneToday]; morning is before noon,
///   as in the streak service);
/// * nothing today while [appInForeground]: a reminder never shows while the
///   app is open, and leaving the app plans the week again;
/// * nothing before [pauseUntil] (the parent Pause);
/// * the evening line alternates by date; on a gift night it is the gift
///   line. [nextStickerOpensGift] says the next sticker the card places is
///   the 3rd or the 7th. The first finished brush of a day places that day's
///   sticker, so tonight is a gift night only if nothing was brushed yet
///   today, and every later night is one (a brush first plans it all again).
List<PlannedReminder> planReminders({
  required DateTime now,
  required ReminderSettings settings,
  bool morningDoneToday = false,
  bool eveningDoneToday = false,
  DateTime? pauseUntil,
  bool nextStickerOpensGift = false,
  bool appInForeground = false,
}) {
  final brushedToday = morningDoneToday || eveningDoneToday;
  final plan = <PlannedReminder>[];
  for (var dayIndex = 0; dayIndex < kReminderHorizonDays; dayIndex++) {
    // DateTime turns Oct 32 into Nov 1.
    final day = DateTime(now.year, now.month, now.day + dayIndex);
    for (final slot in ReminderSlot.values) {
      final evening = slot == ReminderSlot.evening;
      if (!(evening ? settings.eveningOn : settings.morningOn)) continue;
      final time = evening ? settings.evening : settings.morning;
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (!at.isAfter(now)) continue;
      final brushedThisSlot = evening ? eveningDoneToday : morningDoneToday;
      if (dayIndex == 0 && (appInForeground || brushedThisSlot)) continue;
      if (pauseUntil != null && at.isBefore(pauseUntil)) continue;
      final copy = _copyFor(
        slot,
        day,
        giftNight: nextStickerOpensGift && (dayIndex > 0 || !brushedToday),
      );
      plan.add(
        PlannedReminder(
          id: reminderIdFor(slot, day),
          slot: slot,
          at: at,
          title: copy.title,
          body: copy.body,
        ),
      );
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan;
}

ReminderCopy _copyFor(
  ReminderSlot slot,
  DateTime day, {
  required bool giftNight,
}) {
  if (slot == ReminderSlot.morning) return kMorningCopy;
  if (giftNight) return kEveningCopyGift;
  // By date, so a night keeps its line whenever the week is planned.
  return _dayNumber(day).isEven ? kEveningCopyMonsters : kEveningCopyBattle;
}

/// The hand-off's two chances (spec §2).
enum ReminderOffer {
  first,
  second;

  /// 1 or 2: the saved offer count, and the analytics `offer`.
  int get number => index + 1;
}

/// The hand-off to show after a finished brush, or null (spec §2):
///
/// * offer 1: the first finished brush with no offer made yet. That is a new
///   player's first brush, and a player's next brush after updating from a
///   version without reminders (ruling R-1);
/// * offer 2: after offer 1 ended without a decision (a skip, a timeout, a
///   cancelled gate), from the 3rd finished brush, on a later date;
/// * never once the parent decided ([decided]: TURN ON allowed or refused,
///   or "Not now"), while a reminder is on, or after offer 2.
///
/// [today] and [lastOfferDate] are 'yyyy-mm-dd'.
ReminderOffer? reminderOfferDue({
  required int offersShown,
  required String? lastOfferDate,
  required bool decided,
  required bool remindersOn,
  required int totalBrushes,
  required String today,
}) {
  if (decided || remindersOn || totalBrushes < 1) return null;
  if (offersShown <= 0) return ReminderOffer.first;
  final laterDay = lastOfferDate == null || today.compareTo(lastOfferDate) > 0;
  if (offersShown == 1 && totalBrushes >= 3 && laterDay) {
    return ReminderOffer.second;
  }
  return null;
}

/// How an offer ended, for `reminder_offer_result` (spec §6).
enum ReminderOfferResult {
  gateOpened('gate_opened'),
  skipped('skipped'),
  timeout('timeout'),
  notNow('not_now'),
  osDenied('os_denied'),
  enabled('enabled');

  const ReminderOfferResult(this.analyticsName);

  final String analyticsName;
}

/// Screen B's evening time before the parent picks one (spec §3.2): 30
/// minutes before the first brush if that was between 5:30 and 9:30 pm, on
/// the nearest quarter hour, kept between 6:30 and 9:00 pm; otherwise
/// 7:30 pm. [firstBrushTime] is the brush history's 'HH:mm', or null.
ReminderTime defaultEveningTime(String? firstBrushTime) {
  final parts = firstBrushTime?.split(':');
  if (parts == null || parts.length != 2) return kDefaultEveningTime;
  final hour = int.tryParse(parts.first);
  final minute = int.tryParse(parts.last);
  if (hour == null || minute == null) return kDefaultEveningTime;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return kDefaultEveningTime;
  }
  final brushed = hour * 60 + minute;
  if (brushed < 17 * 60 + 30 || brushed > 21 * 60 + 30) {
    return kDefaultEveningTime;
  }
  final quarter = ((brushed - 30 + 7) ~/ 15) * 15;
  return reminderTimeFromMinutes(quarter.clamp(18 * 60 + 30, 21 * 60));
}

/// Screen B's line once the reminder is on (spec §3.2).
String reminderConfirmation(ReminderSettings settings) => settings.morningOn
    ? 'Reminders set for ${formatReminderTime(settings.evening)} and '
          '${formatReminderTime(settings.morning)}'
    : 'Reminder set for ${formatReminderTime(settings.evening)}';
```

- [ ] **Step 4: Run the tests, in three time zones**

Run:
```bash
flutter test test/services/reminder_plan_test.dart
TZ=America/Los_Angeles flutter test test/services/reminder_plan_test.dart
TZ=Europe/Paris flutter test test/services/reminder_plan_test.dart
TZ=UTC flutter test test/services/reminder_plan_test.dart
```
Expected:
- All pass in each zone.
- Under `TZ=UTC`, "the night the clocks go back comes 25 hours after the one before" is reported as skipped. In the other two it runs.
- `flutter test` honours `TZ` (checked while planning: a 7:30 pm instant 24 h later has a 25 h gap over the change).

- [ ] **Step 5: Format, analyze**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib`
Expected: "No issues found!" and "no issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/services/reminder_plan.dart test/services/reminder_plan_test.dart
git commit -m "feat(reminder): the bedtime reminder's rules as pure functions

A rolling week of one-shot reminders built in local time for each date,
skipped when the slot is brushed, during the parent Pause and (today)
while the app is open; the approved copy; the two hand-off offers; the
personalised default time.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 2: The plugin on Android and iOS, behind `ReminderPlatform`

**Files:**
- Modify: `pubspec.yaml` (after `crypto: ^3.0.6`, line 34), `pubspec.lock` (written by `flutter pub get`)
- Create: `lib/services/reminder_platform.dart`
- Create: `test/services/reminder_fakes.dart` (`FakeReminderPlatform`; Task 3 adds more to it)
- Create: `test/flows/reminder_platform_setup_test.dart`
- Modify: `android/app/build.gradle.kts` (`compileOptions`, lines 26-29; a `dependencies` block after `flutter { }`, line 74-76)
- Modify: `android/app/src/main/AndroidManifest.xml` (a permission after line 3; two receivers before `</application>`, line 65)
- Create: `android/app/src/main/res/drawable/ic_stat_brush_reminder.xml`
- Add: `android/app/src/main/res/drawable-nodpi/ic_reminder_large.png` (a copy of `mipmap-xxxhdpi/ic_launcher.png`, 192 × 192)
- Create: `android/app/src/main/res/raw/keep.xml`
- Modify: `ios/Runner/AppDelegate.swift` (imports, lines 1-3; `didFinishLaunchingWithOptions`, lines 14-20)
- Modify: `ios/Podfile.lock` (written by `pod install`, through `flutter build ios`)
- Modify: `docs/ios-port/privacy-manifest-audit.md` (Summary list; a table row after the `lottie` row, line 33)

**Interfaces:**
- Consumes (Task 1): `PlannedReminder`, `ReminderSlot`.
- Produces:
  - `abstract interface class ReminderPlatform` with these members:
    - `Future<void> init({required void Function(String? slot) onTap})`
    - `Future<String?> launchSlot()`
    - `Future<bool> requestPermission()`
    - `Future<bool> notificationsAllowed()`
    - `Future<List<int>> pendingIds()`
    - `Future<void> schedule(PlannedReminder reminder)`
    - `Future<void> cancel(int id)`
    - `Future<void> cancelAll()`
    - `Future<void> openSettings()`
  - `class PluginReminderPlatform implements ReminderPlatform` (`PluginReminderPlatform([FlutterLocalNotificationsPlugin? plugin])`), with `static const channelId = 'brush_reminders'`, `channelName = 'Brushing reminders'`, `smallIcon = 'ic_stat_brush_reminder'`, `largeIcon = 'ic_reminder_large'`.
  - Test helper `FakeReminderPlatform implements ReminderPlatform`:
    - Settable: `bool grant`, `bool allowed`, `String? launchSlotValue`, `Set<int> failScheduleFor`, `Completer<void>? holdSchedule`, `Object? failure`.
    - Recorded: `Map<int, PlannedReminder> pending`, `List<String> calls`, `List<int> cancelled`, `int permissionRequests`, `int cancelAllCalls`, `int openSettingsCalls`, `void Function(String? slot)? onTap`.
    - `List<DateTime> get pendingTimes` (sorted).

- [ ] **Step 1: Add the two packages**

In `pubspec.yaml`, after the line `  crypto: ^3.0.6`, add:

```yaml
  # The parent bedtime reminder (docs/superpowers/specs/2026-10-15-bedtime-
  # reminder-design.md): local notifications only, no FCM, no server.
  # Pinned exactly: 22.3.2 needs Flutter >= 3.38.1 (we are on 3.41.4); 23.x
  # needs Dart 3.12. timezone is imported directly (TZDateTime), so it is a
  # direct dependency too.
  flutter_local_notifications: 22.3.2
  timezone: 0.11.2
```

Run:
```bash
flutter pub get
git diff --stat pubspec.lock
grep -A3 -E "^  (flutter_local_notifications[a-z_]*|timezone):$" pubspec.lock | grep -E "^  [a-z]|version"
flutter test test/audio/audioplayers_pin_test.dart
```
Expected:
- Six new lock entries and no other change: `flutter_local_notifications` 22.3.2, `flutter_local_notifications_linux` 8.0.2, `flutter_local_notifications_platform_interface` 12.2.0, `flutter_local_notifications_web` 1.0.0, `flutter_local_notifications_windows` 3.1.1, `timezone` 0.11.2. (Checked with `flutter pub add flutter_local_notifications --dry-run` while planning.)
- The pin test passes: no Android audio dependency moved.

- [ ] **Step 2: Write the failing structural test**

Create `test/flows/reminder_platform_setup_test.dart`:

```dart
// test/flows/reminder_platform_setup_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's platform setup (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §5). None of
/// it runs in a widget test, so the files themselves are pinned.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the plugin, pinned; no push messaging', () {
    final pubspec = read('pubspec.yaml');
    expect(pubspec, contains('flutter_local_notifications: 22.3.2'));
    expect(pubspec, contains('timezone: 0.11.2'));
    expect(pubspec, isNot(contains('firebase_messaging')));
    expect(pubspec, isNot(contains('flutter_timezone')));
  });

  test('Android: re-armed after a reboot, receivers not exported, no exact '
      'alarms', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    for (final receiver in [
      'ScheduledNotificationReceiver',
      'ScheduledNotificationBootReceiver',
    ]) {
      expect(
        RegExp(
          r'android:exported="false"\s+android:name="com\.dexterous\.'
          r'flutterlocalnotifications\.'
          '$receiver"',
        ).hasMatch(manifest),
        isTrue,
        reason: receiver,
      );
    }
    // Play allows exact alarms only for alarm and calendar apps.
    for (final banned in [
      'SCHEDULE_EXACT_ALARM',
      'USE_EXACT_ALARM',
      'USE_FULL_SCREEN_INTENT',
    ]) {
      expect(manifest, isNot(contains(banned)), reason: banned);
    }
  });

  test('Android: desugaring, the two icons and their keep rule', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(
      gradle,
      contains(
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
      ),
    );
    const res = 'android/app/src/main/res';
    final small = read('$res/drawable/ic_stat_brush_reminder.xml');
    expect(small, contains('android:fillType="evenOdd"'));
    expect(small, contains('android:fillColor="#FFFFFFFF"'));
    expect(
      File('$res/drawable-nodpi/ic_reminder_large.png').existsSync(),
      isTrue,
    );
    final keep = read('$res/raw/keep.xml');
    expect(keep, contains('@drawable/ic_stat_brush_reminder'));
    expect(keep, contains('@drawable/ic_reminder_large'));
  });

  test('the plugin asks nothing at start-up, schedules inexact one-shots, '
      'never badges', () {
    final platform = read('lib/services/reminder_platform.dart');
    for (final flag in [
      'requestAlertPermission: false',
      'requestBadgePermission: false',
      'requestSoundPermission: false',
      'badge: false',
      'provisional: false',
      'presentBadge: false',
      'presentBanner: false',
      'presentList: false',
      'presentAlert: false',
      'presentSound: true',
    ]) {
      expect(platform, contains(flag), reason: flag);
    }
    expect(platform, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(platform, isNot(contains('AndroidScheduleMode.exact')));
    expect(platform, isNot(contains('alarmClock')));
    expect(platform, isNot(contains('matchDateTimeComponents')));
    expect(platform, contains("channelId = 'brush_reminders'"));
    expect(platform, contains("channelName = 'Brushing reminders'"));
  });

  test('only the platform file talks to the plugin', () {
    final users = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains(
              'package:flutter_local_notifications/',
            ))
          f.path,
    ];
    expect(users, ['lib/services/reminder_platform.dart']);
  });

  test('iOS: the notification-centre delegate, apart from the audio '
      'observers, and no permission asked there', () {
    final delegate = read('ios/Runner/AppDelegate.swift');
    expect(
      delegate,
      contains(
        'UNUserNotificationCenter.current().delegate = '
        'self as UNUserNotificationCenterDelegate',
      ),
    );
    expect(delegate, contains('setupAudioSessionObservers()'));
    expect(delegate, isNot(contains('requestAuthorization')));
  });
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `flutter test test/flows/reminder_platform_setup_test.dart`
Expected: FAIL. The first test passes after Step 1; the others fail on the missing files and lines.

- [ ] **Step 4: Create `lib/services/reminder_platform.dart`**

```dart
// lib/services/reminder_platform.dart
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The phone's notification system, as the bedtime reminder uses it (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §5). The
/// real one is [PluginReminderPlatform]; tests use a fake. ReminderService
/// guards every call: none of them may break the app.
abstract interface class ReminderPlatform {
  /// Sets the plugin up, asking for no permission. [onTap] gets the slot name
  /// of a reminder tapped while the app runs.
  Future<void> init({required void Function(String? slot) onTap});

  /// The slot name of the reminder that started the app, or null.
  Future<String?> launchSlot();

  /// The OS prompt (Android 13+ POST_NOTIFICATIONS; iOS alert and sound, no
  /// badge, never provisional). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Whether the OS lets Brush Quest show notifications now.
  Future<bool> notificationsAllowed();

  /// The ids of the notifications waiting to show.
  Future<List<int>> pendingIds();

  Future<void> schedule(PlannedReminder reminder);

  /// Cancels [id], whether it waits or shows.
  Future<void> cancel(int id);

  /// Cancels every notification, waiting or shown.
  Future<void> cancelAll();

  /// The phone's notification settings for Brush Quest.
  Future<void> openSettings();
}

/// [ReminderPlatform] on flutter_local_notifications.
class PluginReminderPlatform implements ReminderPlatform {
  PluginReminderPlatform([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The Android channel a parent can switch off in the phone's settings.
  static const channelId = 'brush_reminders';
  static const channelName = 'Brushing reminders';
  static const channelDescription =
      'The brushing reminder you set in Brush Quest.';

  /// res/drawable/ic_stat_brush_reminder.xml (a monochrome tooth with a moon)
  /// and res/drawable-nodpi/ic_reminder_large.png (the app icon), kept from
  /// the resource shrinker by res/raw/keep.xml.
  static const smallIcon = 'ic_stat_brush_reminder';
  static const largeIcon = 'ic_reminder_large';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: smallIcon,
      largeIcon: DrawableResourceAndroidBitmap(largeIcon),
      color: Color(0xFF7C4DFF),
      category: AndroidNotificationCategory.reminder,
    ),
    // Nothing on screen while the app is open (spec §4), and no badge ever.
    // presentSound must stay true: the plugin gives the notification its
    // sound only then, and a silent bedtime reminder would be missed.
    iOS: DarwinNotificationDetails(
      presentAlert: false,
      presentBanner: false,
      presentList: false,
      presentBadge: false,
      presentSound: true,
    ),
  );

  @override
  Future<void> init({required void Function(String? slot) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
        // The plugin's defaults would prompt here, unguarded, at the first
        // launch. The prompt belongs behind the parent gate.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: false,
          defaultPresentBanner: false,
          defaultPresentList: false,
          defaultPresentBadge: false,
          defaultPresentSound: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchSlot() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      await _android?.requestNotificationsPermission() ?? false,
    TargetPlatform.iOS =>
      await _ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: false,
            provisional: false,
          ) ??
          false,
    _ => false,
  };

  @override
  Future<bool> notificationsAllowed() async => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      await _android?.areNotificationsEnabled() ?? false,
    TargetPlatform.iOS => (await _ios?.checkPermissions())?.isEnabled ?? false,
    _ => false,
  };

  @override
  Future<List<int>> pendingIds() async => [
    for (final request in await _plugin.pendingNotificationRequests())
      request.id,
  ];

  @override
  Future<void> schedule(PlannedReminder reminder) => _plugin.zonedSchedule(
    id: reminder.id,
    title: reminder.title,
    body: reminder.body,
    // An absolute instant: the plan built it in local time for its own date,
    // so no time-zone database is needed, and a trip abroad is put right the
    // next time the app opens.
    scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
    notificationDetails: _details,
    // Inexact: Play allows exact alarms only for alarm and calendar apps.
    // Android may deliver up to about an hour late (spec §5).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: reminder.slot.name,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}
```

- [ ] **Step 5: Create the test fake**

Create `test/services/reminder_fakes.dart`:

```dart
// test/services/reminder_fakes.dart
import 'dart:async';

import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_platform.dart';

/// The phone's notification system, in memory. [pending] is what waits to
/// show; [calls] lists every call by name.
class FakeReminderPlatform implements ReminderPlatform {
  /// What the OS answers when asked.
  bool grant = true;

  /// Whether notifications are allowed now (an answered request sets it).
  bool allowed = false;

  /// The slot of the reminder that "started the app".
  String? launchSlotValue;

  /// Ids whose scheduling throws, as the plugin does for a past date.
  Set<int> failScheduleFor = {};

  /// When set, the next [schedule] call waits for it (overlap tests).
  Completer<void>? holdSchedule;

  final Map<int, PlannedReminder> pending = {};
  final List<String> calls = [];
  final List<int> cancelled = [];
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  int openSettingsCalls = 0;
  void Function(String? slot)? onTap;

  Exception? _exception;
  Error? _error;

  /// From now on every call throws this (null: no more).
  Object? get failure => _exception ?? _error;
  set failure(Object? value) {
    _exception = value is Exception ? value : null;
    _error = value is Error ? value : null;
  }

  /// When the waiting reminders show, soonest first.
  List<DateTime> get pendingTimes =>
      [for (final r in pending.values) r.at]..sort();

  void _enter(String name) {
    calls.add(name);
    final exception = _exception;
    if (exception != null) throw exception;
    final error = _error;
    if (error != null) throw error;
  }

  @override
  Future<void> init({required void Function(String? slot) onTap}) async {
    _enter('init');
    this.onTap = onTap;
  }

  @override
  Future<String?> launchSlot() async {
    _enter('launchSlot');
    return launchSlotValue;
  }

  @override
  Future<bool> requestPermission() async {
    _enter('requestPermission');
    permissionRequests++;
    allowed = grant;
    return grant;
  }

  @override
  Future<bool> notificationsAllowed() async {
    _enter('notificationsAllowed');
    return allowed;
  }

  @override
  Future<List<int>> pendingIds() async {
    _enter('pendingIds');
    return pending.keys.toList();
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    _enter('schedule');
    final hold = holdSchedule;
    if (hold != null) {
      holdSchedule = null;
      await hold.future;
    }
    if (failScheduleFor.contains(reminder.id)) {
      throw ArgumentError.value(
        reminder.at,
        'scheduledDate',
        'Must be a date in the future',
      );
    }
    pending[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    _enter('cancel');
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _enter('cancelAll');
    cancelAllCalls++;
    pending.clear();
  }

  @override
  Future<void> openSettings() async {
    _enter('openSettings');
    openSettingsCalls++;
  }
}
```

- [ ] **Step 6: Android: desugaring, the manifest, the icons**

In `android/app/build.gradle.kts`, replace the `compileOptions` block (lines 26-29) with:

```kotlin
    compileOptions {
        // flutter_local_notifications (the bedtime reminder) needs core library
        // desugaring: its scheduling uses java.time below Android 8.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
```

and at the end of the file, after the `flutter { source = "../.." }` block, add:

```kotlin

dependencies {
    // The desugaring library flutter_local_notifications asks for.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

In `android/app/src/main/AndroidManifest.xml`, after line 3 (`<uses-permission android:name="android.permission.CAMERA" />`), add:

```xml
    <!-- Bedtime reminder: re-arms the scheduled reminders after a reboot. No exact-alarm
         permission on purpose: Play allows it only for alarm and calendar apps.
         POST_NOTIFICATIONS and VIBRATE merge in from flutter_local_notifications. -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

and just before `    </application>` (line 65), after the `EnableImpeller` meta-data, add:

```xml
        <!-- flutter_local_notifications: shows the scheduled bedtime reminders and re-arms
             them after a reboot or an app update. Not exported. -->
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
```

Create `android/app/src/main/res/drawable/ic_stat_brush_reminder.xml`. The path is a tooth with a crescent moon cut out; while planning it was rendered as an SVG and reads clearly at 240 px.

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- The bedtime reminder's status-bar icon: a tooth with a crescent moon cut out.
     Monochrome white on transparent (Android tints it). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="M7.2,2.5C4.9,2.5 3.2,4.3 3.2,6.9C3.2,8.9 4,10.5 4.7,12.4C5.4,14.3 5.6,17.1 6.2,19.7C6.6,21.4 8.7,21.4 9.1,19.7L10,15.8C10.2,14.9 11,14.3 12,14.3C13,14.3 13.8,14.9 14,15.8L14.9,19.7C15.3,21.4 17.4,21.4 17.8,19.7C18.4,17.1 18.6,14.3 19.3,12.4C20,10.5 20.8,8.9 20.8,6.9C20.8,4.3 19.1,2.5 16.8,2.5C15,2.5 14,3.6 12,3.6C10,3.6 9,2.5 7.2,2.5Z M10.95,5.13A3.6,3.6 0 1,0 14.68,10.19A3.2,3.2 0 0,1 10.95,5.13Z" />
</vector>
```

Copy the app icon as the large icon. `@mipmap/ic_launcher` is an adaptive icon on Android 8+, which the plugin can't decode, so a plain PNG is needed:

```bash
mkdir -p android/app/src/main/res/drawable-nodpi
cp android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png android/app/src/main/res/drawable-nodpi/ic_reminder_large.png
```

Create `android/app/src/main/res/raw/keep.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- flutter_local_notifications looks the reminder's icons up by name at run time, so the
     resource shrinker can't see that they are used. Without this, a release build strips
     them and reminders silently fail (the plugin rejects a missing default icon). -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_brush_reminder,@drawable/ic_reminder_large" />
```

- [ ] **Step 7: iOS: the notification-centre delegate**

In `ios/Runner/AppDelegate.swift`, add `import UserNotifications` after `import UIKit` (line 3), and replace `application(_:didFinishLaunchingWithOptions:)` (lines 14-20) with:

```swift
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setupAudioSessionObservers()
    // Bedtime reminder (flutter_local_notifications): FlutterAppDelegate is
    // the notification-centre delegate and hands each notification to the
    // plugin, which keeps reminders off the screen while the app is open.
    // Separate from the audio-session observers above. No permission is asked
    // here: that happens behind the parent gate.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
```

The app uses the UIScene lifecycle (`FlutterImplicitEngineDelegate`). The README's `setPluginRegistrantCallback` is only for notification actions in a background isolate, which the reminder doesn't use, so `didInitializeImplicitFlutterEngine` stays as it is.

- [ ] **Step 8: Run the structural test**

Run: `flutter test test/flows/reminder_platform_setup_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 9: Android builds, with the right permissions**

Run:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --debug
~/Library/Android/sdk/build-tools/35.0.0/aapt2 dump permissions build/app/outputs/flutter-apk/app-debug.apk
```
Expected:
- The build succeeds. It did while planning, on a copy with these exact edits.
- The permissions include `android.permission.POST_NOTIFICATIONS`, `android.permission.RECEIVE_BOOT_COMPLETED` and `android.permission.VIBRATE`.
- They include neither `SCHEDULE_EXACT_ALARM` nor `USE_EXACT_ALARM`, and not `com.google.android.gms.permission.AD_ID`. The other permissions are the app's existing ones.
- If the build stops at an AAR metadata check asking for core library desugaring, Step 6's `compileOptions` edit is missing.
- `apkanalyzer` from cmdline-tools fails on this machine ("Cannot locate latest build tools"); use `aapt2` as above.

- [ ] **Step 10: iOS builds, and the Kids Category gate still passes**

Run:
```bash
flutter build ios --release --no-codesign
scripts/check_ios_kids_binary.sh build/ios/iphoneos/Runner.app
find build/ios/iphoneos/Runner.app -name PrivacyInfo.xcprivacy -path '*flutter_local_notifications*' -exec plutil -p {} \;
git status --short ios
```
Expected:
- The build succeeds; `pod install` runs inside it.
- The gate prints `PASS: no analytics, crash-reporting or advertising-identifier SDK code found.`
- The plugin's manifest shows `"NSPrivacyTracking" => false` and `"NSPrivacyCollectedDataTypes" => []`, plus the UserDefaults reason `CA92.1` only.
- `git status` shows `ios/Podfile.lock` modified, gaining `flutter_local_notifications (0.0.1)`. If anything else under `ios/` changed, read its diff before staging it.

If Xcode can't build here (no Xcode, or a toolchain error unrelated to this change), report BLOCKED with the error. Don't skip the gate.

- [ ] **Step 11: Note the plugin in the iOS privacy manifest audit**

In `docs/ios-port/privacy-manifest-audit.md`, add to the end of the `## Summary` list:

```markdown
- ✅ **flutter_local_notifications 22.3.2** (v1.1, the parent bedtime reminder): its own manifest, no tracking, no collected data, UserDefaults `CA92.1` only.
```

and after the `lottie` row of the audit table:

```markdown
| `flutter_local_notifications 22.3.2` | `flutter_local_notifications 22.3.2` (own iOS) | ✅ | `flutter_local_notifications_privacy.bundle/PrivacyInfo.xcprivacy`: NSPrivacyTracking false, no collected data types, UserDefaults `CA92.1` only. Local notifications; nothing leaves the device. |
```

- [ ] **Step 12: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 13: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/reminder_platform.dart test/services/reminder_fakes.dart test/flows/reminder_platform_setup_test.dart android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/src/main/res/drawable/ic_stat_brush_reminder.xml android/app/src/main/res/drawable-nodpi/ic_reminder_large.png android/app/src/main/res/raw/keep.xml ios/Runner/AppDelegate.swift ios/Podfile.lock docs/ios-port/privacy-manifest-audit.md
git commit -m "feat(reminder): flutter_local_notifications 22.3.2 behind ReminderPlatform

Inexact one-shot reminders (no exact-alarm permission), re-armed after a
reboot; a monochrome tooth-and-moon status icon; no permission asked at
start-up on iOS, no badge, nothing shown while the app is open. The iOS
Kids Category binary gate still passes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 3: `ReminderService`, its analytics, and the slots of a date

**Files:**
- Modify: `lib/services/streak_service.dart` (`getTodaySlots`, lines 321-327)
- Modify: `lib/services/analytics_service.dart` (new methods at the end of the class, before its closing `}` at line 217)
- Create: `lib/services/reminder_service.dart`
- Modify: `test/services/reminder_fakes.dart` (adds `RecordingAnalytics` and `installReminderService`)
- Create: `test/services/reminder_service_test.dart`
- Modify: `test/services/analytics_service_test.dart` (`_exerciseEveryEntryPoint`, and a test in the Android group)
- Modify: `test/services/streak_service_test.dart` (two tests at the end of its first group, `group('StreakService', ...)`, before line 516)

**Interfaces:**
- Consumes (Task 1): everything in `reminder_plan.dart`. (Task 2): `ReminderPlatform`, `PluginReminderPlatform`, `FakeReminderPlatform`.
- Produces:
  - `StreakService`: `static String dateKey(DateTime day)` ('yyyy-mm-dd') and `Future<TodaySlotsStatus> getSlotsOn(DateTime day)`. `getTodaySlots()` is unchanged for callers.
  - `AnalyticsService`: `logReminderOfferShown({required String offer})`, `logReminderOfferResult({required String result})`, `logReminderEnabled({required int eveningHour, required bool morning})`, `logAppOpenFromReminder({required String slot})`, `setReminderOn({required bool on})`. All return `Future<void>`.
  - `typedef GiftNightCheck = Future<bool> Function();` and `Future<bool> noStickerGifts()` (always false).
  - `ReminderService`, constructed through:
    - `factory ReminderService()`
    - `@visibleForTesting ReminderService.forTesting({required ReminderPlatform platform, AnalyticsService? analytics, DateTime Function()? now, GiftNightCheck nextStickerOpensGift = noStickerGifts})`
    - `@visibleForTesting static ReminderService? testInstance` (getter and setter)
  - Its keys: `keyEveningEnabled`, `keyEveningTime`, `keyMorningEnabled`, `keyMorningTime`, `keyOfferCount`, `keyOfferLastDate`, `keyDecided`, and `allKeys`.
  - Its methods:
    - `Future<void> init()`, `Future<void> onAppResumed()`, `Future<void> onAppPaused()`, `Future<void> reschedule()`
    - `Future<ReminderSettings> settings()`, `Future<ReminderTime> suggestedEveningTime()`
    - `Future<bool> turnOn(ReminderSettings wanted)`, `Future<void> saveSettings(ReminderSettings changed)`
    - `Future<ReminderOffer?> offerDue()`, `Future<void> noteOfferShown(ReminderOffer offer)`, `void noteParentZoneOffer()`, `Future<void> noteOfferResult(ReminderOfferResult result)`
    - `Future<bool> notificationsAllowed()`, `Future<void> openPhoneSettings()`, `Future<void> resetAll()`
  - Test helpers in `reminder_fakes.dart`: `class RecordingAnalytics` (`events`, `properties`, `named(String)`) and `Future<ReminderService> installReminderService({required FakeReminderPlatform platform, required RecordingAnalytics recorder, DateTime Function()? now, GiftNightCheck nextStickerOpensGift = noStickerGifts, bool initialise = true})`. The helper installs the service as `ReminderService.testInstance`.
  - Method order in `reminder_service.dart` matters: Task 7's structural test cuts `turnOn` at `Future<void> saveSettings(` and `saveSettings` at `Future<ReminderOffer?> offerDue(`.

- [ ] **Step 1: The slots of a date, in `StreakService`**

Add these tests at the end of the first group, `group('StreakService', ...)`, in `test/services/streak_service_test.dart`: after the test `'BrushRecord.fromJson uses defaults for missing heroId/worldId'` (line 509), before that group's closing `});` and `group('Wallet and Ranger Rank', ...)`. Not in the last group, "Streak bonuses", which Part B may delete with the bonuses.

```dart
    // ── Slots on a date (the bedtime reminder) ────────────────────

    test('getSlotsOn answers for the given date; getTodaySlots agrees', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'morning_done_date': StreakService.dateKey(now),
      });
      final service = StreakService();
      final today = await service.getSlotsOn(now);
      expect(today.morningDone, isTrue);
      expect(today.eveningDone, isFalse);
      expect((await service.getTodaySlots()).morningDone, isTrue);
      final tomorrow = await service.getSlotsOn(
        DateTime(now.year, now.month, now.day + 1),
      );
      expect(tomorrow.completedCount, 0);
    });

    test('dateKey is yyyy-mm-dd, padded', () {
      expect(StreakService.dateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(StreakService.dateKey(DateTime(2026, 12, 25)), '2026-12-25');
    });
```

Run: `flutter test test/services/streak_service_test.dart`
Expected: FAIL to compile, because `getSlotsOn` and `dateKey` don't exist.

In `lib/services/streak_service.dart`, replace `getTodaySlots` (lines 321-327) with:

```dart
  Future<TodaySlotsStatus> getTodaySlots() => getSlotsOn(DateTime.now());

  /// Which slots were brushed on [day]'s date. The done-date keys hold only
  /// the latest date, so this answers for today (and a later day: nothing).
  /// The bedtime reminder passes its own clock here.
  Future<TodaySlotsStatus> getSlotsOn(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final date = dateKey(day);
    return TodaySlotsStatus(
      morningDone: prefs.getString(_keyMorningDoneDate) == date,
      eveningDone: prefs.getString(_keyEveningDoneDate) == date,
    );
  }

  /// 'yyyy-mm-dd' for [day]: the form of every date this service saves.
  static String dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
```

Run: `flutter test test/services/streak_service_test.dart`
Expected: PASS.

- [ ] **Step 2: The reminder's analytics**

In `test/services/analytics_service_test.dart`, add at the end of `_exerciseEveryEntryPoint` (after `await service.logFlameTierReached(tier: 'small');`):

```dart
  await service.logReminderOfferShown(offer: '1');
  await service.logReminderOfferResult(result: 'skipped');
  await service.logReminderEnabled(eveningHour: 19, morning: false);
  await service.logAppOpenFromReminder(slot: 'evening');
  await service.setReminderOn(on: true);
```

and at the end of `group('AnalyticsService on Android (unchanged behaviour)', ...)`:

```dart
    test('the bedtime reminder: four events and the reminder_on property', () async {
      final fake = _RecordingAnalytics();
      final service = AnalyticsService.forTesting(
        isAndroid: true,
        analytics: fake,
      );
      await service.init();
      fake.calls.clear();
      await service.logReminderOfferShown(offer: 'parent_zone');
      await service.logReminderOfferResult(result: 'os_denied');
      await service.logReminderEnabled(eveningHour: 19, morning: true);
      await service.logAppOpenFromReminder(slot: 'morning');
      await service.setReminderOn(on: false);
      expect(fake.events, [
        {'name': 'reminder_offer_shown', 'offer': 'parent_zone'},
        {'name': 'reminder_offer_result', 'result': 'os_denied'},
        {'name': 'reminder_enabled', 'evening_hour': 19, 'morning': 1},
        {'name': 'app_open_from_reminder', 'slot': 'morning'},
      ]);
      expect(fake.calls.last, 'setUserProperty(reminder_on=false)');
    });
```

Run: `flutter test test/services/analytics_service_test.dart`
Expected: FAIL to compile, because the methods don't exist.

In `lib/services/analytics_service.dart`, add before the class's closing `}`:

```dart

  // ── Parent bedtime reminder (spec 2026-10-15-bedtime-reminder-design §6) ──

  /// [offer]: '1' or '2' (the hand-off after a brush) or 'parent_zone'.
  Future<void> logReminderOfferShown({required String offer}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'reminder_offer_shown',
      parameters: {'offer': offer},
    );
  }

  /// [result]: gate_opened, skipped, timeout, not_now, os_denied or enabled.
  Future<void> logReminderOfferResult({required String result}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'reminder_offer_result',
      parameters: {'result': result},
    );
  }

  Future<void> logReminderEnabled({
    required int eveningHour,
    required bool morning,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'reminder_enabled',
      parameters: {'evening_hour': eveningHour, 'morning': morning ? 1 : 0},
    );
  }

  /// [slot]: 'evening' or 'morning'.
  Future<void> logAppOpenFromReminder({required String slot}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'app_open_from_reminder',
      parameters: {'slot': slot},
    );
  }

  /// User property reminder_on: whether a reminder is on.
  Future<void> setReminderOn({required bool on}) async {
    if (!_enabled) return;
    await _fa.setUserProperty(name: 'reminder_on', value: on ? 'true' : 'false');
  }
```

Run: `flutter test test/services/analytics_service_test.dart`
Expected: PASS. The iOS tests now cover the five new entry points: nothing reaches FirebaseAnalytics.

- [ ] **Step 3: Add the shared test helpers**

At the top of `test/services/reminder_fakes.dart`, replace its two `import` lines for the app with:

```dart
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_platform.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
```

(keep `import 'dart:async';` first), and add at the end of the file:

```dart
/// FirebaseAnalytics that records, for an Android-mode AnalyticsService (on
/// the test host AnalyticsService is otherwise a no-op).
class RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];
  final Map<String, String?> properties = {};

  /// The events called [name], with their parameters.
  Iterable<Map<String, Object?>> named(String name) =>
      events.where((e) => e['name'] == name);

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add({'name': name, ...?parameters});
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    properties[name] = value;
  }
}

/// A ReminderService on [platform], recording analytics in [recorder], with
/// its clock at [now]. It is installed as the app's ReminderService (reset
/// `ReminderService.testInstance = null` in tearDown). [initialise] runs
/// `init()`, as app start does.
Future<ReminderService> installReminderService({
  required FakeReminderPlatform platform,
  required RecordingAnalytics recorder,
  DateTime Function()? now,
  GiftNightCheck nextStickerOpensGift = noStickerGifts,
  bool initialise = true,
}) async {
  final analytics = AnalyticsService.forTesting(
    isAndroid: true,
    analytics: recorder,
  );
  await analytics.init();
  final service = ReminderService.forTesting(
    platform: platform,
    analytics: analytics,
    now: now,
    nextStickerOpensGift: nextStickerOpensGift,
  );
  ReminderService.testInstance = service;
  if (initialise) await service.init();
  return service;
}
```

- [ ] **Step 4: Write the failing service tests**

Create `test/services/reminder_service_test.dart`:

```dart
// test/services/reminder_service_test.dart
import 'dart:async';
import 'dart:io';

import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_fakes.dart';

/// ReminderService (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §2–§6): what
/// it plans and when, the offers, and that the notification system can never
/// break the app. The clock is a Thursday, 9 am, unless a test moves it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late DateTime now;

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    now = DateTime(2026, 10, 15, 9);
  });

  tearDown(() {
    ReminderService.testInstance = null;
  });

  Future<ReminderService> service({
    Map<String, Object> prefs = const {},
    GiftNightCheck gift = noStickerGifts,
    bool initialise = true,
  }) {
    SharedPreferences.setMockInitialValues(prefs);
    return installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => now,
      nextStickerOpensGift: gift,
      initialise: initialise,
    );
  }

  const eveningOn = <String, Object>{
    ReminderService.keyEveningEnabled: true,
    ReminderService.keyEveningTime: 19 * 60 + 30,
  };

  /// 7:30 pm on each date of October 2026 from [first] to [last].
  List<DateTime> nights(int first, int last) => [
    for (var d = first; d <= last; d++) DateTime(2026, 10, d, 19, 30),
  ];

  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('start-up', () {
    test('sets the plugin up and asks for no permission', () async {
      await service();
      expect(platform.calls.first, 'init');
      expect(platform.permissionRequests, 0);
    });

    test('plans the week; the app being open holds tonight back', () async {
      await service(prefs: eveningOn);
      expect(platform.pendingTimes, nights(16, 21));
    });

    test('a reminder that started the app is counted', () async {
      platform.launchSlotValue = 'evening';
      await service();
      expect(recorder.named('app_open_from_reminder'), [
        {'name': 'app_open_from_reminder', 'slot': 'evening'},
      ]);
    });

    test('a tap while the app runs is counted', () async {
      await service();
      platform.onTap!('morning');
      await pumpEventQueue();
      expect(recorder.named('app_open_from_reminder'), [
        {'name': 'app_open_from_reminder', 'slot': 'morning'},
      ]);
    });

    test('the reminder_on user property follows the setting', () async {
      await service(prefs: eveningOn);
      expect(recorder.properties['reminder_on'], 'true');
    });

    test('nothing touches the plugin before init', () async {
      final s = await service(prefs: eveningOn, initialise: false);
      await s.reschedule();
      await s.onAppPaused();
      await s.resetAll();
      expect(platform.calls, isEmpty);
    });

    test('init with a failing plugin leaves reminders off, quietly', () async {
      platform.failure = StateError('no plugin');
      final s = await service(prefs: eveningOn);
      platform.failure = null;
      await s.onAppPaused();
      expect(platform.calls, ['init']);
      expect(platform.pending, isEmpty);
    });
  });

  group('the week', () {
    test(
      'leaving the app brings tonight back; coming back holds it again',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        expect(platform.pendingTimes, nights(15, 21));
        await s.onAppResumed();
        expect(platform.pendingTimes, nights(16, 21));
      },
    );

    test(
      "a brush this evening drops tonight's reminder, not tomorrow's",
      () async {
        now = DateTime(2026, 10, 15, 18);
        final s = await service(
          prefs: {...eveningOn, 'evening_done_date': '2026-10-15'},
        );
        await s.onAppPaused();
        expect(platform.pendingTimes, nights(16, 21));
      },
    );

    test('a morning brush leaves tonight on', () async {
      final s = await service(
        prefs: {...eveningOn, 'morning_done_date': '2026-10-15'},
      );
      await s.onAppPaused();
      expect(platform.pendingTimes, nights(15, 21));
    });

    test('the parent Pause holds every reminder before its end', () async {
      final s = await service(
        prefs: {
          ...eveningOn,
          'streak_pause_until': DateTime(2026, 10, 18).toIso8601String(),
        },
      );
      await s.onAppPaused();
      expect(platform.pendingTimes, nights(18, 21));
    });

    test('with a reminder on, every reminder id is cleared first, shown ones '
        'too', () async {
      final s = await service(prefs: eveningOn);
      platform.cancelled.clear();
      await s.onAppPaused();
      expect(platform.cancelled.toSet(), allReminderIds().toSet());
    });

    test(
      'turning everything off cancels what waits, and nothing else',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        platform.pending[7] = PlannedReminder(
          id: 7,
          slot: ReminderSlot.evening,
          at: DateTime(2026, 10, 20),
          title: 'not ours',
          body: 'not ours',
        );
        await s.saveSettings(const ReminderSettings());
        expect(platform.pending.keys, [7]);
        expect(platform.cancelled, isNot(contains(7)));
      },
    );

    test('one instant that fails to schedule does not stop the rest', () async {
      platform.failScheduleFor = {
        reminderIdFor(ReminderSlot.evening, DateTime(2026, 10, 17)),
      };
      final s = await service(prefs: eveningOn);
      await s.onAppPaused();
      expect(platform.pendingTimes, [...nights(15, 16), ...nights(18, 21)]);
    });

    test(
      'calls that overlap make one more plan, after the last change',
      () async {
        final s = await service(prefs: eveningOn);
        platform.calls.clear();
        final hold = Completer<void>();
        platform.holdSchedule = hold;
        final first = s.onAppPaused();
        final second = s.onAppResumed();
        final third = s.onAppPaused();
        await pumpEventQueue(); // the first plan now waits inside schedule()
        final saved = await prefs();
        await saved.setBool(ReminderService.keyEveningEnabled, false);
        hold.complete();
        await Future.wait([first, second, third]);
        // Two plans, not three: the first, then one more with the reminder off
        // (only a plan with nothing on asks what waits).
        expect(platform.calls.where((c) => c == 'pendingIds'), hasLength(1));
        expect(platform.pending, isEmpty);
      },
    );
  });

  group('failures', () {
    for (final failure in [
      (name: 'an Exception', value: Exception('MissingPluginException')),
      (name: 'an Error', value: StateError('LateInitializationError')),
    ]) {
      test('a failing plugin never throws (${failure.name})', () async {
        final s = await service(prefs: eveningOn);
        platform.failure = failure.value;
        await expectLater(s.onAppPaused(), completes);
        await expectLater(
          s.turnOn(const ReminderSettings(eveningOn: true)),
          completion(isFalse),
        );
        await expectLater(s.notificationsAllowed(), completion(isFalse));
        await expectLater(s.openPhoneSettings(), completes);
        await expectLater(s.resetAll(), completes);
        await expectLater(s.offerDue(), completes);
      });
    }

    test('a failing gift check means no gift line', () async {
      final s = await service(
        prefs: eveningOn,
        gift: () async => throw StateError('card'),
      );
      await s.onAppPaused();
      expect(platform.pending, hasLength(7));
      expect(
        platform.pending.values.map((r) => r.body),
        isNot(contains(kEveningCopyGift.body)),
      );
    });
  });

  group('turning it on', () {
    test('asks the OS, then saves and plans; no more hand-offs', () async {
      final s = await service();
      final on = await s.turnOn(
        const ReminderSettings(
          eveningOn: true,
          evening: (hour: 19, minute: 45),
        ),
      );
      expect(on, isTrue);
      expect(platform.permissionRequests, 1);
      final saved = await prefs();
      expect(saved.getBool(ReminderService.keyEveningEnabled), isTrue);
      expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60 + 45);
      expect(saved.getBool(ReminderService.keyMorningEnabled), isFalse);
      expect(saved.getBool(ReminderService.keyDecided), isTrue);
      expect(results(), ['enabled']);
      expect(recorder.named('reminder_enabled'), [
        {'name': 'reminder_enabled', 'evening_hour': 19, 'morning': 0},
      ]);
      expect(recorder.properties['reminder_on'], 'true');
      // The app is open (Screen B): tonight waits for it to be left.
      expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19, 45));
    });

    test("the OS says no: nothing saved as on, and it was the parent's "
        'decision', () async {
      platform.grant = false;
      final s = await service();
      expect(await s.turnOn(const ReminderSettings(eveningOn: true)), isFalse);
      final saved = await prefs();
      expect(saved.containsKey(ReminderService.keyEveningEnabled), isFalse);
      expect(saved.getBool(ReminderService.keyDecided), isTrue);
      expect(platform.pending, isEmpty);
      expect(results(), ['os_denied']);
      expect(recorder.named('reminder_enabled'), isEmpty);
    });

    test('saveSettings never turns a reminder on: only turnOn can', () async {
      final s = await service();
      await s.saveSettings(
        const ReminderSettings(eveningOn: true, morningOn: true),
      );
      expect((await s.settings()).anyOn, isFalse);
      expect(platform.permissionRequests, 0);
      expect(platform.pending, isEmpty);
    });

    test('a new time while on is planned at once', () async {
      final s = await service(prefs: eveningOn);
      await s.onAppPaused();
      await s.saveSettings(
        const ReminderSettings(eveningOn: true, evening: (hour: 20, minute: 0)),
      );
      expect(platform.pendingTimes.first, DateTime(2026, 10, 15, 20));
      expect(platform.pendingTimes, hasLength(7));
    });
  });

  group('settings', () {
    test(
      'nothing saved: both off, the evening time from the first brush',
      () async {
        final s = await service(
          prefs: {
            'brush_history': [
              '{"date":"2026-10-12","time":"20:15","heroId":"blaze","worldId":"candy_crater"}',
              '{"date":"2026-10-14","time":"07:05","heroId":"blaze","worldId":"candy_crater"}',
            ],
          },
          initialise: false,
        );
        final settings = await s.settings();
        expect(settings.anyOn, isFalse);
        expect(settings.evening, (hour: 19, minute: 45));
        expect(settings.morning, kDefaultMorningTime);
      },
    );

    test('an unreadable history suggests 7:30 pm', () async {
      final s = await service(
        prefs: {
          'brush_history': ['{"date":"2026-10-14"}'],
        },
        initialise: false,
      );
      expect((await s.settings()).evening, kDefaultEveningTime);
    });

    test(
      'a saved time is kept; a saved value of the wrong type is ignored',
      () async {
        final s = await service(
          prefs: {
            ReminderService.keyEveningTime: 20 * 60,
            ReminderService.keyMorningTime: 'oops',
          },
          initialise: false,
        );
        final settings = await s.settings();
        expect(settings.evening, (hour: 20, minute: 0));
        expect(settings.morning, kDefaultMorningTime);
      },
    );
  });

  group('offers (spec §2)', () {
    test('the first brush: offer 1; showing it saves its number and the '
        'date', () async {
      final s = await service(prefs: {'total_brushes': 1}, initialise: false);
      expect(await s.offerDue(), ReminderOffer.first);
      await s.noteOfferShown(ReminderOffer.first);
      final saved = await prefs();
      expect(saved.getInt(ReminderService.keyOfferCount), 1);
      expect(saved.getString(ReminderService.keyOfferLastDate), '2026-10-15');
      expect(await s.offerDue(), isNull);
      expect(recorder.named('reminder_offer_shown'), [
        {'name': 'reminder_offer_shown', 'offer': '1'},
      ]);
    });

    test('skipped yesterday: offer 2 from the 3rd brush', () async {
      final s = await service(
        prefs: {
          'total_brushes': 3,
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: '2026-10-14',
        },
        initialise: false,
      );
      expect(await s.offerDue(), ReminderOffer.second);
    });

    test('skip, timeout and the gate leave offer 2 open; "Not now" ends the '
        'offers', () async {
      final s = await service(
        prefs: {
          'total_brushes': 3,
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: '2026-10-14',
        },
        initialise: false,
      );
      await s.noteOfferResult(ReminderOfferResult.skipped);
      await s.noteOfferResult(ReminderOfferResult.timeout);
      await s.noteOfferResult(ReminderOfferResult.gateOpened);
      expect(await s.offerDue(), ReminderOffer.second);
      await s.noteOfferResult(ReminderOfferResult.notNow);
      expect(await s.offerDue(), isNull);
      expect(results(), ['skipped', 'timeout', 'gate_opened', 'not_now']);
    });

    test('no offer while a reminder is on', () async {
      final s = await service(
        prefs: {...eveningOn, 'total_brushes': 1},
        initialise: false,
      );
      expect(await s.offerDue(), isNull);
    });

    test('the Parent Zone counts as an offer of its own', () async {
      final s = await service(initialise: false);
      s.noteParentZoneOffer();
      await pumpEventQueue();
      expect(recorder.named('reminder_offer_shown'), [
        {'name': 'reminder_offer_shown', 'offer': 'parent_zone'},
      ]);
    });

    test('offers read saved state only: they never touch the plugin', () async {
      final s = await service(prefs: {'total_brushes': 1});
      platform.calls.clear();
      await s.offerDue();
      await s.noteOfferShown(ReminderOffer.first);
      await s.noteOfferResult(ReminderOfferResult.skipped);
      expect(platform.calls, isEmpty);
    });
  });

  group('gift nights (Part B wires the check)', () {
    test(
      'until the sticker card ships, no reminder carries the gift line',
      () async {
        final s = await service(prefs: eveningOn);
        await s.onAppPaused();
        expect(
          platform.pending.values.map((r) => r.body),
          isNot(contains(kEveningCopyGift.body)),
        );
      },
    );

    test(
      'a gift next and nothing brushed today: every night says it',
      () async {
        final s = await service(prefs: eveningOn, gift: () async => true);
        await s.onAppPaused();
        expect(
          {for (final r in platform.pending.values) r.body},
          {kEveningCopyGift.body},
        );
      },
    );

    test('the card is asked only when the evening reminder is on', () async {
      var asked = 0;
      Future<bool> gift() async {
        asked++;
        return true;
      }

      final s = await service(
        prefs: {
          ReminderService.keyMorningEnabled: true,
          ReminderService.keyMorningTime: 7 * 60,
        },
        gift: gift,
      );
      await s.onAppPaused();
      expect(asked, 0);
      expect(platform.pending, isNotEmpty);
    });
  });

  test(
    'Start fresh: everything cancelled, every reminder key forgotten',
    () async {
      final s = await service(
        prefs: {
          ...eveningOn,
          ReminderService.keyMorningEnabled: true,
          ReminderService.keyMorningTime: 7 * 60,
          ReminderService.keyDecided: true,
          ReminderService.keyOfferCount: 2,
          ReminderService.keyOfferLastDate: '2026-10-01',
        },
      );
      await s.resetAll();
      expect(platform.cancelAllCalls, 1);
      expect(platform.pending, isEmpty);
      final saved = await prefs();
      for (final key in ReminderService.allKeys) {
        expect(saved.containsKey(key), isFalse, reason: key);
      }
      expect(recorder.properties['reminder_on'], 'false');
    },
  );

  test('the keys stay on this device: none is synced', () {
    final sync = File('lib/services/sync_service.dart').readAsStringSync();
    expect(sync, isNot(contains("'reminder_")));
    for (final key in ReminderService.allKeys) {
      expect(key, startsWith('reminder_'));
    }
  });
}
```

- [ ] **Step 5: Run it to make sure it fails**

Run: `flutter test test/services/reminder_service_test.dart`
Expected: FAIL to compile, because `reminder_service.dart` doesn't exist.

- [ ] **Step 6: Create `lib/services/reminder_service.dart`**

The order of the methods is part of the contract (Task 7's structural test).

```dart
// lib/services/reminder_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';
import 'streak_service.dart';

/// Whether the next sticker the card places opens a gift: it is the 3rd or
/// the 7th (sticker-card spec §4.1). The card is Part B of the 2026-10-15
/// rework. Until it ships, [noStickerGifts] answers, and no reminder carries
/// the gift line.
typedef GiftNightCheck = Future<bool> Function();

/// Before the sticker card: no night is a gift night.
Future<bool> noStickerGifts() async => false;

/// The parent bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md): the
/// parent's settings, the hand-off offers, and a rolling week of one-shot
/// notifications ([planReminders]). Everything stays on this device; none of
/// its keys is synced. No call into the notification system may break the
/// app: each one is guarded, and nothing is scheduled before [init].
class ReminderService {
  factory ReminderService() => _testInstance ?? _instance;

  /// A service on [platform] (in tests, a fake), with its own [analytics],
  /// clock and gift check.
  @visibleForTesting
  ReminderService.forTesting({
    required ReminderPlatform platform,
    AnalyticsService? analytics,
    DateTime Function()? now,
    GiftNightCheck nextStickerOpensGift = noStickerGifts,
  }) : this._(platform, analytics, now ?? DateTime.now, nextStickerOpensGift);

  ReminderService._(
    this._platform,
    this._analyticsOverride,
    this._now,
    this._nextStickerOpensGift,
  );

  // Part B (the sticker card) replaces noStickerGifts here with the card's
  // own check: true when its count is 2 or 6 (the next sticker is the 3rd or
  // the 7th), false on a full card (the next one starts a new card).
  static final ReminderService _instance = ReminderService._(
    PluginReminderPlatform(),
    null,
    DateTime.now,
    noStickerGifts,
  );

  static ReminderService? _testInstance;

  /// The service a test installed, if any.
  @visibleForTesting
  static ReminderService? get testInstance => _testInstance;

  /// Tests install their service here; null brings the real one back.
  @visibleForTesting
  static set testInstance(ReminderService? service) => _testInstance = service;

  static const keyEveningEnabled = 'reminder_evening_enabled';
  static const keyEveningTime = 'reminder_evening_time';
  static const keyMorningEnabled = 'reminder_morning_enabled';
  static const keyMorningTime = 'reminder_morning_time';
  static const keyOfferCount = 'reminder_offer_count';
  static const keyOfferLastDate = 'reminder_offer_last_date';
  static const keyDecided = 'reminder_decided';

  /// Every reminder key. Per device (none is in SyncService's keys); "Start
  /// fresh" removes them all.
  static const allKeys = [
    keyEveningEnabled,
    keyEveningTime,
    keyMorningEnabled,
    keyMorningTime,
    keyOfferCount,
    keyOfferLastDate,
    keyDecided,
  ];

  final ReminderPlatform _platform;
  final AnalyticsService? _analyticsOverride;
  final DateTime Function() _now;
  final GiftNightCheck _nextStickerOpensGift;

  AnalyticsService get _analytics => _analyticsOverride ?? AnalyticsService();

  /// True once [init] has set the plugin up. Before that (and in tests that
  /// never call it) nothing is scheduled and the plugin is never touched.
  bool _ready = false;

  /// The app is open: no reminder shows today (spec §4). It starts open.
  bool _foreground = true;

  Future<void>? _rescheduling;
  bool _rescheduleAgain = false;

  /// App start (main.dart): sets the plugin up, asking for no permission;
  /// counts an app open from a reminder; plans the week.
  Future<void> init() async {
    if (_ready) return;
    try {
      await _platform.init(onTap: _onReminderTapped);
    } on Object catch (e) {
      debugPrint('Reminders unavailable: $e');
      return;
    }
    _ready = true;
    final slot = await _safe(_platform.launchSlot, null);
    if (slot != null) _onReminderTapped(slot);
    final prefs = await SharedPreferences.getInstance();
    unawaited(_analytics.setReminderOn(on: _readSettings(prefs).anyOn));
    await reschedule();
  }

  /// A tap on a reminder only opens the app, to Home and its usual greeting
  /// (spec §4: no deep link).
  void _onReminderTapped(String? slot) {
    unawaited(_analytics.logAppOpenFromReminder(slot: slot ?? 'unknown'));
  }

  /// The app is back on screen: today's reminders wait while it is open, and
  /// the week is planned again from now.
  Future<void> onAppResumed() {
    _foreground = true;
    return reschedule();
  }

  /// The app was left: today's reminders are planned again.
  Future<void> onAppPaused() {
    _foreground = false;
    return reschedule();
  }

  /// Plans the week again and replaces what waits (spec §5): at start, on
  /// resume and pause, after every brush, and when the Pause or a setting
  /// changes. A call that comes while one runs makes it run once more, after
  /// the last change. Never throws.
  Future<void> reschedule() {
    if (!_ready) return Future<void>.value();
    final running = _rescheduling;
    if (running != null) {
      _rescheduleAgain = true;
      return running;
    }
    return _rescheduling = _rescheduleLoop();
  }

  Future<void> _rescheduleLoop() async {
    try {
      do {
        _rescheduleAgain = false;
        await _rescheduleOnce();
      } while (_rescheduleAgain);
    } on Object catch (e) {
      debugPrint('Reminder planning failed: $e');
    } finally {
      _rescheduling = null;
    }
  }

  Future<void> _rescheduleOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = _readSettings(prefs);
    final now = _now();
    final streak = StreakService();
    final today = await streak.getSlotsOn(now);
    final pauseUntil = await streak.getStreakPauseEnd();
    final gift =
        settings.eveningOn && await _safe(_nextStickerOpensGift, false);
    final plan = planReminders(
      now: now,
      settings: settings,
      morningDoneToday: today.morningDone,
      eveningDoneToday: today.eveningDone,
      pauseUntil: pauseUntil,
      nextStickerOpensGift: gift,
      appInForeground: _foreground,
    );
    if (settings.anyOn) {
      // Every reminder id, waiting or showing: a reminder the parent has seen
      // goes once the app is opened or a brush is recorded.
      for (final id in allReminderIds()) {
        await _try(() => _platform.cancel(id));
      }
    } else {
      for (final id in await _safe(_platform.pendingIds, const <int>[])) {
        if (isReminderId(id)) await _try(() => _platform.cancel(id));
      }
    }
    for (final reminder in plan) {
      await _try(() => _platform.schedule(reminder));
    }
  }

  /// The parent's settings. With no evening time saved yet, the evening time
  /// is the one suggested from the first brush (spec §3.2).
  Future<ReminderSettings> settings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readSettings(prefs);
    if (prefs.get(keyEveningTime) is int) return saved;
    return saved.copyWith(evening: await suggestedEveningTime());
  }

  /// 30 minutes before the first brush, or 7:30 pm ([defaultEveningTime]).
  Future<ReminderTime> suggestedEveningTime() async {
    try {
      final history = await StreakService().getHistory(); // newest first
      return defaultEveningTime(history.isEmpty ? null : history.last.time);
    } on Object catch (e) {
      debugPrint('Brush history unreadable: $e');
      return kDefaultEveningTime;
    }
  }

  /// TURN ON (Screen B), or a Parent Zone switch turned on (spec §3.2): the
  /// OS prompt first, and the reminder is saved only if the OS allows it.
  /// Either answer is the parent's decision: no more hand-offs.
  Future<bool> turnOn(ReminderSettings wanted) async {
    final granted = await _safe(_platform.requestPermission, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDecided, true);
    final result = granted
        ? ReminderOfferResult.enabled
        : ReminderOfferResult.osDenied;
    unawaited(_analytics.logReminderOfferResult(result: result.analyticsName));
    if (!granted) return false;
    await _writeSettings(prefs, wanted);
    unawaited(
      _analytics.logReminderEnabled(
        eveningHour: wanted.evening.hour,
        morning: wanted.morningOn,
      ),
    );
    unawaited(_analytics.setReminderOn(on: wanted.anyOn));
    await reschedule();
    return true;
  }

  /// The Parent Zone's other changes: a switch turned off, a new time.
  /// Turning a reminder on goes through [turnOn] (the OS must allow it
  /// first), so here a reminder that is off stays off.
  Future<void> saveSettings(ReminderSettings changed) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _readSettings(prefs);
    final allowed = changed.copyWith(
      eveningOn: changed.eveningOn && current.eveningOn,
      morningOn: changed.morningOn && current.morningOn,
    );
    await _writeSettings(prefs, allowed);
    unawaited(_analytics.setReminderOn(on: allowed.anyOn));
    await reschedule();
  }

  /// When DONE is tapped after a finished brush: the hand-off to show, or
  /// null (spec §2, [reminderOfferDue]). Saved state only; the OS is never
  /// asked. On Android 13+ it can't tell "never asked" from "refused", so a
  /// refusal in our own flow is saved as the parent's decision instead.
  Future<ReminderOffer?> offerDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.get(keyOfferCount);
      final last = prefs.get(keyOfferLastDate);
      return reminderOfferDue(
        offersShown: shown is int ? shown : 0,
        lastOfferDate: last is String ? last : null,
        decided: prefs.get(keyDecided) == true,
        remindersOn: _readSettings(prefs).anyOn,
        totalBrushes: await StreakService().getTotalBrushes(),
        today: StreakService.dateKey(_now()),
      );
    } on Object catch (e) {
      debugPrint('Reminder offer skipped: $e');
      return null;
    }
  }

  /// The hand-off is on screen: [offer] has been made, today.
  Future<void> noteOfferShown(ReminderOffer offer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyOfferCount, offer.number);
    await prefs.setString(keyOfferLastDate, StreakService.dateKey(_now()));
    unawaited(_analytics.logReminderOfferShown(offer: '${offer.number}'));
  }

  /// A Parent Zone switch is being turned on: the Parent Zone's own offer
  /// (ruling R-6). [turnOn] sends its result.
  void noteParentZoneOffer() {
    unawaited(_analytics.logReminderOfferShown(offer: 'parent_zone'));
  }

  /// How the hand-off went: gate opened, skipped, timeout or "Not now"
  /// ([turnOn] sends the OS's answer itself). "Not now" is the parent's
  /// decision: no more hand-offs.
  Future<void> noteOfferResult(ReminderOfferResult result) async {
    if (result == ReminderOfferResult.notNow) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyDecided, true);
    }
    unawaited(_analytics.logReminderOfferResult(result: result.analyticsName));
  }

  /// Whether the OS lets Brush Quest show notifications (the Parent Zone).
  Future<bool> notificationsAllowed() =>
      _safe(_platform.notificationsAllowed, false);

  /// "Open phone settings": a link out, only ever offered behind the parent
  /// gate (the Parent Zone).
  Future<void> openPhoneSettings() => _try(_platform.openSettings);

  /// "Start fresh" (Settings): every reminder cancelled, shown ones too, and
  /// every reminder key removed (spec §4).
  Future<void> resetAll() async {
    if (_ready) await _try(_platform.cancelAll);
    final prefs = await SharedPreferences.getInstance();
    for (final key in allKeys) {
      await prefs.remove(key);
    }
    unawaited(_analytics.setReminderOn(on: false));
  }

  /// The saved settings. A value of the wrong type (an odd old save) reads
  /// as not saved.
  ReminderSettings _readSettings(SharedPreferences prefs) {
    ReminderTime time(String key, ReminderTime fallback) {
      final value = prefs.get(key);
      return value is int ? reminderTimeFromMinutes(value) : fallback;
    }

    return ReminderSettings(
      eveningOn: prefs.get(keyEveningEnabled) == true,
      evening: time(keyEveningTime, kDefaultEveningTime),
      morningOn: prefs.get(keyMorningEnabled) == true,
      morning: time(keyMorningTime, kDefaultMorningTime),
    );
  }

  Future<void> _writeSettings(
    SharedPreferences prefs,
    ReminderSettings settings,
  ) async {
    await prefs.setBool(keyEveningEnabled, settings.eveningOn);
    await prefs.setInt(keyEveningTime, reminderMinutes(settings.evening));
    await prefs.setBool(keyMorningEnabled, settings.morningOn);
    await prefs.setInt(keyMorningTime, reminderMinutes(settings.morning));
  }

  /// One call into the notification system. A reminder must never break the
  /// app: a failure (an Exception, or an Error such as the
  /// LateInitializationError of an unregistered plugin) is logged and
  /// [fallback] returned.
  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on Object catch (e) {
      debugPrint('Reminder platform call failed: $e');
      return fallback;
    }
  }

  Future<void> _try(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (e) {
      debugPrint('Reminder platform call failed: $e');
    }
  }
}
```

- [ ] **Step 7: Run the service tests**

Run: `flutter test test/services/reminder_service_test.dart test/services/reminder_plan_test.dart test/services/analytics_service_test.dart test/services/streak_service_test.dart`
Expected: all PASS.

- [ ] **Step 8: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes. Nothing calls the service yet.

- [ ] **Step 9: Commit**

```bash
git add lib/services/reminder_service.dart lib/services/analytics_service.dart lib/services/streak_service.dart test/services/reminder_fakes.dart test/services/reminder_service_test.dart test/services/analytics_service_test.dart test/services/streak_service_test.dart
git commit -m "feat(reminder): ReminderService: settings, offers and a guarded weekly plan

One serialised reschedule() for start, resume, pause, brushes and
setting changes; the OS asked only from turnOn() and the reminder saved
only if it allows; nothing scheduled before init(), and no plugin
failure (Exception or Error) can escape. The gift line waits for the
sticker card: GiftNightCheck is always false until Part B.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 4: One GROWN-UP CHECK for onboarding and the hand-off

The onboarding camera page's gate moves, unchanged, to a shared widget, so the reminder hand-off opens the very same check (ruling R-7). This is a pure move: same dialog, same problems, same `barrierDismissible: false`. `OnboardingScreen.debugGateRandom` keeps seeding it.

**Files:**
- Create: `lib/widgets/parent_gate_dialog.dart`
- Modify: `lib/screens/onboarding_screen.dart`: an import (after line 7); `_showParentGate()` (lines 1181-1194); delete `_ParentGateDialog` and its state (lines 1243-1394)
- Modify: `test/flows/camera_mode_flow_test.dart` (the `GROWN-UP CHECK` expectation, lines 33-37)
- Modify: `test/screens/onboarding_parent_gate_test.dart` (the doc comment, lines 11-12)
- Create: `test/widgets/parent_gate_dialog_test.dart`
- Unchanged, and must still pass: `test/screens/onboarding_parent_gate_test.dart` (its tests), `test/screens/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces (Task 6 relies on this):
  - `Future<bool?> showParentGate(BuildContext context, {Random? random})`: `true` when answered, `false` on CANCEL, never dismissed by a tap outside.
  - `class ParentGateDialog extends StatefulWidget` with `const ParentGateDialog({super.key, this.random})`.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/parent_gate_dialog_test.dart`:

```dart
// test/widgets/parent_gate_dialog_test.dart
import 'dart:math';

import 'package:brush_quest/widgets/parent_gate_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared GROWN-UP CHECK (moved unchanged from onboarding): onboarding's
/// camera page and the bedtime-reminder hand-off both open it.
void main() {
  /// A page with one button that opens the gate and keeps its answers.
  Future<List<bool?>> pumpOpener(WidgetTester tester, {Random? random}) async {
    final answers = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    answers.add(await showParentGate(context, random: random)),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return answers;
  }

  ({int a, int b}) problem(WidgetTester tester) {
    final text = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(text)!;
    return (a: int.parse(m.group(1)!), b: int.parse(m.group(2)!));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a right answer closes it with true', (tester) async {
    final answers = await pumpOpener(tester);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    final p = problem(tester);
    await tester.enterText(find.byType(TextField), '${p.a * p.b}');
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('CANCEL closes it with false', (tester) async {
    final answers = await pumpOpener(tester);
    await tester.tap(find.text('CANCEL'));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('a tap outside does not close it', (tester) async {
    final answers = await pumpOpener(tester);
    await tester.tapAt(const Offset(4, 4));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('a wrong answer deals a new problem from the given Random', (
    tester,
  ) async {
    final expected = Random(8);
    final first = (a: 4 + expected.nextInt(6), b: 3 + expected.nextInt(5));
    final second = (a: 4 + expected.nextInt(6), b: 3 + expected.nextInt(5));
    final answers = await pumpOpener(tester, random: Random(8));
    expect(problem(tester), first);
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Try again!'), findsOneWidget);
    expect(problem(tester), second);
    expect(answers, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/widgets/parent_gate_dialog_test.dart`
Expected: FAIL to compile, because `parent_gate_dialog.dart` doesn't exist.

- [ ] **Step 3: Create `lib/widgets/parent_gate_dialog.dart`**

Everything from `@override void initState()` down is the onboarding dialog, character for character. Only the class names, the `random` field and the doc comments are new.

```dart
// lib/widgets/parent_gate_dialog.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the GROWN-UP CHECK, the parent gate in front of anything a child
/// must not do alone (Apple Guideline 1.3, COPPA): `true` once it is
/// answered, `false` on CANCEL. A tap outside never closes it: an accidental
/// tap just outside the dialog (Jim hit it on the Android emulator) must not
/// silently bail out. [random] deals the problems; tests pass a seeded one.
/// Opened by the onboarding camera page and the bedtime-reminder hand-off.
Future<bool?> showParentGate(BuildContext context, {Random? random}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ParentGateDialog(random: random),
  );
}

/// A typed answer to "A × B" with A in 4..9 and B in 3..7, the same kind of
/// check as the Settings Parent Check. A fixed question with tap targets
/// could be memorised or brute-forced by a child, so a wrong or empty answer
/// clears the field and deals a new problem. Pops `true` on a correct answer
/// and `false` on CANCEL.
class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, this.random});

  /// Deals the problems; a new [Random] when null.
  final Random? random;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _answerController = TextEditingController();
  late final Random _random = widget.random ?? Random();
  late int _mathA;
  late int _mathB;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newProblem();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _newProblem() {
    _mathA = 4 + _random.nextInt(6);
    _mathB = 3 + _random.nextInt(5);
  }

  void _checkAnswer() {
    final answer = int.tryParse(_answerController.text.trim());
    if (answer == _mathA * _mathB) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Try again!';
        _answerController.clear();
        _newProblem();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // The number keypad shrinks the screen: scroll instead of overflowing.
      scrollable: true,
      backgroundColor: const Color(0xFF1A0A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'GROWN-UP CHECK',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type the answer:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            '$_mathA × $_mathB = ?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _answerController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              onSubmitted: (_) => _checkAnswer(),
              decoration: InputDecoration(
                hintText: '?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 24,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF00E5FF),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _checkAnswer,
          child: const Text(
            'CONTINUE',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Onboarding opens the shared gate**

In `lib/screens/onboarding_screen.dart`:

1. After `import '../widgets/mouth_guide.dart';` (line 7) add `import '../widgets/parent_gate_dialog.dart';`.
2. Replace `_showParentGate()` and its doc comment (lines 1181-1194, from `/// Parental gate: a typed, random multiplication` to the method's closing `}`) with:

```dart
  /// Parental gate: the shared GROWN-UP CHECK ([showParentGate]), a typed,
  /// random multiplication like the Settings Parent Check, dealt from this
  /// screen's test seed. Mirrors the COPPA "parent gate" pattern used by
  /// Apple-Kids-approved apps.
  Future<bool?> _showParentGate() =>
      showParentGate(context, random: OnboardingScreen.debugGateRandom);
```

3. Delete from the line `/// The GROWN-UP CHECK shown before the camera consent. Same kind of check as` (line 1243) through the closing `}` of `_ParentGateDialogState` (line 1394), and the blank line after it. Keep `/// Starburst / zap impact effect between hero and monster.` and the `_ImpactBurst` class that follows.

`dart:math` stays imported (the screen's animations use `sin` and `pi`), and so does `package:flutter/services.dart` (`HapticFeedback`).

- [ ] **Step 5: The camera-flow structural test follows the gate**

In `test/flows/camera_mode_flow_test.dart`, test `'onboarding camera page is parent-gated (COPPA)'`, replace

```dart
    expect(
      source.contains('GROWN-UP CHECK'),
      isTrue,
      reason: 'Onboarding must show a parental gate before enabling camera',
    );
```

with

```dart
    // The gate itself is the shared GROWN-UP CHECK, also opened by the
    // bedtime-reminder hand-off (lib/widgets/parent_gate_dialog.dart).
    final gate = File(
      'lib/widgets/parent_gate_dialog.dart',
    ).readAsStringSync();
    expect(
      source.contains('showParentGate('),
      isTrue,
      reason: 'Onboarding must show a parental gate before enabling camera',
    );
    expect(gate.contains('GROWN-UP CHECK'), isTrue);
    expect(
      gate.contains('barrierDismissible: false'),
      isTrue,
      reason: 'A tap outside the gate must not dismiss it',
    );
```

In `test/screens/onboarding_parent_gate_test.dart`, change the doc comment's second line from `/// onboarding camera page (\`_ParentGateDialog\` in onboarding_screen.dart).` to `/// onboarding camera page (the shared \`ParentGateDialog\`, lib/widgets/parent_gate_dialog.dart).`. Its tests don't change.

- [ ] **Step 6: Run the gate, onboarding and camera-flow tests**

Run: `flutter test test/widgets/parent_gate_dialog_test.dart test/screens/onboarding_parent_gate_test.dart test/screens/onboarding_screen_test.dart test/flows/camera_mode_flow_test.dart`
Expected: all PASS. The onboarding gate tests pass unchanged, which is the proof the move changed nothing.

- [ ] **Step 7: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/parent_gate_dialog.dart lib/screens/onboarding_screen.dart test/widgets/parent_gate_dialog_test.dart test/flows/camera_mode_flow_test.dart test/screens/onboarding_parent_gate_test.dart
git commit -m "refactor(gate): the GROWN-UP CHECK becomes a shared widget

Moved unchanged from the onboarding camera page so the bedtime-reminder
hand-off opens the same check. The onboarding gate tests pass as they
were.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 5: Screen B, the parent's reminder screen

**Files:**
- Create: `lib/screens/after_brush_home.dart`
- Create: `lib/widgets/reminder_time_dropdown.dart`
- Create: `lib/screens/reminder_parent_screen.dart`
- Create: `test/widgets/reminder_time_dropdown_test.dart`
- Create: `test/screens/reminder_parent_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `ReminderTime`, `ReminderSettings`, `eveningReminderChoices`, `morningReminderChoices`, `formatReminderTime`, `reminderMinutes`, `reminderTimeFromMinutes`, `reminderConfirmation`, `ReminderOfferResult`. (Task 3): `ReminderService().settings()`, `.turnOn()`, `.noteOfferResult()`; `installReminderService`, `FakeReminderPlatform`, `RecordingAnalytics`.
- Produces:
  - `abstract final class AfterBrushHome` with `@visibleForTesting static WidgetBuilder? debugBuilder`, `static Route<void> fadeTo(WidgetBuilder builder)`, `static Route<void> route()` (to `HomeScreen(skipGreeting: true)`, or `debugBuilder`'s page) and `static Future<void> go(BuildContext context)` (push, removing every route below).
  - `class ReminderTimeDropdown extends StatelessWidget` with `const ReminderTimeDropdown({super.key, required ReminderTime value, required List<ReminderTime> choices, required ValueChanged<ReminderTime>? onChanged})`. It is a `DropdownButton<int>` over minutes after midnight.
  - `class ReminderParentScreen extends StatefulWidget` with `const ReminderParentScreen({super.key})` and `static const confirmationHold = Duration(milliseconds: 2500)`.
  - Keys: `parent_evening_time`, `parent_morning_check`, `parent_morning_time`, `parent_turn_on`, `parent_not_now`, `parent_confirmation`.

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/reminder_time_dropdown_test.dart`:

```dart
// test/widgets/reminder_time_dropdown_test.dart
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/widgets/reminder_time_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<ReminderTime>> pumpList(
    WidgetTester tester,
    ReminderTime value, {
    bool enabled = true,
  }) async {
    final picked = <ReminderTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReminderTimeDropdown(
              value: value,
              choices: eveningReminderChoices,
              onChanged: enabled ? picked.add : null,
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  DropdownButton<int> dropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));

  testWidgets('shows the time; a pick reports the new one', (tester) async {
    final picked = await pumpList(tester, (hour: 19, minute: 30));
    expect(find.text('7:30 PM'), findsOneWidget);
    await tester.tap(find.byType(ReminderTimeDropdown));
    await tester.pumpAndSettle();
    // The open list shows the times up to the current one: pick one above.
    await tester.tap(find.text('6:45 PM').last);
    await tester.pumpAndSettle();
    expect(picked, [(hour: 18, minute: 45)]);
  });

  testWidgets('offers every quarter hour from 5 to 10 pm', (tester) async {
    await pumpList(tester, (hour: 19, minute: 30));
    expect(dropdown(tester).items, hasLength(21));
  });

  testWidgets('a saved time that is not a choice still shows, without an '
      'error', (tester) async {
    await pumpList(tester, (hour: 18, minute: 10));
    expect(find.text('6:10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(dropdown(tester).items, hasLength(22));
  });

  testWidgets('without onChanged it is greyed out', (tester) async {
    await pumpList(tester, (hour: 19, minute: 30), enabled: false);
    expect(dropdown(tester).onChanged, isNull);
  });
}
```

Create `test/screens/reminder_parent_screen_test.dart`:

```dart
// test/screens/reminder_parent_screen_test.dart
import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_parent_screen.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_fakes.dart';

/// Screen B of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.2), behind
/// the GROWN-UP CHECK: the explanation first, the OS prompt only from TURN
/// ON, and the reminder saved only if the OS allows it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;

  setUpAll(() async {
    // The app's own font: the small-phone test measures real text.
    final fredoka = FontLoader('Fredoka')
      ..addFont(
        rootBundle.load(
          'assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf',
        ),
      );
    await fredoka.load();
  });

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];
  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    Size size = const Size(430, 932),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 9),
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Fredoka'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ReminderParentScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the [list] of times and picks [time]. The open list shows the
  /// times up to the current one, so tests pick an earlier time.
  Future<void> pick(WidgetTester tester, String list, String time) async {
    await tester.tap(key(list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(time).last);
    await tester.pumpAndSettle();
  }

  /// TURN ON, and the frame after the OS has answered.
  Future<void> turnOn(WidgetTester tester) async {
    await tester.tap(key('parent_turn_on'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('says what the reminder is, before any OS prompt', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('FOR GROWN-UPS'), findsOneWidget);
    expect(find.text('Want a bedtime brushing reminder?'), findsOneWidget);
    expect(
      find.text(
        "One reminder on this phone each evening, only if brushing hasn't "
        'happened yet. It stays on this device; nothing is sent to us.',
      ),
      findsOneWidget,
    );
    expect(find.text('Remind me at'), findsOneWidget);
    expect(find.text('7:30 PM'), findsOneWidget);
    expect(find.text('Morning reminder too'), findsOneWidget);
    expect(tester.widget<Checkbox>(key('parent_morning_check')).value, isFalse);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(find.text('TURN ON'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(
      find.text('Change or turn off anytime: Parents > Settings > Reminders'),
      findsOneWidget,
    );
    expect(platform.permissionRequests, 0);
  });

  testWidgets('the evening time starts 30 minutes before the first brush', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      saved: {
        'brush_history': [
          '{"date":"2026-10-14","time":"20:15","heroId":"blaze","worldId":"candy_crater"}',
        ],
      },
    );
    expect(find.text('7:45 PM'), findsOneWidget);
  });

  testWidgets('TURN ON, allowed: saved, "Reminder set for 7:30 PM", then '
      'Home', (tester) async {
    await pumpScreen(tester);
    await turnOn(tester);
    expect(platform.permissionRequests, 1);
    expect(find.text('Reminder set for 7:30 PM'), findsOneWidget);
    expect(key('parent_confirmation'), findsOneWidget);
    expect(key('parent_turn_on'), findsNothing);
    final saved = await prefs();
    expect(saved.getBool(ReminderService.keyEveningEnabled), isTrue);
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60 + 30);
    expect(saved.getBool(ReminderService.keyMorningEnabled), isFalse);
    expect(results(), ['enabled']);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('new times and the morning ticked: both saved, both confirmed', (
    tester,
  ) async {
    await pumpScreen(tester);
    await pick(tester, 'parent_evening_time', '7:00 PM');
    await tester.tap(key('parent_morning_check'));
    await tester.pump();
    await pick(tester, 'parent_morning_time', '6:45 AM');
    await turnOn(tester);
    expect(find.text('Reminders set for 7:00 PM and 6:45 AM'), findsOneWidget);
    final saved = await prefs();
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60);
    expect(saved.getBool(ReminderService.keyMorningEnabled), isTrue);
    expect(saved.getInt(ReminderService.keyMorningTime), 6 * 60 + 45);
    expect(recorder.named('reminder_enabled'), [
      {'name': 'reminder_enabled', 'evening_hour': 19, 'morning': 1},
    ]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the morning time waits for the box to be ticked', (
    tester,
  ) async {
    await pumpScreen(tester);
    final morning = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: key('parent_morning_time'),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    expect(morning.onChanged, isNull);
  });

  testWidgets('the OS says no: nothing on, no more offers, straight Home', (
    tester,
  ) async {
    platform.grant = false;
    await pumpScreen(tester);
    await turnOn(tester);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    final saved = await prefs();
    expect(saved.containsKey(ReminderService.keyEveningEnabled), isFalse);
    expect(saved.getBool(ReminderService.keyDecided), isTrue);
    expect(results(), ['os_denied']);
    expect(platform.pending, isEmpty);
  });

  testWidgets('Not now: Home, no OS prompt, no more offers', (tester) async {
    await pumpScreen(tester);
    await tester.tap(key('parent_not_now'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(platform.permissionRequests, 0);
    expect((await prefs()).getBool(ReminderService.keyDecided), isTrue);
    expect(results(), ['not_now']);
  });

  testWidgets('a double tap on TURN ON asks the OS once', (tester) async {
    await pumpScreen(tester);
    await tester.tap(key('parent_turn_on'));
    await tester.tap(key('parent_turn_on'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    expect(platform.permissionRequests, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('leaving while "Reminder set" shows leaves no timer behind', (
    tester,
  ) async {
    await pumpScreen(tester);
    await turnOn(tester);
    expect(key('parent_confirmation'), findsOneWidget);
    // A pending Timer at the end of a test fails it: dispose must cancel.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('360x640 at the largest text size: nothing overflows', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(360, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Change or turn off anytime: Parents > Settings > Reminders'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `flutter test test/widgets/reminder_time_dropdown_test.dart test/screens/reminder_parent_screen_test.dart`
Expected: FAIL to compile; the three files don't exist yet.

- [ ] **Step 3: Create `lib/screens/after_brush_home.dart`**

```dart
// lib/screens/after_brush_home.dart
import 'package:flutter/material.dart';

import 'home_screen.dart';

/// How a finished brush reaches Home: [HomeScreen] with `skipGreeting`,
/// fading in, with nothing left to go back to. The victory screen and the
/// bedtime-reminder screens all leave this way.
abstract final class AfterBrushHome {
  /// Tests build a light page here instead of the real Home.
  @visibleForTesting
  static WidgetBuilder? debugBuilder;

  /// A route to [builder]'s page that fades in.
  static Route<void> fadeTo(WidgetBuilder builder) => PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// The route to Home itself.
  static Route<void> route() =>
      fadeTo(debugBuilder ?? (_) => const HomeScreen(skipGreeting: true));

  /// Leaves for Home, removing every route below.
  static Future<void> go(BuildContext context) =>
      Navigator.of(context).pushAndRemoveUntil<void>(route(), (_) => false);
}
```

- [ ] **Step 4: Create `lib/widgets/reminder_time_dropdown.dart`**

```dart
// lib/widgets/reminder_time_dropdown.dart
import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';

/// A reminder time picked from a list of quarter hours (spec §3.2 "Remind
/// me at"; ruling R-5). A saved time that isn't one of [choices] is listed
/// too, so an older or odd value never breaks the list. With [onChanged]
/// null it is greyed out.
class ReminderTimeDropdown extends StatelessWidget {
  const ReminderTimeDropdown({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final ReminderTime value;
  final List<ReminderTime> choices;
  final ValueChanged<ReminderTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = {
      for (final choice in choices) reminderMinutes(choice),
      reminderMinutes(value),
    }.toList()..sort();
    final changed = onChanged;
    return DropdownButton<int>(
      value: reminderMinutes(value),
      dropdownColor: const Color(0xFF1A0A3E),
      iconEnabledColor: const Color(0xFF00E5FF),
      menuMaxHeight: 320,
      underline: const SizedBox.shrink(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      items: [
        for (final m in minutes)
          DropdownMenuItem(
            value: m,
            child: Text(formatReminderTime(reminderTimeFromMinutes(m))),
          ),
      ],
      onChanged: changed == null
          ? null
          : (m) {
              if (m != null) changed(reminderTimeFromMinutes(m));
            },
    );
  }
}
```

- [ ] **Step 5: Create `lib/screens/reminder_parent_screen.dart`**

```dart
// lib/screens/reminder_parent_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import '../widgets/reminder_time_dropdown.dart';
import '../widgets/space_background.dart';
import 'after_brush_home.dart';

/// Screen B of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.2): the
/// parent's own screen, reached only through the GROWN-UP CHECK on the
/// hand-off. It says what the reminder is before the OS asks anything: TURN
/// ON shows the OS prompt, and the reminder is saved only if the OS allows
/// it. "Not now" is final. The back gesture returns to the hand-off.
class ReminderParentScreen extends StatefulWidget {
  const ReminderParentScreen({super.key});

  /// How long "Reminder set for 7:45 PM" stays before Home.
  static const confirmationHold = Duration(milliseconds: 2500);

  @override
  State<ReminderParentScreen> createState() => _ReminderParentScreenState();
}

class _ReminderParentScreenState extends State<ReminderParentScreen> {
  /// What TURN ON saves: the evening reminder at the time shown, and the
  /// morning one if ticked. Null while loading.
  ReminderSettings? _wanted;
  bool _busy = false;
  String? _confirmation;
  Timer? _homeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _homeTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await ReminderService().settings();
    if (!mounted) return;
    setState(() => _wanted = saved.copyWith(eveningOn: true, morningOn: false));
  }

  void _change(ReminderSettings wanted) {
    if (_busy) return;
    setState(() => _wanted = wanted);
  }

  Future<void> _turnOn() async {
    final wanted = _wanted;
    if (wanted == null || _busy) return;
    setState(() => _busy = true);
    final on = await ReminderService().turnOn(wanted);
    if (!mounted) return;
    if (!on) {
      unawaited(AfterBrushHome.go(context));
      return;
    }
    setState(() => _confirmation = reminderConfirmation(wanted));
    _homeTimer = Timer(ReminderParentScreen.confirmationHold, () {
      if (mounted) unawaited(AfterBrushHome.go(context));
    });
  }

  Future<void> _notNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ReminderService().noteOfferResult(ReminderOfferResult.notNow);
    if (!mounted) return;
    unawaited(AfterBrushHome.go(context));
  }

  @override
  Widget build(BuildContext context) {
    final wanted = _wanted;
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: wanted == null
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ForGrownUps(),
                      const SizedBox(height: 24),
                      const _MoonAndBrush(),
                      const SizedBox(height: 20),
                      const Text(
                        'Want a bedtime brushing reminder?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "One reminder on this phone each evening, only if "
                        "brushing hasn't happened yet. It stays on this "
                        'device; nothing is sent to us.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Remind me at', style: _labelStyle),
                          ),
                          ReminderTimeDropdown(
                            key: const ValueKey('parent_evening_time'),
                            value: wanted.evening,
                            choices: eveningReminderChoices,
                            onChanged: _busy
                                ? null
                                : (time) =>
                                      _change(wanted.copyWith(evening: time)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            key: const ValueKey('parent_morning_check'),
                            value: wanted.morningOn,
                            activeColor: const Color(0xFF00E5FF),
                            onChanged: _busy
                                ? null
                                : (on) => _change(
                                    wanted.copyWith(morningOn: on ?? false),
                                  ),
                          ),
                          const Expanded(
                            child: Text(
                              'Morning reminder too',
                              style: _labelStyle,
                            ),
                          ),
                          ReminderTimeDropdown(
                            key: const ValueKey('parent_morning_time'),
                            value: wanted.morning,
                            choices: morningReminderChoices,
                            onChanged: _busy || !wanted.morningOn
                                ? null
                                : (time) =>
                                      _change(wanted.copyWith(morning: time)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (_confirmation case final confirmation?)
                        _Confirmation(text: confirmation)
                      else ...[
                        _TurnOnButton(onPressed: _busy ? null : _turnOn),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const ValueKey('parent_not_now'),
                          onPressed: _busy ? null : _notNow,
                          child: const Text(
                            'Not now',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Change or turn off anytime: Parents > Settings > '
                        'Reminders',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(color: Colors.white, fontSize: 16);

class _ForGrownUps extends StatelessWidget {
  const _ForGrownUps();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.lock_rounded, color: Color(0xFFFFD54F), size: 18),
        SizedBox(width: 8),
        Text(
          'FOR GROWN-UPS',
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

/// A moon and a toothbrush: a bedtime brush.
class _MoonAndBrush extends StatelessWidget {
  const _MoonAndBrush();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bedtime_rounded, color: Color(0xFFFFD54F), size: 64),
        SizedBox(width: 12),
        ImageIcon(
          AssetImage('assets/images/icon_toothbrush.png'),
          color: Color(0xFF00E5FF),
          size: 56,
        ),
      ],
    );
  }
}

class _TurnOnButton extends StatelessWidget {
  const _TurnOnButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const ValueKey('parent_turn_on'),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'TURN ON',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('parent_confirmation'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF00E676),
          size: 32,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/widgets/reminder_time_dropdown_test.dart test/screens/reminder_parent_screen_test.dart`
Expected: PASS (4 and 10 tests).

- [ ] **Step 7: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/after_brush_home.dart lib/widgets/reminder_time_dropdown.dart lib/screens/reminder_parent_screen.dart test/widgets/reminder_time_dropdown_test.dart test/screens/reminder_parent_screen_test.dart
git commit -m "feat(reminder): the parent's reminder screen (Screen B)

What the reminder is, a time (30 min before the first brush, on the
quarter hour), an optional morning reminder; TURN ON asks the OS and
saves only if it allows, then confirms and goes Home; Not now is final.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 6: Screen A, the child's hand-off, and Buddy's line

**Files:**
- Add: `assets/audio/voices/buddy/voice_reminder_handoff.mp3` (from `.remember/v1.1/voice-staging/`; mp3, 22 050 Hz, mono, 64 kbps, 3.9 s)
- Modify: `lib/services/audio_service.dart` (a new list after `_brushFlowVoices`, which ends at line 564; and `_allPreloadFiles`, lines 568-577)
- Modify: `test/audio/audio_assets_test.dart` (a mirror list after `_brushFlowVoices`, which ends at line 290; and `_allAudioFiles`, lines 293-302)
- Create: `lib/screens/reminder_handoff_screen.dart`
- Create: `test/screens/reminder_handoff_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `ReminderOffer`, `ReminderOfferResult`. (Task 3): `ReminderService().noteOfferShown()` and `.noteOfferResult()`; the test helpers. (Task 4): `showParentGate`. (Task 5): `ReminderParentScreen`, `AfterBrushHome`.
- Produces (Task 7 relies on these):
  - `class ReminderHandoffScreen extends StatefulWidget` with `const ReminderHandoffScreen({super.key, required ReminderOffer offer})`, `static const voiceLine = 'voice_reminder_handoff.mp3'` and `static const idleTimeout = Duration(seconds: 15)`.
  - Keys: `handoff_picture`, `handoff_lock`, `handoff_skip`.

- [ ] **Step 1: Add the voice line**

```bash
cp .remember/v1.1/voice-staging/voice_reminder_handoff.mp3 assets/audio/voices/buddy/voice_reminder_handoff.mp3
afinfo assets/audio/voices/buddy/voice_reminder_handoff.mp3 | grep -E "Data format|estimated duration|bit rate"
```
Expected: `1 ch, 22050 Hz`, about `3.92 sec`, about `64000 bits per second`. The file is under `assets/`, which is committed; the staging copy under `.remember/` is never committed.

In `lib/services/audio_service.dart`, between the end of `_brushFlowVoices` (its `];`, line 564) and `/// Complete list of files to preload`, add:

```dart

  /// The parent bedtime reminder's hand-off (spec 2026-10-15 §3.1): "Great
  /// mission! Grown-ups, tap the lock for a bedtime reminder."
  static const _reminderVoices = ['voice_reminder_handoff.mp3'];
```

and in `_allPreloadFiles`, after `..._brushFlowVoices,`, add `..._reminderVoices,`.

In `test/audio/audio_assets_test.dart`, between the end of `const _brushFlowVoices = [...]` and `/// Complete preload list, matching AudioService._allPreloadFiles.`, add:

```dart

/// The bedtime reminder's hand-off line (mirrors AudioService._reminderVoices).
const _reminderVoices = ['voice_reminder_handoff.mp3'];
```

and in `_allAudioFiles`, after `..._brushFlowVoices,`, add `..._reminderVoices,`.

Run: `flutter test test/audio/audio_assets_test.dart`
Expected: PASS, including `voice_reminder_handoff.mp3 exists`.

- [ ] **Step 2: Write the failing screen tests**

Create `test/screens/reminder_handoff_screen_test.dart`:

```dart
// test/screens/reminder_handoff_screen_test.dart
import 'dart:async';

import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_handoff_screen.dart';
import 'package:brush_quest/screens/reminder_parent_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/timed_fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// Screen A of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.1): no
/// words, Buddy's line once, the lock into the GROWN-UP CHECK, and Home after
/// the arrow, the back gesture or 15 s without a touch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late TimedFakeAudioService audio;

  setUpAll(() {
    // tearDown's `testInstance = null` builds a real AudioService, whose
    // players talk to the audioplayers channels.
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    ReminderOffer offer = ReminderOffer.first,
    Size size = const Size(430, 932),
  }) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 1,
      'selected_hero': 'frost',
      'unlocked_heroes': ['blaze', 'frost'],
      'muted': false,
    });
    audio = TimedFakeAudioService(
      lengths: const {
        ReminderHandoffScreen.voiceLine: Duration(milliseconds: 3900),
      },
    );
    final start = tester.binding.clock.now();
    audio.clock = () => tester.binding.clock.now().difference(start);
    AudioService.testInstance = audio;
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 20),
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ReminderHandoffScreen(offer: offer)),
    );
    await tester.pump();
  }

  /// Lets Buddy's line end, then drops the screen. A Timer still pending at
  /// the end of a test fails it, so this also checks that dispose cancels
  /// the 15 s.
  Future<void> leave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> openLock(WidgetTester tester) async {
    await tester.tap(key('handoff_lock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Answers the open GROWN-UP CHECK and taps CONTINUE.
  Future<void> passGate(WidgetTester tester) async {
    final text = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(text)!;
    final answer = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    await tester.enterText(find.byType(TextField), '$answer');
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> fadeHome(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets("Buddy's line, once; not one word on screen", (tester) async {
    await pumpScreen(tester);
    expect(audio.playedVoiceLines, [ReminderHandoffScreen.voiceLine]);
    expect(find.byType(Text), findsNothing);
    expect(key('handoff_picture'), findsOneWidget);
    expect(key('handoff_lock'), findsOneWidget);
    expect(key('handoff_skip'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('notes the offer: its number, today, the shown event', (
    tester,
  ) async {
    await pumpScreen(tester, offer: ReminderOffer.second);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ReminderService.keyOfferCount), 2);
    expect(prefs.getString(ReminderService.keyOfferLastDate), '2026-10-15');
    expect(recorder.named('reminder_offer_shown'), [
      {'name': 'reminder_offer_shown', 'offer': '2'},
    ]);
    await leave(tester);
  });

  testWidgets('the arrow: Buddy stops, Home as usual, offer 2 stays possible', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(key('handoff_skip'));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(audio.voiceNamed(ReminderHandoffScreen.voiceLine)!.cut, isTrue);
    expect(results(), ['skipped']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ReminderService.keyDecided), isFalse);
  });

  testWidgets('15 s without a tap: Home', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 14900));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['timeout']);
  });

  testWidgets('a touch anywhere starts the 15 s again', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.tapAt(const Offset(20, 120)); // the background, no button
    await tester.pump(const Duration(milliseconds: 14800));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the back button goes Home, never out of the app', (
    tester,
  ) async {
    await pumpScreen(tester);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['skipped']);
  });

  testWidgets('the lock: Buddy stops, the GROWN-UP CHECK, then the parent '
      'screen; no timeout behind it', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 1));
    await openLock(tester);
    expect(audio.voiceNamed(ReminderHandoffScreen.voiceLine)!.cut, isTrue);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(results(), ['gate_opened']);
    await passGate(tester);
    expect(find.byType(ReminderParentScreen), findsOneWidget);
    expect(find.text('Want a bedtime brushing reminder?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('HOME'), findsNothing);
    expect(results(), ['gate_opened']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CANCEL on the check: back here, and the 15 s start again', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 12));
    await openLock(tester);
    // A grown-up working out the sum: nothing times out behind the check.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(key('handoff_lock'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 14500));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['gate_opened', 'timeout']);
  });

  testWidgets('backing out of the parent screen comes back here', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLock(tester);
    await passGate(tester);
    expect(find.byType(ReminderParentScreen), findsOneWidget);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pump();
    // The page's exit transition outlasts 400 ms on the test's Android theme.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ReminderParentScreen), findsNothing);
    expect(key('handoff_lock'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 14500));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: it all fits, '
        'the arrow big enough for small fingers', (tester) async {
      await pumpScreen(tester, size: size);
      expect(tester.takeException(), isNull);
      final lock = tester.getRect(key('handoff_lock'));
      final skip = tester.getRect(key('handoff_skip'));
      expect(lock.bottom, lessThanOrEqualTo(size.height));
      expect(skip.bottom, lessThanOrEqualTo(size.height));
      expect(skip.width, greaterThanOrEqualTo(48));
      expect(lock.overlaps(skip), isFalse);
      await leave(tester);
    });
  }

  testWidgets('leaving the screen leaves no timer behind', (tester) async {
    await pumpScreen(tester);
    await leave(tester);
  });
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `flutter test test/screens/reminder_handoff_screen_test.dart`
Expected: FAIL to compile, because `reminder_handoff_screen.dart` doesn't exist.

- [ ] **Step 4: Create `lib/screens/reminder_handoff_screen.dart`**

```dart
// lib/screens/reminder_handoff_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../services/hero_service.dart';
import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import '../services/weapon_service.dart';
import '../widgets/parent_gate_dialog.dart';
import '../widgets/space_background.dart';
import 'after_brush_home.dart';
import 'reminder_parent_screen.dart';

/// Screen A of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.1):
/// between the victory screen and Home, once or twice ever. For the child,
/// who can't read: a picture (his hero, an arrow, a grown-up with a phone)
/// and Buddy's line. The lock opens the GROWN-UP CHECK, then the parent's
/// screen. The arrow, the back gesture, or [idleTimeout] without a touch go
/// Home as usual. Home itself is not changed.
class ReminderHandoffScreen extends StatefulWidget {
  const ReminderHandoffScreen({super.key, required this.offer});

  /// The first, or the second and last, time it is shown.
  final ReminderOffer offer;

  /// "Great mission! Grown-ups, tap the lock for a bedtime reminder."
  static const voiceLine = 'voice_reminder_handoff.mp3';

  /// This long without a touch: Home.
  static const idleTimeout = Duration(seconds: 15);

  @override
  State<ReminderHandoffScreen> createState() => _ReminderHandoffScreenState();
}

class _ReminderHandoffScreenState extends State<ReminderHandoffScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  /// The 15 s without a touch. Stopped while the gate or the parent's screen
  /// is up; cancelled in dispose.
  Timer? _idleTimer;
  bool _gateOpen = false;
  bool _leaving = false;
  String _heroId = 'blaze';
  int _stage = 1;
  String _weaponId = 'star_blaster';

  @override
  void initState() {
    super.initState();
    unawaited(_loadHero());
    unawaited(ReminderService().noteOfferShown(widget.offer));
    unawaited(AudioService().playVoice(ReminderHandoffScreen.voiceLine));
    _restartIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadHero() async {
    final heroes = HeroService();
    final hero = await heroes.getSelectedHero();
    final stage = await heroes.getEvolutionStage(hero.id);
    final weaponId = await WeaponService().getSelectedWeaponId();
    if (!mounted) return;
    setState(() {
      _heroId = hero.id;
      _stage = stage;
      _weaponId = weaponId;
    });
  }

  /// Any touch starts the 15 s again ("15 s with no tap", spec §3.1).
  void _restartIdle() {
    _idleTimer?.cancel();
    if (_gateOpen || _leaving) return;
    _idleTimer = Timer(
      ReminderHandoffScreen.idleTimeout,
      () => unawaited(_leave(ReminderOfferResult.timeout)),
    );
  }

  /// Home as usual: the arrow, the back gesture, or the 15 s.
  Future<void> _leave(ReminderOfferResult result) async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _idleTimer?.cancel();
    unawaited(ReminderService().noteOfferResult(result));
    await AudioService().stopVoice();
    if (!mounted) return;
    unawaited(AfterBrushHome.go(context));
  }

  /// The lock: the GROWN-UP CHECK, then the parent's screen. Cancelling the
  /// check, or backing out of that screen, comes back here.
  Future<void> _openLock() async {
    if (_gateOpen || _leaving) return;
    _gateOpen = true;
    _idleTimer?.cancel();
    unawaited(HapticFeedback.lightImpact());
    unawaited(AudioService().stopVoice());
    unawaited(
      ReminderService().noteOfferResult(ReminderOfferResult.gateOpened),
    );
    final passed = await showParentGate(context);
    if (!mounted) return;
    if (passed ?? false) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderParentScreen()),
      );
    }
    if (!mounted) return;
    _gateOpen = false;
    _restartIdle();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave(ReminderOfferResult.skipped));
      },
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _restartIdle(),
          child: SpaceBackground(
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  _HandOffPicture(
                    heroId: _heroId,
                    stage: _stage,
                    weaponId: _weaponId,
                  ),
                  const Spacer(),
                  _LockButton(pulse: _pulse, onTap: _openLock),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                      child: _SkipArrow(
                        onTap: () =>
                            unawaited(_leave(ReminderOfferResult.skipped)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// His hero, an arrow, a grown-up holding a phone: "give the phone to a
/// grown-up". Not a button.
class _HandOffPicture extends StatelessWidget {
  const _HandOffPicture({
    required this.heroId,
    required this.stage,
    required this.weaponId,
  });

  final String heroId;
  final int stage;
  final String weaponId;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('handoff_picture'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HeroService.buildHeroImage(
          heroId,
          stage: stage,
          weaponId: weaponId,
          size: 120,
        ),
        Icon(
          Icons.trending_flat_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 56,
        ),
        const SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.person_rounded, color: Colors.white, size: 110),
              Positioned(
                right: 4,
                bottom: 10,
                child: Icon(
                  Icons.smartphone_rounded,
                  color: Color(0xFF00E5FF),
                  size: 44,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The big gold lock the grown-up taps, gently pulsing.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.pulse, required this.onTap});

  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) =>
          Transform.scale(scale: 1 + pulse.value * 0.06, child: child),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('handoff_lock'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 76,
            ),
          ),
        ),
      ),
    );
  }
}

/// The skip arrow, 72 px: Home as usual.
class _SkipArrow extends StatelessWidget {
  const _SkipArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: InkWell(
        key: const ValueKey('handoff_skip'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/screens/reminder_handoff_screen_test.dart test/audio/audio_assets_test.dart`
Expected: all PASS. If a timing assertion misses by one frame, check that test's arithmetic before touching the screen: the timings are the spec's.

- [ ] **Step 6: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 7: Commit**

```bash
git add assets/audio/voices/buddy/voice_reminder_handoff.mp3 lib/services/audio_service.dart test/audio/audio_assets_test.dart lib/screens/reminder_handoff_screen.dart test/screens/reminder_handoff_screen_test.dart
git commit -m "feat(reminder): the child's hand-off screen (Screen A)

No words: his hero, an arrow, a grown-up with a phone, and Buddy's
'Great mission! Grown-ups, tap the lock for a bedtime reminder.' The
lock opens the GROWN-UP CHECK, then the parent's screen; the arrow,
the back gesture or 15 s without a touch go Home as usual.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 7: The wiring: DONE, every brush, start, resume and pause

**Files:**
- Modify: `lib/screens/victory_screen.dart`: imports (line 26, `import 'home_screen.dart';`); after the `recordBrush(...)` call (lines 514-517); the end of `_goHome()` (lines 1465-1479)
- Modify: `lib/main.dart`: an import (after line 19); `main()` (after line 58); `didChangeAppLifecycleState` (lines 89-109)
- Create: `test/flows/reminder_offer_flow_test.dart`
- Create: `test/screens/victory_reminder_offer_test.dart`

If Part A or Part B of the rework has changed these spots since commit 8f6872d, keep their new code. Make only the three changes below: replan after `recordBrush`, ask `offerDue()` before Home, and push the hand-off when it answers.

**Interfaces:**
- Consumes (Task 3): `ReminderService().init()`, `.reschedule()`, `.offerDue()`, `.onAppResumed()`, `.onAppPaused()`. (Task 5): `AfterBrushHome`. (Task 6): `ReminderHandoffScreen`.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing structural test**

Create `test/flows/reminder_offer_flow_test.dart`:

```dart
// test/flows/reminder_offer_flow_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's parent gate, in the camera-flow pattern
/// (camera_mode_flow_test.dart; memory decision_camera_parent_gate.md): the
/// GROWN-UP CHECK, then the parent's own explanation (Screen B), then the OS
/// prompt, then the reminder saved only if the OS allows it. Behaviour is
/// pinned by reminder_handoff_screen_test, reminder_parent_screen_test and
/// reminder_service_test; this pins the order in the code and the wiring.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// The text of [source] from [from] up to the next [to].
  String section(String source, String from, String to) {
    final start = source.indexOf(from);
    expect(start, isNonNegative, reason: from);
    final end = source.indexOf(to, start + from.length);
    expect(end, isNonNegative, reason: to);
    return source.substring(start, end);
  }

  test('the hand-off reaches the reminder screen only through the GROWN-UP '
      'CHECK', () {
    final handoff = read('lib/screens/reminder_handoff_screen.dart');
    final lock = section(handoff, 'Future<void> _openLock()', 'Widget build(');
    final gate = lock.indexOf('showParentGate(context)');
    final passed = lock.indexOf('if (passed ?? false)');
    final screen = lock.indexOf('ReminderParentScreen()');
    expect(gate, isNonNegative);
    expect(passed, greaterThan(gate));
    expect(screen, greaterThan(passed));
    expect(
      'ReminderParentScreen('.allMatches(handoff),
      hasLength(1),
      reason: 'no other way into the reminder screen',
    );
  });

  test(
    'TURN ON asks the OS first; the reminder is saved only if it allows',
    () {
      final service = read('lib/services/reminder_service.dart');
      final turnOn = section(
        service,
        'Future<bool> turnOn(',
        'Future<void> saveSettings(',
      );
      final ask = turnOn.indexOf('requestPermission');
      final guard = turnOn.indexOf('if (!granted) return false;');
      final save = turnOn.indexOf('_writeSettings(');
      expect(ask, isNonNegative);
      expect(guard, greaterThan(ask));
      expect(save, greaterThan(guard));
      final saveSettings = section(
        service,
        'Future<void> saveSettings(',
        'Future<ReminderOffer?> offerDue(',
      );
      expect(saveSettings, contains('changed.eveningOn && current.eveningOn'));
      expect(saveSettings, contains('changed.morningOn && current.morningOn'));
      final parent = read('lib/screens/reminder_parent_screen.dart');
      expect(parent, contains('ReminderService().turnOn('));
      expect(parent, isNot(contains('saveSettings(')));
    },
  );

  test('nothing else asks for notification permission', () {
    final askers = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('requestPermission'))
          f.path,
    ]..sort();
    expect(askers, [
      'lib/services/reminder_platform.dart',
      'lib/services/reminder_service.dart',
    ]);
    final service = read('lib/services/reminder_service.dart');
    expect(
      'requestPermission'.allMatches(service),
      hasLength(1),
      reason: 'only turnOn asks',
    );
  });

  test('main sets reminders up and follows the app in and out', () {
    final main = read('lib/main.dart');
    expect(main, contains('unawaited(ReminderService().init());'));
    final paused = section(
      main,
      'if (state == AppLifecycleState.paused)',
      '} else if (state == AppLifecycleState.inactive',
    );
    expect(paused, contains('ReminderService().onAppPaused()'));
    final resumed = section(
      main,
      '} else if (state == AppLifecycleState.resumed)',
      'Widget build(',
    );
    expect(resumed, contains('ReminderService().onAppResumed()'));
  });

  test('the victory screen: every brush replans; DONE offers before Home', () {
    final victory = read('lib/screens/victory_screen.dart');
    final record = victory.indexOf('_streakService.recordBrush(');
    final replan = victory.indexOf('ReminderService().reschedule()');
    expect(record, isNonNegative);
    expect(replan, greaterThan(record));
    final goHome = section(
      victory,
      'Future<void> _goHome() async {',
      'Widget build(BuildContext context)',
    );
    expect(
      goHome.indexOf('ReminderService().offerDue()'),
      greaterThan(goHome.lastIndexOf('stopVoice()')),
    );
    expect(goHome, contains('ReminderHandoffScreen(offer: offer)'));
    expect(goHome, contains('AfterBrushHome.route()'));
  });

  test('Home is not changed', () {
    final home = read('lib/screens/home_screen.dart');
    expect(home, isNot(contains('Reminder')));
  });
}
```

- [ ] **Step 2: Write the failing victory test**

Create `test/screens/victory_reminder_offer_test.dart`:

```dart
// test/screens/victory_reminder_offer_test.dart
import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_handoff_screen.dart';
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// DONE on the victory screen: when an offer is due, the bedtime-reminder
/// hand-off comes before Home (spec 2026-10-15-bedtime-reminder-design §2),
/// and every recorded brush plans the reminders again (§5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() {
    AudioService.testInstance = FakeAudioService();
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
    StreakService.isPurchasing = false;
  });

  Map<String, Object> kid({
    required int brushesBefore,
    Map<String, Object> extra = const {},
  }) => {
    'total_brushes': brushesBefore,
    'selected_hero': 'blaze',
    'selected_weapon': 'star_blaster',
    'unlocked_heroes': ['blaze'],
    'unlocked_weapons': ['star_blaster'],
    'current_world': 'candy_crater',
    'collected_cards': <String>[],
    'trophy_captured': <String>[],
    'muted': false,
    ...extra,
  };

  Future<void> pumpVictory(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
      ),
    );
    await tester.pump();
  }

  /// Waits for the 60 s safety DONE (no chest tap needed), taps it, and runs
  /// until the victory screen has gone.
  Future<void> finishWithDone(WidgetTester tester) async {
    await pumpVictory(tester);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('DONE'), findsOneWidget);
    await tester.tap(find.text('DONE'), warnIfMissed: false);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(VictoryScreen).evaluate().isEmpty) break;
    }
    expect(find.byType(VictoryScreen), findsNothing);
  }

  /// Lets the popups' and the hand-off's timers run out, then drops the tree.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  ReminderOffer? offerShown(WidgetTester tester) {
    final handoff = find.byType(ReminderHandoffScreen);
    if (handoff.evaluate().isEmpty) return null;
    return tester.widget<ReminderHandoffScreen>(handoff).offer;
  }

  testWidgets('the first brush ever: DONE opens the hand-off, offer 1', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(kid(brushesBefore: 0));
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(offerShown(tester), ReminderOffer.first);
    expect(find.text('HOME'), findsNothing);
    await drain(tester);
  });

  testWidgets('offer 2: from the 3rd brush, on a later day than offer 1', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues(
      kid(
        brushesBefore: 2,
        extra: {
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: StreakService.dateKey(yesterday),
        },
      ),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(offerShown(tester), ReminderOffer.second);
    await drain(tester);
  });

  testWidgets('once the parent decided, DONE goes straight Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      kid(brushesBefore: 4, extra: {ReminderService.keyDecided: true}),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(ReminderHandoffScreen), findsNothing);
    await drain(tester);
  });

  testWidgets('with a reminder on, DONE goes straight Home', (tester) async {
    SharedPreferences.setMockInitialValues(
      kid(
        brushesBefore: 4,
        extra: {
          ReminderService.keyEveningEnabled: true,
          ReminderService.keyEveningTime: 19 * 60 + 30,
        },
      ),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(find.text('HOME'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('every recorded brush plans the reminders again', (tester) async {
    SharedPreferences.setMockInitialValues(
      kid(brushesBefore: 4, extra: {ReminderService.keyDecided: true}),
    );
    await installReminderService(platform: platform, recorder: recorder);
    final plansBefore = platform.calls.where((c) => c == 'pendingIds').length;
    await pumpVictory(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(
      platform.calls.where((c) => c == 'pendingIds').length,
      greaterThan(plansBefore),
    );
    await tester.pump(const Duration(seconds: 61));
    await drain(tester);
  });
}
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `flutter test test/flows/reminder_offer_flow_test.dart test/screens/victory_reminder_offer_test.dart`
Expected:
- The flow test fails on main.dart and the victory screen. Its gate, TURN ON, "nothing else asks" and Home tests already pass.
- In the victory test, the two offer tests and the replan test fail: DONE still goes straight Home, and nothing replans after the brush. The two "straight Home" tests already pass.

- [ ] **Step 4: The victory screen**

In `lib/screens/victory_screen.dart`:

1. Replace `import 'home_screen.dart';` (line 26) with:

```dart
import '../services/reminder_service.dart';
import 'after_brush_home.dart';
import 'reminder_handoff_screen.dart';
```

(`HomeScreen` is now reached only through `AfterBrushHome`.)

2. Right after the `recordBrush` call (the statement that starts `final outcome = await _streakService.recordBrush(`, lines 514-517), add:

```dart
    // The brush cancels today's reminder for its slot, and the week is
    // planned again (bedtime reminder spec §5).
    unawaited(ReminderService().reschedule());
```

3. In `_goHome()`, replace the end of the method, from `    await AudioService().stopVoice();` (line 1465) to its closing `  }`, with:

```dart
    await AudioService().stopVoice();
    // Once or twice ever, the bedtime-reminder hand-off comes between this
    // screen and Home: after the closing line, before Home (bedtime reminder
    // spec §2).
    final offer = await ReminderService().offerDue();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushAndRemoveUntil(
        offer == null
            ? AfterBrushHome.route()
            : AfterBrushHome.fadeTo((_) => ReminderHandoffScreen(offer: offer)),
        (route) => false,
      ),
    );
  }
```

The two victory tests that tap DONE (`victory_goal_test.dart`: "the closing line once …" and "a sequence that fails before the closing beat …") now push the hand-off, because their saves have no reminder state. They only check that a route was pushed and which closing lines played, so they still pass.

- [ ] **Step 5: `main.dart`**

1. After `import 'services/audio_service.dart';` add `import 'services/reminder_service.dart';`.
2. In `main()`, after `await StreakService.migrateToWalletEconomy();` (line 58), add:

```dart

  // The parent bedtime reminder: sets the plugin up (it never asks for a
  // permission here) and plans the week. Not awaited: a slow or failing
  // plugin must not hold up or break the start.
  unawaited(ReminderService().init());
```

3. Replace `didChangeAppLifecycleState` (lines 89-109) with:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AudioService.traceEnabled) AudioService.trace('[AUD] app $state');
    if (state == AppLifecycleState.paused) {
      // Backgrounded on both platforms — kill all audio, snapshotting the
      // current track so resume can restore it.
      AudioService().stopAllAudioForLifecycle();
      // The app was left: today's bedtime reminder is planned again.
      unawaited(ReminderService().onAppPaused());
    } else if (state == AppLifecycleState.inactive && !Platform.isIOS) {
      // Android: 'inactive' precedes paused. Kill audio.
      // iOS: 'inactive' is transient (Control Center pull, notification banner,
      // system alert, brief overlays). Killing audio here + stopAllAudio's
      // _musicPlaying=false made audio appear permanently dead after every
      // minor interruption. AVAudioSession interruption recovery in
      // AppDelegate.swift handles real iOS interruptions (calls, Siri).
      AudioService().stopAllAudioForLifecycle();
    } else if (state == AppLifecycleState.resumed) {
      // Screens don't rebuild on resume, so without this the music that was
      // playing before the phone slept never comes back (Jim's v24 feedback).
      AudioService().resumeAfterWake();
      // Back in the app: no reminder shows today while it is open (bedtime
      // reminder spec §4), and the week is planned again from now.
      unawaited(ReminderService().onAppResumed());
    }
  }
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/flows/reminder_offer_flow_test.dart test/screens/victory_reminder_offer_test.dart test/screens/victory_goal_test.dart test/screens/victory_screen_test.dart test/screens/victory_flame_test.dart`
Expected: all PASS.

- [ ] **Step 7: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/victory_screen.dart lib/main.dart test/flows/reminder_offer_flow_test.dart test/screens/victory_reminder_offer_test.dart
git commit -m "feat(reminder): DONE offers the reminder hand-off; every brush replans

After the first finished brush (and once more from the 3rd, on a later
day) DONE goes to the hand-off before Home. Every recorded brush, app
start, resume and pause plans the week again; nothing asks for a
permission at start-up.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 8: The Parent Zone: the REMINDERS card, the Pause, Start fresh, the Guide

**Files:**
- Create: `lib/widgets/reminder_settings_card.dart`
- Modify: `lib/screens/settings_screen.dart`:
  - imports (after lines 13 and 14)
  - the Pause switch (lines 1562-1576)
  - `_resetProgress()` (before `// Also delete cloud data if signed in`, line 1210)
  - `_buildSettingsTab()` (before `// ── OTHER`, line 1882)
  - `_buildGuideTab()` (before its closing `const SizedBox(height: 32)`, line 2116)
- Create: `test/widgets/reminder_settings_card_test.dart`
- Create: `test/screens/settings_reminders_test.dart`
- Modify: `test/screens/settings_copy_test.dart` (a constant after `_starsAndShopBody`, and a test in `group('Parent Guide tab', ...)`)

If Part B has rewritten parts of the Guide by now, add the new section at the end of the Guide list all the same, and leave Part B's sections as they are.

**Interfaces:**
- Consumes (Task 1): `ReminderSlot`, `ReminderSettings`, the choices. (Task 3): `ReminderService().settings()`, `.notificationsAllowed()`, `.turnOn()`, `.saveSettings()`, `.noteParentZoneOffer()`, `.openPhoneSettings()`, `.reschedule()`, `.resetAll()`. (Task 5): `ReminderTimeDropdown`.
- Produces:
  - `class ReminderSettingsCard extends StatefulWidget` with `const ReminderSettingsCard({super.key, VoidCallback? onInteraction})`.
  - Keys: `reminder_evening_switch`, `reminder_morning_switch`, `reminder_evening_time`, `reminder_morning_time`, `reminder_blocked`, `reminder_open_settings`.

- [ ] **Step 1: Write the failing card tests**

Create `test/widgets/reminder_settings_card_test.dart`:

```dart
// test/widgets/reminder_settings_card_test.dart
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/widgets/reminder_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_fakes.dart';

/// The Parent Zone's REMINDERS card (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3). The
/// app is open while it shows, so today's reminder waits: the plans below
/// start tomorrow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late int touches;

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    touches = 0;
  });

  tearDown(() {
    ReminderService.testInstance = null;
  });

  const eveningOn = <String, Object>{
    ReminderService.keyEveningEnabled: true,
    ReminderService.keyEveningTime: 19 * 60 + 30,
  };

  Finder key(String name) => find.byKey(ValueKey(name));
  bool switchOn(WidgetTester tester, String name) =>
      tester.widget<Switch>(key(name)).value;
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  Future<void> pumpCard(
    WidgetTester tester, [
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 9),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReminderSettingsCard(onInteraction: () => touches++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off: both switches off, no time, no note, the OS not asked', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Bedtime reminder'), findsOneWidget);
    expect(find.text('Morning reminder'), findsOneWidget);
    expect(
      find.text("Only if that brush hasn't happened yet. Stays on this phone."),
      findsOneWidget,
    );
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(switchOn(tester, 'reminder_morning_switch'), isFalse);
    expect(key('reminder_evening_time'), findsNothing);
    expect(key('reminder_blocked'), findsNothing);
    expect(platform.calls, isNot(contains('notificationsAllowed')));
  });

  testWidgets('the bedtime switch on: the OS asked, then on, timed and '
      'planned', (tester) async {
    await pumpCard(tester);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(platform.permissionRequests, 1);
    expect(switchOn(tester, 'reminder_evening_switch'), isTrue);
    expect(find.text('7:30 PM'), findsOneWidget);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19, 30));
    expect(recorder.named('reminder_offer_shown'), [
      {'name': 'reminder_offer_shown', 'offer': 'parent_zone'},
    ]);
    expect(results(), ['enabled']);
    expect(touches, 1);
  });

  testWidgets('the OS refuses: still off, the note, and Open phone settings '
      'opens them', (tester) async {
    platform.grant = false;
    await pumpCard(tester);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(
      find.text(
        'Notifications for Brush Quest are off in your phone settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open phone settings'));
    await tester.pump();
    expect(platform.openSettingsCalls, 1);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getBool(ReminderService.keyEveningEnabled), isNot(isTrue));
    expect(results(), ['os_denied']);
  });

  testWidgets('on, but off in the phone: the card says so as it opens', (
    tester,
  ) async {
    await pumpCard(tester, eveningOn);
    expect(switchOn(tester, 'reminder_evening_switch'), isTrue);
    expect(key('reminder_blocked'), findsOneWidget);
  });

  testWidgets("back from the phone's settings with notifications allowed: "
      'the note goes', (tester) async {
    await pumpCard(tester, eveningOn);
    expect(key('reminder_blocked'), findsOneWidget);
    await tester.tap(key('reminder_open_settings'));
    await tester.pump();
    platform.allowed = true; // the parent allowed them there
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(key('reminder_blocked'), findsNothing);
  });

  testWidgets('turning it off cancels the waiting reminders and asks nothing', (
    tester,
  ) async {
    platform.allowed = true;
    await pumpCard(tester, eveningOn);
    expect(platform.pending, isNotEmpty);
    await tester.tap(key('reminder_evening_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(platform.pending, isEmpty);
    expect(platform.permissionRequests, 0);
  });

  testWidgets('a new time is saved and planned', (tester) async {
    platform.allowed = true;
    await pumpCard(tester, eveningOn);
    // Which times an open menu shows depends on where the card sits on the
    // screen; the menu itself is ReminderTimeDropdown's own test. Pick as the
    // menu does.
    final list = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: key('reminder_evening_time'),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    list.onChanged!(19 * 60);
    await tester.pumpAndSettle();
    final saved = await SharedPreferences.getInstance();
    expect(saved.getInt(ReminderService.keyEveningTime), 19 * 60);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 19));
    expect(touches, 1);
  });

  testWidgets('a saved time that is not on the list still shows', (
    tester,
  ) async {
    platform.allowed = true;
    await pumpCard(tester, {
      ReminderService.keyEveningEnabled: true,
      ReminderService.keyEveningTime: 18 * 60 + 10,
    });
    expect(find.text('6:10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the morning reminder: its own switch, at 7:00 AM', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.tap(key('reminder_morning_switch'));
    await tester.pumpAndSettle();
    expect(switchOn(tester, 'reminder_morning_switch'), isTrue);
    expect(switchOn(tester, 'reminder_evening_switch'), isFalse);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(platform.pendingTimes.first, DateTime(2026, 10, 16, 7));
  });

  testWidgets('360 px wide, the largest text: nothing overflows', (
    tester,
  ) async {
    platform.allowed = true;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      ...eveningOn,
      ReminderService.keyMorningEnabled: true,
      ReminderService.keyMorningTime: 7 * 60,
    });
    await installReminderService(platform: platform, recorder: recorder);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ReminderSettingsCard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/widgets/reminder_settings_card_test.dart`
Expected: FAIL to compile, because `reminder_settings_card.dart` doesn't exist.

- [ ] **Step 3: Create `lib/widgets/reminder_settings_card.dart`**

```dart
// lib/widgets/reminder_settings_card.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import 'reminder_time_dropdown.dart';

/// The REMINDERS card of Parents > Settings (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3): the
/// bedtime reminder and the morning one, each with its time. Turning one on
/// asks the OS first (the Parent Zone is behind the parent gate). If the OS
/// has notifications off, the card says so and offers the phone's settings,
/// a link out allowed only here. [onInteraction] keeps the Parent Zone
/// unlocked.
class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({super.key, this.onInteraction});

  final VoidCallback? onInteraction;

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard>
    with WidgetsBindingObserver {
  ReminderSettings? _settings;
  bool _blocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings (or anywhere): what the OS allows may
  /// have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  Future<void> _load() async {
    final service = ReminderService();
    final settings = await service.settings();
    final blocked = settings.anyOn && !await service.notificationsAllowed();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _blocked = blocked;
    });
  }

  /// A switch: on asks the OS through [ReminderService.turnOn]; off saves.
  Future<void> _switch(ReminderSlot slot, {required bool on}) async {
    final current = _settings;
    if (current == null || _busy) return;
    widget.onInteraction?.call();
    final wanted = slot == ReminderSlot.evening
        ? current.copyWith(eveningOn: on)
        : current.copyWith(morningOn: on);
    setState(() => _busy = true);
    final service = ReminderService();
    var saved = wanted;
    var refused = false;
    if (on) {
      service.noteParentZoneOffer();
      if (!await service.turnOn(wanted)) {
        saved = current;
        refused = true;
      }
    } else {
      await service.saveSettings(wanted);
    }
    final blocked =
        refused || (saved.anyOn && !await service.notificationsAllowed());
    if (!mounted) return;
    setState(() {
      _settings = saved;
      _blocked = blocked;
      _busy = false;
    });
  }

  Future<void> _time(ReminderSlot slot, ReminderTime time) async {
    final current = _settings;
    if (current == null || _busy) return;
    widget.onInteraction?.call();
    final changed = slot == ReminderSlot.evening
        ? current.copyWith(evening: time)
        : current.copyWith(morning: time);
    setState(() => _settings = changed);
    await ReminderService().saveSettings(changed);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox(height: 120);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final slot in ReminderSlot.values) ...[
            if (slot != ReminderSlot.values.first)
              const Divider(color: Colors.white12, height: 20),
            _ReminderRow(
              slot: slot,
              on: slot == ReminderSlot.evening
                  ? settings.eveningOn
                  : settings.morningOn,
              time: slot == ReminderSlot.evening
                  ? settings.evening
                  : settings.morning,
              enabled: !_busy,
              onSwitch: (on) => unawaited(_switch(slot, on: on)),
              onTime: (time) => unawaited(_time(slot, time)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "Only if that brush hasn't happened yet. Stays on this phone.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          if (_blocked) ...[
            const SizedBox(height: 12),
            _BlockedNote(
              onOpen: () {
                widget.onInteraction?.call();
                unawaited(ReminderService().openPhoneSettings());
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One reminder: its switch, and its time while it is on.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.slot,
    required this.on,
    required this.time,
    required this.enabled,
    required this.onSwitch,
    required this.onTime,
  });

  final ReminderSlot slot;
  final bool on;
  final ReminderTime time;
  final bool enabled;
  final ValueChanged<bool> onSwitch;
  final ValueChanged<ReminderTime> onTime;

  @override
  Widget build(BuildContext context) {
    final evening = slot == ReminderSlot.evening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              evening ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
              color: Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                evening ? 'Bedtime reminder' : 'Morning reminder',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              key: ValueKey('reminder_${slot.name}_switch'),
              value: on,
              onChanged: enabled ? onSwitch : null,
              activeThumbColor: const Color(0xFFFFD54F),
            ),
          ],
        ),
        if (on)
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: ReminderTimeDropdown(
              key: ValueKey('reminder_${slot.name}_time'),
              value: time,
              choices: evening
                  ? eveningReminderChoices
                  : morningReminderChoices,
              onChanged: enabled ? onTime : null,
            ),
          ),
      ],
    );
  }
}

/// Notifications are off in the phone: say so, and offer its settings.
class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('reminder_blocked'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications for Brush Quest are off in your phone settings.',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('reminder_open_settings'),
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open phone settings'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00E5FF),
            side: const BorderSide(color: Color(0xFF00E5FF)),
          ),
        ),
      ],
    );
  }
}
```

Run: `flutter test test/widgets/reminder_settings_card_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 4: Write the failing Settings tests**

Create `test/screens/settings_reminders_test.dart`:

```dart
// test/screens/settings_reminders_test.dart
import 'dart:io';

import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/widgets/reminder_settings_card.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// Parents > Settings > Reminders (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3, §4):
/// where the card sits, and what the Pause and Start fresh do to reminders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
  });

  setUp(() {
    AudioService.testInstance = FakeAudioService();
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
  });

  testWidgets('the REMINDERS card sits between BRUSHING and OTHER', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await installReminderService(
      platform: FakeReminderPlatform(),
      recorder: RecordingAnalytics(),
    );
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The Parent Check.
    final challenge = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge)!;
    await tester.enterText(
      find.byType(TextField),
      '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The card reads its settings once its tab is built.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('REMINDERS'), findsOneWidget);
    expect(find.byType(ReminderSettingsCard), findsOneWidget);
    expect(find.text('Bedtime reminder'), findsOneWidget);
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('REMINDERS'), greaterThan(top('BRUSHING')));
    expect(top('REMINDERS'), lessThan(top('OTHER')));
  });

  test('the Pause plans the reminders again; Start fresh clears them before '
      'the cloud copy goes', () {
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    final pause = settings.substring(
      settings.indexOf('Widget _buildPauseStreakCard()'),
      settings.indexOf('Widget _buildSettingsTab('),
    );
    expect(
      RegExp(
        r'setStreakPause\(picked\);\s+unawaited\(ReminderService\(\)\.reschedule\(\)\);',
      ).hasMatch(pause),
      isTrue,
    );
    expect(
      RegExp(
        r'clearStreakPause\(\);\s+unawaited\(ReminderService\(\)\.reschedule\(\)\);',
      ).hasMatch(pause),
      isTrue,
    );
    final reset = settings.substring(
      settings.indexOf('Future<void> _resetProgress()'),
      settings.indexOf('Future<void> _openPrivacyPolicy()'),
    );
    final clear = reset.indexOf('ReminderService().resetAll()');
    expect(clear, isNonNegative);
    expect(clear, lessThan(reset.indexOf('deleteCloudData()')));
  });
}
```

In `test/screens/settings_copy_test.dart`, after the `_starsAndShopBody` constant, add:

```dart

const _bedtimeReminderBody =
    'In Settings > Reminders you can turn on one reminder on this phone '
    'each evening, and a morning one too. It comes around the time '
    'you pick, only if that brush hasn\'t happened yet, and not while '
    'the streak is paused. If Brush Quest isn\'t opened for a week, '
    'the reminders stop by themselves.\n\n'
    'Reminders are scheduled and shown entirely on this phone; '
    'nothing is sent to us. You can also turn them off in your '
    'phone\'s notification settings.';
```

and at the end of `group('Parent Guide tab', ...)`, after `'Our Promise is unchanged'`, add:

```dart
    testWidgets('the Bedtime Reminder paragraph, word for word', (
      tester,
    ) async {
      await openGuide(tester);

      expect(inGuide(find.text('Bedtime Reminder')), findsOneWidget);
      expect(inGuide(find.byIcon(Icons.notifications_active)), findsOneWidget);
      expect(inGuide(find.text(_bedtimeReminderBody)), findsOneWidget);
    });
```

Run: `flutter test test/screens/settings_reminders_test.dart test/screens/settings_copy_test.dart`
Expected: FAIL. No REMINDERS card, no reschedule or resetAll calls, no Guide section.

- [ ] **Step 5: Wire the card, the Pause, Start fresh and the Guide into Settings**

In `lib/screens/settings_screen.dart`:

1. After `import '../services/analytics_service.dart';` (line 13) add `import '../services/reminder_service.dart';`, and after `import '../widgets/glass_card.dart';` (line 14) add `import '../widgets/reminder_settings_card.dart';`.

2. The Pause switch (in `_buildPauseStreakCard`). Replace

```dart
                if (picked != null) {
                  await StreakService().setStreakPause(picked);
                  setState(() {
```

with

```dart
                if (picked != null) {
                  // The bedtime reminder waits for the Pause to end.
                  await StreakService().setStreakPause(picked);
                  unawaited(ReminderService().reschedule());
                  setState(() {
```

and replace

```dart
                await StreakService().clearStreakPause();
                setState(() {
```

with

```dart
                await StreakService().clearStreakPause();
                unawaited(ReminderService().reschedule());
                setState(() {
```

3. `_resetProgress()`: before `    // Also delete cloud data if signed in` (line 1210), add:

```dart
    // The bedtime reminder: every notification cancelled, its settings and
    // offers forgotten.
    await ReminderService().resetAll();
```

4. `_buildSettingsTab()`: replace

```dart
        const SizedBox(height: 24),

        // ── OTHER ────────────────────────────────────────────
```

with

```dart
        const SizedBox(height: 24),

        // ── REMINDERS (the parent bedtime reminder) ──────────
        const _SectionHeader(
          icon: Icons.notifications_active,
          label: 'REMINDERS',
          color: Color(0xFFFFD54F),
        ),
        const SizedBox(height: 8),
        ReminderSettingsCard(onInteraction: _resetInactivityTimer),

        const SizedBox(height: 24),

        // ── OTHER ────────────────────────────────────────────
```

5. `_buildGuideTab()`: as the list's last section, just before its closing `const SizedBox(height: 32),`, add:

```dart
        _buildGuideSection(
          'Bedtime Reminder',
          'In Settings > Reminders you can turn on one reminder on this phone '
              'each evening, and a morning one too. It comes around the time '
              'you pick, only if that brush hasn\'t happened yet, and not while '
              'the streak is paused. If Brush Quest isn\'t opened for a week, '
              'the reminders stop by themselves.\n\n'
              'Reminders are scheduled and shown entirely on this phone; '
              'nothing is sent to us. You can also turn them off in your '
              'phone\'s notification settings.',
          Icons.notifications_active,
          const Color(0xFFFFD54F),
        ),
```

The paragraph is new parent copy (ruling R-10): every claim in it holds. "Around the time you pick" is there because Android delivers inexact alarms up to about an hour late. "A week" is the 7-day plan, and "nothing is sent to us" holds because the notifications are local only.

- [ ] **Step 6: Run the Settings tests**

Run: `flutter test test/screens/settings_reminders_test.dart test/screens/settings_copy_test.dart test/screens/settings_screen_test.dart test/screens/settings_parent_gate_test.dart test/screens/settings_camera_permission_test.dart test/widgets/reminder_settings_card_test.dart`
Expected: all PASS.

- [ ] **Step 7: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && dart run dart_code_linter:metrics analyze lib && flutter test`
Expected: "No issues found!" and "no issues found!", and every test passes.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/reminder_settings_card.dart lib/screens/settings_screen.dart test/widgets/reminder_settings_card_test.dart test/screens/settings_reminders_test.dart test/screens/settings_copy_test.dart
git commit -m "feat(reminder): Parents > Settings > Reminders, and the Guide paragraph

A REMINDERS card (bedtime and morning, each with its time; turning one
on asks the OS; a note and Open phone settings when notifications are
off, refreshed on return). The Pause replans the week; Start fresh
cancels every reminder and forgets its settings.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 9: The privacy-policy sentence and the project docs

**Files:**
- Modify: `docs/privacy-policy.html` (Section 1, after the Camera subsection, between lines 301 and 303)
- Modify: `test/flows/reminder_platform_setup_test.dart` (one test)
- Modify: `CLAUDE.md` (Key Decisions → Dependencies; Architecture; Settings Page; Game Flow)
- Modify: `STATUS.md` (a new entry at the top of the APP log, before line 14)

**Which policy file is live:** `docs/privacy-policy.html`. GitHub Pages serves `main:/docs` at brushquest.app (`docs/CNAME`; `gh api repos/{owner}/{repo}/pages` says `{'branch': 'main', 'path': '/docs'}`), so this is https://brushquest.app/privacy-policy.html.
- The root `privacy-policy.html` is an older copy that nothing serves. Leave it alone.
- The sentence goes live when this branch reaches `main` with the v1.1 release, not before. v29 has no reminders.
- A v29 final policy waits locally in `.remember/v29-launch/copy/privacy-policy-final.html`, to be published to `main` on the v29 submission day. When v1.1 merges after it, keep the v29 text and re-add this one subsection. That is a merge note for the controller (Task 10, Step 7).
- The effective date and the "Changes in this version" list are left to that release-day merge. The spec asks for one sentence.

- [ ] **Step 1: Write the failing test**

In `test/flows/reminder_platform_setup_test.dart`, add at the end of `main()`:

```dart
  test('the live privacy policy says the reminders stay on the device', () {
    // docs/ is what GitHub Pages serves at brushquest.app.
    final policy = read('docs/privacy-policy.html');
    expect(
      policy,
      contains('<h3>Bedtime reminders (optional, off by default)</h3>'),
    );
    expect(
      policy,
      contains(
        'Optional bedtime reminders are scheduled and shown entirely on your '
        'device; no information is sent to us.',
      ),
    );
  });
```

Run: `flutter test test/flows/reminder_platform_setup_test.dart`
Expected: FAIL on the new test.

- [ ] **Step 2: Add the approved sentence to the live policy**

In `docs/privacy-policy.html`, replace

```html
    </ul>

    <h3>Crash Reports (Android only, automatic, anonymous)</h3>
```

with

```html
    </ul>

    <h3>Bedtime reminders (optional, off by default)</h3>
    <p>Optional bedtime reminders are scheduled and shown entirely on your device; no information is sent to us.</p>

    <h3>Crash Reports (Android only, automatic, anonymous)</h3>
```

That spot is the end of the Camera subsection in Section 1, "What We Collect". The sentence is the spec's §5 sentence, word for word (Jim: yes). The App Store privacy label stays "Data Not Collected", and `docs/ios-port/privacy-labels.md` doesn't change.

Run: `flutter test test/flows/reminder_platform_setup_test.dart`
Expected: PASS.

- [ ] **Step 3: `CLAUDE.md`**

1. In Key Decisions, the **Dependencies** line: after `google_sign_in`, add `, flutter_local_notifications + timezone (the parent bedtime reminder: local notifications only, no FCM)`.

2. In Architecture, under `screens/`, after the `settings_screen.dart` line, add:

```text
    reminder_handoff_screen.dart  # After DONE, once or twice ever: Buddy calls a grown-up; the lock opens the GROWN-UP CHECK
    reminder_parent_screen.dart   # The parent's reminder screen (behind the gate): time, morning too, TURN ON / Not now
    after_brush_home.dart         # The fade to Home after a brush (victory and the reminder screens)
```

   Under `services/`, after `sync_service.dart`, add:

```text
    reminder_plan.dart         # Bedtime reminder rules: the week's one-shots, copy, offers, default time (pure)
    reminder_platform.dart     # flutter_local_notifications behind ReminderPlatform (the only plugin user)
    reminder_service.dart      # Bedtime reminder: settings, offers, guarded weekly reschedule, analytics
```

   Under `widgets/`, after `mouth_guide.dart`, add:

```text
    parent_gate_dialog.dart    # The GROWN-UP CHECK (onboarding camera page, reminder hand-off)
    reminder_settings_card.dart # Parents > Settings > Reminders
    reminder_time_dropdown.dart # Quarter-hour time picker for the reminders
```

3. In **Settings Page**, after the Brushing line, add:

```markdown
- **Reminders**: bedtime reminder and an optional morning one, each with its time; turning one on asks the OS; if notifications are off in the phone, a note and Open phone settings
```

4. In **Game Flow**, after step 5, add a new step 6 and renumber "Progress auto-synced to cloud if signed in" to 7:

```markdown
6. After DONE, once or twice ever (the first brush; once more from the 3rd, on a later day, if the first was skipped): the bedtime-reminder hand-off. A picture (his hero → a grown-up with a phone) and Buddy: "Great mission! Grown-ups, tap the lock for a bedtime reminder." The lock opens the GROWN-UP CHECK, then the parent's screen (time, optional morning reminder, TURN ON asks the OS / Not now). The arrow, back or 15 s without a touch go Home. Reminders are local notifications at the parent's time, only if that brush hasn't happened, never while the app is open, planned a week ahead
```

- [ ] **Step 4: `STATUS.md`**

Under `### APP`, before the first dated entry (line 14, `- **2026-10-15 — v1.1 rework 2: …`), add one line. Use the day you run this (`date +%Y-%m-%d`) and no usage numbers:

```markdown
- **<today> — v1.1 Part C built: the parent bedtime reminder.** Plan `docs/superpowers/plans/2026-10-15-bedtime-reminder.md`. After DONE, once or twice ever, a hand-off screen (no words; Buddy: "Great mission! Grown-ups, tap the lock for a bedtime reminder.") leads through the GROWN-UP CHECK to the parent's screen: TURN ON asks the OS and saves only if allowed; Not now is final. Local notifications (flutter_local_notifications 22.3.2, inexact, no exact-alarm permission), a week planned ahead, skipped when that brush is done, during the Pause and while the app is open; Parents > Settings > Reminders; Start fresh clears them; one sentence added to the live privacy policy. The gift-night line waits for the sticker card (always off until Part B). iOS Kids Category binary gate passes. **Next:** the three-evening lateness check on Jim's Android phone, and the hand-off test with Oliver (Hard Block).
```

- [ ] **Step 5: Format, analyze, full suite**

Run: `dart format lib test && dart analyze && flutter test`
Expected: "No issues found!" and every test passes.

- [ ] **Step 6: Commit**

```bash
git add docs/privacy-policy.html test/flows/reminder_platform_setup_test.dart CLAUDE.md STATUS.md
git commit -m "docs(reminder): the privacy-policy sentence, CLAUDE.md and STATUS

'Optional bedtime reminders are scheduled and shown entirely on your
device; no information is sent to us.' in the live policy (docs/,
served by GitHub Pages; live once v1.1 reaches main).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01STWCtX8pE4SLhUiiBxVG9M"
```

---

### Task 10: Device checks before Jim sees it (controller only, not a subagent)

**Files:** none change unless a check finds a problem. Then fix it in a new commit, with a test.

- [ ] **Step 1: All quality gates**

```bash
cd /Users/jimchabas/Projects/brush-quest
dart format --set-exit-if-changed lib test
dart analyze
dart run dart_code_linter:metrics analyze lib
flutter test
TZ=Europe/Paris flutter test test/services/reminder_plan_test.dart
semgrep --config auto lib/
gitleaks detect --source .
```

Expected:
- No format changes; "No issues found!" twice; every test passes, in Paris time too.
- semgrep: 0 findings.
- gitleaks: only the 9 historical false positives that predate this branch.

- [ ] **Step 2: Release-shaped Android build: the icons survive the shrinker**

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --release
~/Library/Android/sdk/build-tools/35.0.0/aapt2 dump resources build/app/outputs/flutter-apk/app-release.apk | grep -E "drawable/(ic_stat_brush_reminder|ic_reminder_large)"
~/Library/Android/sdk/build-tools/35.0.0/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk | grep -E "NOTIFICATIONS|BOOT|EXACT"
```

Expected:
- Both drawables are listed. If either is missing, `res/raw/keep.xml` isn't applied, and every reminder would fail in release.
- The permissions are POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED, and nothing with EXACT.

- [ ] **Step 3: iOS: the Kids Category gate and the privacy manifest**

```bash
flutter build ios --release --no-codesign
scripts/check_ios_kids_binary.sh build/ios/iphoneos/Runner.app
find build/ios/iphoneos/Runner.app -name PrivacyInfo.xcprivacy -path '*flutter_local_notifications*' -exec plutil -p {} \;
```

Expected: `PASS`, and the plugin's manifest has `"NSPrivacyTracking" => false` and `"NSPrivacyCollectedDataTypes" => []`. For the App Store submission notes (when iOS ships): "Optional parent-set brushing reminder, enabled only behind the parental gate; local notifications only."

- [ ] **Step 4: The emulator walkthrough (CLAUDE.md Pre-Ship UX Checklist)**

On `test_pixel` (Android 14, so the POST_NOTIFICATIONS prompt is real):

```bash
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
$ANDROID_SDK_ROOT/emulator/emulator -avd test_pixel -no-snapshot-save &
$ANDROID_SDK_ROOT/platform-tools/adb wait-for-device
flutter build apk --debug
$ANDROID_SDK_ROOT/platform-tools/adb uninstall com.brushquest.brush_quest
$ANDROID_SDK_ROOT/platform-tools/adb install build/app/outputs/flutter-apk/app-debug.apk
```

As a 7-year-old who can't read, then as the parent:
1. Fresh install: onboarding, then the first brush (Parents > Settings > Timer per zone 10 s makes it shorter), the victory screen, DONE.
2. The hand-off:
   - Is it clear without words that the phone goes to a grown-up?
   - Does Buddy's line start after the closing line, with nothing over it?
   - The lock: the GROWN-UP CHECK, then the parent's screen.
3. The parent's screen: TURN ON, then Android's "Allow Brush Quest to send you notifications?", Allow. "Reminder set for 7:30 PM", then Home with its usual return line.
4. Check the week is scheduled (the app in the background first: press Home):

```bash
$ANDROID_SDK_ROOT/platform-tools/adb shell dumpsys alarm | grep -B2 -A6 com.brushquest.brush_quest | head -60
```

   Expected: alarms for the next evenings at 7:30 pm local, and none for tonight while the app was open.
5. To see one fire without waiting, set the clock 1 minute before the reminder (the emulator is a `google_apis` image, so `adb root` works). Leave the app in the background, wait up to a few minutes, then put things back:

```bash
$ANDROID_SDK_ROOT/platform-tools/adb root
$ANDROID_SDK_ROOT/platform-tools/adb shell settings put global auto_time 0
$ANDROID_SDK_ROOT/platform-tools/adb shell date <MMDDhhmmYYYY.ss>
$ANDROID_SDK_ROOT/platform-tools/adb shell settings put global auto_time 1
```

   `<MMDDhhmmYYYY.ss>` is the toybox `date` format: for 2026-10-16 19:29:00, `101619292026.00`.
   - Check: the title and text, the tooth-and-moon icon in the status bar, the app icon as the large icon, and the channel "Brushing reminders" in the app's notification settings.
   - Tapping it opens Home with its greeting.
6. Parents > Settings > Reminders: turn the morning on; change the evening time; turn the evening off. Use `dumpsys alarm` after each change.
   - Pause: the alarms before the Pause's end are gone.
   - Start fresh: no alarm is left.
7. Offer 2. Start fresh, brush once, and skip the hand-off with the arrow. Brush twice more. Move the clock to tomorrow and brush again: the hand-off comes back once. Skip it, and it never comes again.

Note anything that collides, reads wrong or doesn't fit a 360 dp screen. Fix it before Jim sees it.

- [ ] **Step 5: Three evenings on Jim's Android phone (lateness)**

The spec's device check. It needs Jim's go for a build: `1.1.0+42` to Play internal, or a direct install on his Samsung (Android 16).
- Jim turns the reminder on through the hand-off, or Parents > Settings > Reminders, at his usual time minus 30 minutes. The default does this.
- For three evenings he doesn't open the app before the reminder, and he notes when it arrives.
- An evening when the brush came first and no reminder showed counts as a check of the skip rule. It is no lateness data.
- Decision rule (spec §5):
  - Mostly within 30 minutes: ship as is.
  - Over 30 minutes on 2 of the 3 evenings, or once over 60: propose moving the default 15 minutes earlier. That is a Tier 3 copy and economy-neutral change, so Jim's call.
  - Never exact alarms.
- Record the three times in the SDD ledger and the Test Run artifact's v1.1 tab.

- [ ] **Step 6: The hand-off test with Oliver (Hard Block: Jim and Oliver)**

On Oliver's own phone, with the new build. He already has brushes and no reminder state, so his next DONE brings offer 1 (ruling R-1). Never use Start fresh on his phone: it would wipe his progress.
- Jim watches without prompting. Does Oliver bring the phone to a grown-up, tap the lock himself, tap the arrow, or wait out the 15 s?
- Ask him afterwards what Buddy asked him to do.
- If he skips, offer 2 comes from his 3rd brush on a later day. Watch that one too if you can.
- The answers decide whether the hand-off ships as it is. Record them in the Test Run artifact.

- [ ] **Step 7: Report**

Write the results into the SDD ledger: the gates, the release-build icons, the iOS gate, the walkthrough notes, the three evenings, and Oliver's hand-off. Update the Test Run artifact's v1.1 tab. Remind Jim of the two merge notes:
- When v1.1 reaches `main` after the v29 final policy has been published, keep the v29 text and re-add the "Bedtime reminders" subsection.
- Part B wires the sticker card's gift check into `ReminderService._instance`.
