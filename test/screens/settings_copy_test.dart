import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';

/// v29 parent-facing copy in Settings, approved verbatim by Jim:
///
/// * the cloud-save consent dialog (reached through "Sign in with Google").
///   Its analytics sentence is platform-specific: the iPhone binary contains
///   no Firebase Analytics, Crashlytics or ads (Apple Kids Category), so the
///   Android wording would be false there.
/// * the Parent Guide tab, whose old text promised things the app does not do
///   (a "structured, not random" chest, a 5-day "Daily Bonuses" cycle, two
///   teeth icons on the home screen).
///
/// The strings are pinned on purpose: they are the approved text, so changing
/// the copy has to be a deliberate edit here too.

// ── Cloud-save consent dialog ─────────────────────────────────────────────
const _consentTitle = 'Cloud Save — Data Notice';

const _consentIntro =
    'By signing in, you agree to back up your child\'s game progress to '
    'Google\'s cloud (Firebase). It backs up automatically after each '
    'brush and includes:';

const _consentBullets =
    '• Brushing history (date and time), counts and streaks\n'
    '• Stars, unlocked items and trophies\n'
    '• Settings\n'
    '• Your email and name from the sign-in';

const _iosAnalyticsSentence =
    'Brush Quest doesn\'t use any analytics, advertising or '
    'crash-reporting tools.';

const _androidAnalyticsSentence =
    'Brush Quest also sends app usage and crash data, not linked to your '
    'name or email (Google Firebase Analytics and Crashlytics, advertising '
    'ID off), so we can fix bugs. Nothing is used for advertising or '
    'personalization.';

const _consentClosing =
    'We never ask for your child\'s name, age or photo. To delete '
    'everything, including the backup and this sign-in, use Delete Account '
    'in Settings.';

// ── Parent Guide ──────────────────────────────────────────────────────────
const _ourPromiseBody =
    'Brush Quest is designed to make tooth brushing a habit your child '
    'looks forward to.\n\n'
    'There are no ads. No purchase prompts are shown to children. '
    'Everything is earned through brushing.';

const _streaksBody =
    'Brushing every day builds a streak. The longer the streak, the more '
    'bonus stars your child earns and the better their chest odds.\n\n'
    'If a day is missed, there\'s a one-day grace period — your child '
    'won\'t lose their streak from a single missed day. You can also pause '
    'the streak from the parent dashboard for vacations or sick days.\n\n'
    'Their best streak is saved and shown on the Dashboard.';

const _morningEveningBody =
    'The app supports two brushing sessions per day — morning (before '
    'noon) and evening (after noon). When your child brushes both morning '
    'and evening, they earn a bonus star.\n\n'
    'The TODAY card on the Dashboard tab shows which sessions are done and '
    'at what time.';

const _treasureChestsBody =
    'After each session, your child opens a treasure chest. Every chest '
    'holds at least 1 bonus star, and sometimes 2, 3 or 5. What\'s inside '
    'is a surprise; longer streaks (3+ and 7+ days) make the bigger '
    'rewards more likely.\n\n'
    'Chests are free and can\'t be bought. Nothing in the app costs real '
    'money.\n\n'
    'About one day in four is a Treasure Boost day: every chest gives 1 '
    'extra star.';

const _trophyCollectingBody =
    'Your child captures monster trophies by brushing. Each world has 5 '
    'monsters, taken on in order, one per completed brushing session. Most '
    'are captured in 1 session; tougher ones take 2 or 3. When your child '
    'finishes a world, any monster still left in it joins the collection '
    'automatically.\n\n'
    'Trophies are earned only through brushing — never at random, '
    'never through purchases.';

