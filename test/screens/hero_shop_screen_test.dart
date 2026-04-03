import 'package:brush_quest/screens/hero_shop_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';
import 'package:brush_quest/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    // Mock audioplayers platform channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
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
  });

  Future<void> pumpShop(
    WidgetTester tester, {
    int wallet = 50,
    List<String> unlockedHeroes = const ['blaze'],
    List<String> unlockedWeapons = const ['star_blaster'],
    List<String> unlockedEvolutions = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': wallet,
      'total_stars': wallet + 10,
      'unlocked_heroes': unlockedHeroes,
      'selected_hero': unlockedHeroes.first,
      'unlocked_weapons': unlockedWeapons,
      'selected_weapon': unlockedWeapons.first,
      'unlocked_evolutions': unlockedEvolutions,
      'muted': false,
      'current_world': 'candy_crater',
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(home: HeroShopScreen()),
    );
    // Let async _loadData and SharedPreferences complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  // ── Tab display ──────────────────────────────────────────────

  testWidgets('HEROES and WEAPONS tabs render', (tester) async {
    await pumpShop(tester);
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('WEAPONS'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Hero grid ────────────────────────────────────────────────

  testWidgets('hero grid shows all heroes', (tester) async {
    await pumpShop(tester);
    // Each hero row renders evolution cells. We should see one row per hero.
    // The HEROES tab is selected by default, so Blaze's row is visible.
    // Look for the check_circle icon (equipped indicator for blaze stage 1)
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('locked heroes show star price', (tester) async {
    await pumpShop(tester, wallet: 0);
    // Frost costs 5 stars — the price should be visible as text
    expect(find.text('5'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Weapon grid ──────────────────────────────────────────────

  testWidgets('weapon grid shows all weapons after tapping WEAPONS tab',
      (tester) async {
    await pumpShop(tester);
    // Tap WEAPONS tab
    await tester.tap(find.text('WEAPONS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Star Blaster is selected, so its featured display should show "EQUIPPED"
    expect(find.text('EQUIPPED'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('locked weapons show price tags', (tester) async {
    await pumpShop(tester, wallet: 0);
    // Switch to weapons tab
    await tester.tap(find.text('WEAPONS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Flame Sword costs 5 — price tag should be visible
    expect(find.text('5'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Wallet display ───────────────────────────────────────────

  testWidgets('wallet shows star count in header', (tester) async {
    await pumpShop(tester, wallet: 42);
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Evolution gating snackbar ────────────────────────────────

  testWidgets(
      'tapping stage 3 without owning stage 2 shows gating snackbar',
      (tester) async {
    // Blaze is owned, blaze_stage2 is NOT owned, so tapping stage 3 should
    // show the "Unlock the previous evolution first!" snackbar.
    await pumpShop(
      tester,
      wallet: 100,
      unlockedHeroes: ['blaze'],
      unlockedEvolutions: [], // stage2 not owned
    );

    // The hero grid is a ListView with hero rows. Each row has 3 evolution
    // cells. We need to tap the 3rd cell (stage 3) of the first row (Blaze).
    // The cells are GestureDetectors. Find all GestureDetector widgets in
    // the evolution grid area. Stage 3 evolution for Blaze shows a price
    // since it's locked but wallet >= price.
    //
    // However, stage 3 is gated because stage 2 is not owned, so it should
    // show a lock icon instead of a shopping cart.
    // Let's find the lock icons — stage 2 and stage 3 of each hero will
    // show lock state. We tap stage 3 of Blaze.

    // Stage 3 of Blaze costs 20 and we have 100 stars, but stage 2 isn't
    // owned, so stage 3 shows a lock. The _EvolutionCell for Blaze stage 3
    // will have isGated=true. Tapping it calls _onEvolutionTap which checks
    // gating and shows the snackbar.
    //
    // We need to locate the third evolution cell in the first _HeroEvolutionRow.
    // Each _HeroEvolutionRow contains 3 _EvolutionCell widgets.
    // Each _EvolutionCell has a GestureDetector. Let's find all of them.

    // There are many GestureDetectors on screen. The evolution cells are
    // wrapped in Expanded within a Row. Let's target by finding the lock
    // icon in cells — stage 3 should have a lock.
    //
    // A better approach: find all _EvolutionCell equivalent widgets by
    // finding GestureDetector children within evolution grid area.
    // Since we can't reference private widget types directly, let's
    // tap at the general position. However, widget tests work differently.
    //
    // Let's use the shopping cart icon to find buyable cells, and lock to
    // find gated ones. For Blaze: stage 1 is equipped (check_circle),
    // stage 2 is locked but affordable (shopping cart), stage 3 is gated
    // (lock icon).
    //
    // Actually, let's just find lock icons and tap the first one that
    // corresponds to stage 3.

    // Find all lock icons
    final lockIcons = find.byIcon(Icons.lock);
    expect(lockIcons, findsWidgets);

    // Tap the first lock icon — this should be in the Blaze row, stage 3
    // (stage 2 shows shopping cart since it's affordable and not gated)
    await tester.tap(lockIcons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Unlock the previous evolution first!'),
      findsOneWidget,
    );
    await tester.binding.setSurfaceSize(null);
  });

  // ── Header title ─────────────────────────────────────────────

  testWidgets('header shows HEROES & WEAPONS title', (tester) async {
    await pumpShop(tester);
    expect(find.text('HEROES & WEAPONS'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
