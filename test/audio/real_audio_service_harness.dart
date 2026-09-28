import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:brush_quest/services/audio_service.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_service.dart';

/// Host-side harness that drives the REAL [AudioService] (real
/// `audioplayers` Dart layer, real voice pump, real music health logic)
/// against a scripted fake of the native audioplayers platform.
///
/// Why: every other audio test injects [FakeAudioService], so the real
/// `_pumpVoiceQueue` / `playMusic` / `ensureMusicPlaying` / lifecycle paths
/// had zero behavioural host coverage. This harness records every
/// platform-interface call the real service produces (the same calls that
/// cross the `xyz.luan/audioplayers` method channel on device), stamped with
/// fake-clock time, so a change to shared audio code shows up as a diff.
///
/// Players are labelled by creation order, which is fixed by
/// `AudioService._internal()`:
///   V  = voice player, M0 = first music player, S0..S2 = SFX pool,
///   M1, M2, ... = every later player (only `playMusic` creates players
///   outside `preloadAll`, which the harness never calls).
///
/// Everything runs inside [FakeAsync]; use plain `test()`, not `testWidgets`.
///
/// Known gap: `AudioPlayer.dispose()` never reaches the platform inside
/// FakeAsync (its `Future.wait` includes subscription-cancel futures that
/// complete on the root zone), so `dispose` calls are not recorded and
/// anything that awaits a player's dispose() would hang here. Today only
/// playMusic's `Platform.isIOS` branch awaits it, which host runs never take.
class AudioHarness {
  AudioHarness._(this.async, this.platform, this.cache);

  final FakeAsync async;
  final FakeAudioplayersPlatform platform;
  final FakeAudioCache cache;
  late final AudioService service;

  /// Every `debugPrint` line emitted while the harness ran.
  final List<String> prints = [];

  static FakeAudioplayersPlatform? _platform;
  static FakeAudioCache? _cache;

  /// Install the fake platform + cache. Call from `setUpAll`.
  static void install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _platform ??= FakeAudioplayersPlatform();
    _cache ??= FakeAudioCache();
    AudioplayersPlatformInterface.instance = _platform!;
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
    AudioCache.instance = _cache!;
    // Build the static global scope now so its log stream binds to a fake.
    expect(AudioPlayer.global, isNotNull);
  }

  /// Run [body] against a fresh real [AudioService] inside [FakeAsync].
  ///
  /// [voiceDurations] maps an asset basename to how long the fake native
  /// player "plays" it before emitting `complete` (release-mode players
  /// only; looping music never completes on its own, matching Android's
  /// native `isLooping`). Unlisted voice files default to 1 s.
  ///
  /// [ios] drives `AudioService.debugIsIOSOverride` (reset to null after).
  /// Note an `ios: true` run is a HYBRID: code that still reads
  /// `Platform.isIOS` directly (playMusic's awaited dispose, main.dart) keeps
  /// taking the host/Android branch.
  static void run(
    void Function(AudioHarness h) body, {
    bool ios = false,
    Map<String, Duration> voiceDurations = const {},
    Set<String> neverPrepare = const {},
    Map<String, Duration> loadDelays = const {},
    Map<String, Duration> replyDelays = const {},
    Map<String, Object?> prefs = const {'muted': false},
  }) {
    final platform = _platform;
    final cache = _cache;
    if (platform == null || cache == null) {
      throw StateError('Call AudioHarness.install() in setUpAll first.');
    }
    SharedPreferences.setMockInitialValues(
      Map<String, Object>.of(prefs.map((k, v) => MapEntry(k, v!))),
    );
    final originalDebugPrint = debugPrint;
    AudioService.debugIsIOSOverride = ios;
    try {
      fakeAsync((async) {
        platform.reset(
          clock: () => async.elapsed,
          voiceDurations: voiceDurations,
          neverPrepare: neverPrepare,
          replyDelays: replyDelays,
        );
        cache.loadDelays
          ..clear()
          ..addAll(loadDelays);
        // A fresh global platform instance makes `GlobalAudioScope` re-run
        // its one-time init INSIDE this FakeAsync zone. (A future completed
        // in the root zone would schedule its listeners outside FakeAsync.)
        // Initialising before any player exists means every player's
        // `_create()` takes the same number of hops, so `create` calls
        // arrive in construction order and player labels are stable.
        GlobalAudioplayersPlatformInterface.instance =
            FakeGlobalAudioplayersPlatform();
        unawaited(AudioPlayer.global.ensureInitialized());
        async.flushMicrotasks();
        final h = AudioHarness._(async, platform, cache);
        // The iOS music watchdog reads AudioService._now(); follow fake time.
        final epoch = DateTime(2026, 9, 28);
        AudioService.debugNowOverride = () => epoch.add(async.elapsed);
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message == null) return;
          h.prints.add(message);
          // AUDIO_TRACE lines ('[AUD] ...') stay out of the call log so
          // assertions and goldens read the same with tracing compiled in.
          if (!message.startsWith('[')) platform.note('print $message');
        };
        AudioService.testInstance = null; // builds a real AudioService
        h.service = AudioService.testInstance;
        async.flushMicrotasks();
        if (platform.createdCount != 5) {
          throw StateError(
            'Expected 5 players after construction, got '
            '${platform.createdCount}',
          );
        }
        platform.clearLog();
        body(h);
      });
    } finally {
      debugPrint = originalDebugPrint;
      AudioService.debugIsIOSOverride = null;
      AudioService.debugNowOverride = null;
      // Park a player-less fake so later tests never touch real players.
      AudioService.testInstance = FakeAudioService();
    }
  }

  /// Advance fake time (runs timers + microtasks).
  void elapse(Duration d) => async.elapse(d);

  void elapseMs(int ms) => async.elapse(Duration(milliseconds: ms));

  /// Emit a native event on the player with [label].
  void emit(String label, AudioEventType type) =>
      platform.emitEvent(label, type);

  /// Platform log lines (see [FakeAudioplayersPlatform.log]).
  List<String> get log => platform.log;

  /// `audio issue: ...` lines reported by the service.
  List<String> get issues =>
      prints.where((p) => p.startsWith('audio issue:')).toList();

  /// Platform calls of [method] (optionally only on [label]).
  List<String> callsOf(String method, {String? label}) =>
      platform.log.where((line) {
        final m = _callLine.firstMatch(line);
        if (m == null) return false;
        return m.group(2) == method && (label == null || m.group(1) == label);
      }).toList();

  static final _callLine = RegExp(r'^\s*\d+ms (\S+)\.(\w+)');
}