const _starsAndShopBody =
    'Stars are earned by brushing: 2 per session, 1 to 5 more from the '
    'treasure chest, and bonuses for streaks, for brushing morning and '
    'evening, and for coming back after a break. Stars can be spent in the '
    'shop on new heroes and gear.\n\n'
    'Your child\'s Ranger Rank (lifetime total) never goes down — only '
    'the spendable wallet changes when they buy something.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

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
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
    AudioService.debugIsIOSOverride = null;
  });

  /// Pumps Settings at [size] and passes the Parent Check (the math gate).
  Future<void> pumpUnlockedSettings(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final challenge = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge)!;
    final answer = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    await tester.enterText(find.byType(TextField), '$answer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Settings tab -> "Sign in with Google" -> the consent dialog is on screen.
  /// Nothing is consented to, so no real sign-in is ever attempted.
  ///
  /// Uses a tall surface: widget tests draw text in the Ahem test font (every
  /// glyph 1 em wide, about twice the width of a real font), so the dialog is
  /// much taller here than on a device. The tall surface keeps these tests
  /// about the copy, not about layout.
  Future<void> openConsentDialog(WidgetTester tester) async {
    await pumpUnlockedSettings(tester, const Size(430, 1400));
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_consentTitle), findsOneWidget);
  }

  /// Scopes [matching] to the consent dialog: the Settings tab behind it is
  /// still in the widget tree and must not satisfy (or break) an assertion.
  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  group('cloud-save consent dialog', () {
    testWidgets('iOS: says there are no analytics, ads or crash reporting', (
      tester,
    ) async {
      AudioService.debugIsIOSOverride = true;
      await openConsentDialog(tester);

      expect(inDialog(find.text(_iosAnalyticsSentence)), findsOneWidget);
      expect(inDialog(find.text(_androidAnalyticsSentence)), findsNothing);
      // The iPhone build contains none of these SDKs, so it must not name them.
      expect(inDialog(find.textContaining('Crashlytics')), findsNothing);
      expect(inDialog(find.textContaining('Analytics')), findsNothing);
      expect(inDialog(find.textContaining('advertising ID')), findsNothing);
      expect(inDialog(find.text(_consentClosing)), findsOneWidget);
    });

    testWidgets('Android: names Firebase Analytics and Crashlytics, not '
        '"anonymous"', (tester) async {
      AudioService.debugIsIOSOverride = false;
      await openConsentDialog(tester);

      expect(inDialog(find.text(_androidAnalyticsSentence)), findsOneWidget);
      expect(inDialog(find.text(_iosAnalyticsSentence)), findsNothing);
      expect(inDialog(find.textContaining('Crashlytics')), findsOneWidget);
      expect(
        inDialog(find.textContaining('advertising ID off')),
        findsOneWidget,
      );
      expect(inDialog(find.textContaining('anonymous')), findsNothing);
      expect(inDialog(find.text(_consentClosing)), findsOneWidget);
    });

    for (final isIOS in <bool>[true, false]) {
      final platform = isIOS ? 'iOS' : 'Android';

      testWidgets('$platform: intro, bullets and closing are the approved '
          'text', (tester) async {
        AudioService.debugIsIOSOverride = isIOS;
        await openConsentDialog(tester);

        expect(inDialog(find.text(_consentIntro)), findsOneWidget);
        expect(inDialog(find.text(_consentBullets)), findsOneWidget);
        expect(inDialog(find.text(_consentClosing)), findsOneWidget);
      });

      testWidgets('$platform: none of the superseded wording is left', (
        tester,
      ) async {
        AudioService.debugIsIOSOverride = isIOS;
        await openConsentDialog(tester);

        expect(inDialog(find.textContaining('you consent to')), findsNothing);
        expect(
          inDialog(find.textContaining('This data includes')),
          findsNothing,
        );
        expect(
          inDialog(find.textContaining('Brush counts and streaks')),
          findsNothing,
        );
        expect(inDialog(find.textContaining('anonymous')), findsNothing);
        expect(
          inDialog(find.textContaining('No personal information')),
          findsNothing,
        );
        expect(
          inDialog(find.textContaining('resetting progress')),
          findsNothing,
        );
      });

      testWidgets('$platform: keeps the privacy link and both actions', (
        tester,
      ) async {
        AudioService.debugIsIOSOverride = isIOS;
        await openConsentDialog(tester);

        expect(inDialog(find.text('Read our Privacy Policy')), findsOneWidget);
        expect(inDialog(find.text('CANCEL')), findsOneWidget);
        expect(inDialog(find.text('I CONSENT')), findsOneWidget);
      });
    }

    testWidgets('cannot be dismissed by tapping the barrier', (tester) async {
      await openConsentDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      // A tap on the dimmed barrier, far outside the dialog card.
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(_consentTitle), findsOneWidget);
    });

    testWidgets('CANCEL still closes it and starts no sign-in', (tester) async {
      await openConsentDialog(tester);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      // Still offering sign-in (no spinner): the parent declined.
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Parent Guide tab', () {
    // The Guide's ListView, set by [openGuide].
    late Finder guide;

    /// Opens the Guide tab on a tall surface so the whole list is built, not
    /// just the first screenful of a lazily built ListView.
    Future<void> openGuide(WidgetTester tester) async {
      await pumpUnlockedSettings(tester, const Size(430, 3200));
      await openTab(tester, 'Guide');
      expect(find.text('Our Promise'), findsOneWidget);
      guide = find.ancestor(
        of: find.text('Our Promise'),
        matching: find.byType(ListView),
      );
      expect(guide, findsOneWidget);
    }

    /// Scopes [matching] to the Guide, as [inDialog] does for the dialog.
    Finder inGuide(Finder matching) =>
        find.descendant(of: guide, matching: matching);

    testWidgets('Daily Bonuses and the false claims are gone', (tester) async {
      await openGuide(tester);

      expect(inGuide(find.text('Daily Bonuses')), findsNothing);
      expect(inGuide(find.byIcon(Icons.flash_on)), findsNothing);
      expect(inGuide(find.textContaining('5-day cycle')), findsNothing);
      expect(inGuide(find.textContaining('precision')), findsNothing);
      expect(
        inGuide(find.textContaining('structured, not random')),
        findsNothing,
      );
      expect(inGuide(find.textContaining('loot boxes')), findsNothing);
      expect(inGuide(find.textContaining('Two teeth icons')), findsNothing);
      expect(inGuide(find.textContaining('always remembered')), findsNothing);
    });

    testWidgets('keeps the six remaining sections, each with title and icon', (
      tester,
    ) async {
      await openGuide(tester);

      for (final title in <String>[
        'Our Promise',
        'Streaks',
        'Morning & Evening',
        'Treasure Chests',
        'Trophy Collecting',
        'Stars & The Shop',
      ]) {
        expect(inGuide(find.text(title)), findsOneWidget, reason: title);
      }
      for (final icon in <IconData>[
        Icons.favorite,
        Icons.local_fire_department,
        Icons.wb_twilight,
        Icons.card_giftcard,
        Icons.emoji_events,
        Icons.star,
      ]) {
        expect(inGuide(find.byIcon(icon)), findsOneWidget, reason: '$icon');
      }
    });

    testWidgets('shows the corrected text, word for word', (tester) async {
      await openGuide(tester);

      for (final body in <String>[
        _streaksBody,
        _morningEveningBody,
        _treasureChestsBody,
        _trophyCollectingBody,
        _starsAndShopBody,
      ]) {
        expect(inGuide(find.text(body)), findsOneWidget, reason: body);
      }
      // The two fixes parents will actually notice, spelled out.
      expect(
        inGuide(find.textContaining('The TODAY card on the Dashboard tab')),
        findsOneWidget,
      );
      expect(
        inGuide(find.textContaining('What\'s inside is a surprise')),
        findsOneWidget,
      );
    });

    testWidgets('Our Promise is unchanged', (tester) async {
      await openGuide(tester);

      expect(inGuide(find.text(_ourPromiseBody)), findsOneWidget);
    });
  });
}