/// Scripted stand-in for the native audioplayers plugin.
class FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, String> _labels = {};
  final Map<String, StreamController<AudioEvent>> _events = {};
  final Map<String, String?> _currentFile = {};
  final Map<String, ReleaseMode> _releaseMode = {};
  final Map<String, Timer> _completeTimers = {};
  final Map<String, int> _positions = {};

  Duration Function() _clock = () => Duration.zero;
  Map<String, Duration> _voiceDurations = const {};

  /// Asset basenames whose `prepared` event never arrives. Mutable so a
  /// test can let a later attempt succeed.
  final Set<String> neverPrepare = {};
  Map<String, Duration> _replyDelays = const {};

  int createdCount = 0;
  final List<String> log = [];

  void reset({
    required Duration Function() clock,
    required Map<String, Duration> voiceDurations,
    required Set<String> neverPrepare,
    required Map<String, Duration> replyDelays,
  }) {
    for (final t in _completeTimers.values) {
      t.cancel();
    }
    _completeTimers.clear();
    _labels.clear();
    _events.clear();
    _currentFile.clear();
    _releaseMode.clear();
    _positions.clear();
    createdCount = 0;
    log.clear();
    _clock = clock;
    _voiceDurations = voiceDurations;
    this.neverPrepare
      ..clear()
      ..addAll(neverPrepare);
    _replyDelays = replyDelays;
  }

  void clearLog() => log.clear();

  String _stamp() => '${_clock().inMilliseconds}ms'.padLeft(8);

  void note(String line) => log.add('${_stamp()} $line');

  String labelOf(String playerId) => _labels[playerId] ?? '?';

  String idOf(String label) =>
      _labels.entries.firstWhere((e) => e.value == label).key;

  /// Latest-created player whose label starts with [prefix] (e.g. 'M').
  String latestLabel(String prefix) =>
      _labels.values.where((l) => l.startsWith(prefix)).last;

  void setPosition(String label, int ms) => _positions[idOf(label)] = ms;

  Future<void> _call(String playerId, String method, [String args = '']) async {
    log.add(
      '${_stamp()} ${labelOf(playerId)}.$method${args.isEmpty ? '' : ' $args'}',
    );
    final delay = _replyDelays[method];
    if (delay != null) await Future<void>.delayed(delay);
  }

  void _cancelComplete(String playerId) =>
      _completeTimers.remove(playerId)?.cancel();

  void emitEvent(String label, AudioEventType type) {
    final id = idOf(label);
    log.add('${_stamp()} $label <- ${type.name}');
    _events[id]?.add(
      AudioEvent(
        eventType: type,
        isPrepared: type == AudioEventType.prepared ? true : null,
      ),
    );
  }

  static String _basename(String url) => url.split('/').last;

  @override
  Future<void> create(String playerId) async {
    final n = createdCount++;
    const fixed = ['V', 'M0', 'S0', 'S1', 'S2'];
    _labels[playerId] = n < fixed.length ? fixed[n] : 'M${n - 4}';
    _events[playerId] = StreamController<AudioEvent>.broadcast();
    _releaseMode[playerId] = ReleaseMode.release;
    await _call(playerId, 'create');
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _events[playerId]!.stream;

  @override
  Future<void> dispose(String playerId) async {
    _cancelComplete(playerId);
    await _call(playerId, 'dispose');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    _cancelComplete(playerId);
    final file = _basename(url);
    _currentFile[playerId] = file;
    _positions[playerId] = 0;
    await _call(playerId, 'setSourceUrl', file);
    if (neverPrepare.contains(file)) return;
    // Native preparation completes on a later event-loop turn.
    Timer(const Duration(milliseconds: 20), () {
      if (_currentFile[playerId] != file || !_events.containsKey(playerId)) {
        return;
      }
      emitEvent(labelOf(playerId), AudioEventType.prepared);
    });
  }

  @override
  Future<void> resume(String playerId) async {
    await _call(playerId, 'resume');
    _cancelComplete(playerId);
    final file = _currentFile[playerId];
    if (file == null || _releaseMode[playerId] == ReleaseMode.loop) return;
    final duration =
        _voiceDurations[file] ??
        (file.startsWith('voice_') ? const Duration(seconds: 1) : null);
    if (duration == null) return;
    _completeTimers[playerId] = Timer(duration, () {
      _completeTimers.remove(playerId);
      if (_currentFile[playerId] != file) return;
      emitEvent(labelOf(playerId), AudioEventType.complete);
    });
  }

  @override
  Future<void> pause(String playerId) async {
    _cancelComplete(playerId);
    await _call(playerId, 'pause');
  }

  @override
  Future<void> stop(String playerId) async {
    _cancelComplete(playerId);
    await _call(playerId, 'stop');
  }

  @override
  Future<void> release(String playerId) async {
    _cancelComplete(playerId);
    await _call(playerId, 'release');
  }

  @override
  Future<void> seek(String playerId, Duration position) =>
      _call(playerId, 'seek', '${position.inMilliseconds}');

  @override
  Future<void> setBalance(String playerId, double balance) =>
      _call(playerId, 'setBalance', '$balance');

  @override
  Future<void> setVolume(String playerId, double volume) =>
      _call(playerId, 'setVolume', '$volume');

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) {
    _releaseMode[playerId] = releaseMode;
    return _call(playerId, 'setReleaseMode', releaseMode.name);
  }

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) =>
      _call(playerId, 'setPlaybackRate', '$playbackRate');

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) => _call(playerId, 'setSourceBytes');

  @override
  Future<void> setAudioContext(String playerId, AudioContext audioContext) =>
      _call(playerId, 'setAudioContext');

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) =>
      _call(playerId, 'setPlayerMode', playerMode.name);

  @override
  Future<int?> getDuration(String playerId) async {
    await _call(playerId, 'getDuration');
    return null;
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async {
    await _call(playerId, 'getCurrentPosition');
    return _positions[playerId] ?? 0;
  }

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
}

class FakeGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  final _events = StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _events.stream;

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}
}

/// Resolves assets to fake cache paths without touching rootBundle /
/// path_provider. [loadDelays] (by basename) simulates a slow asset copy.
class FakeAudioCache extends AudioCache {
  final Map<String, Duration> loadDelays = {};

  @override
  Future<String> loadPath(String fileName) async {
    final delay = loadDelays[fileName.split('/').last];
    if (delay != null) await Future<void>.delayed(delay);
    return '/cache/$fileName';
  }
}

/// Compare [lines] with the golden text file at [path] (relative to the
/// package root). `flutter test --update-goldens` rewrites the file.
void expectAudioGolden(List<String> lines, String path) {
  final file = File(path);
  final actual = '${lines.join('\n')}\n';
  if (autoUpdateGoldenFiles) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing audio golden $path. Record it with --update-goldens.',
  );
  expect(
    actual,
    file.readAsStringSync(),
    reason:
        'Android audio call sequence changed ($path). If this is an '
        'intended Android behaviour change, re-record with --update-goldens '
        'and justify it in the commit; otherwise the change leaked outside '
        'its iOS gate.',
  );
}
