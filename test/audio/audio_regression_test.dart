import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard tests for AudioService.
///
/// These read the source code directly and verify critical patterns exist.
/// They protect against specific bugs that have broken audio in past releases.
/// See CLAUDE.md "Audio fix -- CRITICAL, DO NOT BREAK" for context.
void main() {
  late String audioSource;
  late String brushingSource;

  setUpAll(() {
    audioSource = File('lib/services/audio_service.dart').readAsStringSync();
    brushingSource = File(
      'lib/screens/brushing_screen.dart',
    ).readAsStringSync();
  });

  test('AndroidAudioFocus.none is set globally', () {
    // All audio players must coexist without stealing focus from each other.
    // If this is changed to any other focus mode, SFX/voice/music will
    // interrupt each other on Android.
    expect(
      audioSource.contains('AndroidAudioFocus.none'),
      isTrue,
      reason:
          'AudioService must set AndroidAudioFocus.none so players coexist. '
          'Manual volume ducking replaces OS-level audio focus.',
    );

    // It should be set via the global AudioPlayer context
    expect(
      audioSource.contains('AudioPlayer.global.setAudioContext'),
      isTrue,
      reason:
          'AndroidAudioFocus.none must be set globally via '
          'AudioPlayer.global.setAudioContext, not per-player.',
    );
  });

  test('Voice pump uses Future.any with completion, external-stop, timeout', () {
    // The voice pump must use Future.any with three signals:
    //   1. onPlayerComplete — natural end of voice
    //   2. an explicit external-stop completer (_activeVoiceStop) fired by
    //      stopVoice()/interrupt — so interrupts recover instantly
    //   3. Duration(seconds: 15) timeout — fallback safety net
    //
    // The external-stop completer REPLACED the old Android
    // onPlayerStateChanged(PlayerState.stopped) listener, which could not
    // distinguish a real external stop from the transient `stopped` blip
    // emitted during a normal source-swap when the queue advances — that
    // false-positive cut every queued voice that followed another (v25 bug:
    // trophy naming voice not played + victory voices cut). Do NOT reintroduce
    // a PlayerState.stopped-based completion signal in the pump.

    expect(
      audioSource.contains('Future.any'),
      isTrue,
      reason: 'Voice pump must use Future.any for completion detection.',
    );

    expect(
      audioSource.contains('onPlayerComplete'),
      isTrue,
      reason: 'Voice pump must listen for onPlayerComplete.',
    );

    // Explicit per-item external-stop completer must exist and be raced.
    expect(
      audioSource.contains('_activeVoiceStop'),
      isTrue,
      reason:
          'Voice pump must use an explicit external-stop completer '
          '(_activeVoiceStop) so interrupts recover without the 15s timeout.',
    );

    // stopVoice() and interrupt must fire that completer.
    expect(
      audioSource.contains('_fireVoiceStop()'),
      isTrue,
      reason:
          'stopVoice() and playVoice(interrupt:) must call _fireVoiceStop() so '
          'a genuine external stop ends the pump wait immediately.',
    );

    // Guard against regression: the pump must NOT race a
    // PlayerState.stopped listener for completion — on Android that event
    // fires during normal source-swaps and falsely cuts the next queued voice.
    // (Mentions of PlayerState.stopped in comments are fine; the removed code
    // was the stream filter `s == PlayerState.stopped`.)
    expect(
      audioSource.contains('s == PlayerState.stopped'),
      isFalse,
      reason:
          'Voice pump must NOT filter onPlayerStateChanged for '
          'PlayerState.stopped — use the _activeVoiceStop completer instead.',
    );

    // 15-second timeout fallback must remain.
    expect(
      RegExp(r'Duration\(seconds:\s*15\)').hasMatch(audioSource),
      isTrue,
      reason: 'Voice pump must have a 15-second timeout as fallback.',
    );
  });

  test('playSfx does NOT early-return when voice is playing', () {
    // SFX must still play during voice lines, just at reduced volume (0.24).
    // A previous bug suppressed SFX entirely during voice playback.

    // Extract the playSfx method body
    final playSfxStart = audioSource.indexOf(RegExp(r'playSfx\('));
    expect(playSfxStart, isNot(-1), reason: 'playSfx method not found.');

    // Find the method body (from first { after playSfx to matching })
    final methodStart = audioSource.indexOf('{', playSfxStart);
    int braceDepth = 0;
    int methodEnd = methodStart;
    for (int i = methodStart; i < audioSource.length; i++) {
      if (audioSource[i] == '{') braceDepth++;
      if (audioSource[i] == '}') braceDepth--;
      if (braceDepth == 0) {
        methodEnd = i + 1;
        break;
      }
    }
    final playSfxBody = audioSource.substring(methodStart, methodEnd);

    // Should NOT early-return based on voice state
    expect(
      playSfxBody.contains('_voicePlaying') &&
          RegExp(
            r'if\s*\(\s*_voicePlaying\s*\)\s*return',
          ).hasMatch(playSfxBody),
      isFalse,
      reason:
          'playSfx must NOT early-return when voice is playing. '
          'It should adjust volume instead (0.24 during voice, 0.7 otherwise).',
    );

    // Should adjust volume based on voice state
    expect(
      playSfxBody.contains('0.24'),
      isTrue,
      reason:
          'playSfx must duck SFX volume to 0.24 during voice playback, '
          'not suppress SFX entirely.',
    );

    // The mute guard is OK -- only _muted should cause early return
    expect(
      playSfxBody.contains('if (_muted) return'),
      isTrue,
      reason: 'playSfx should still have the _muted early return guard.',
    );
  });

  test('playMusic disposes old player and creates new AudioPlayer', () {
    // A fresh AudioPlayer must be created for each music session to avoid
    // stuck player state on Android. The old player must be disposed first.

    // Extract playMusic method body (anchored on the declaration, so a new
    // helper that calls playMusic( above it can't hijack the extraction).
    final playMusicStart = audioSource.indexOf(
      RegExp(r'Future<void> playMusic\('),
    );
    expect(playMusicStart, isNot(-1), reason: 'playMusic method not found.');
    // Start at the body brace after `async`, not the `{...}` named-parameter
    // list in the signature.
    final asyncIdx = audioSource.indexOf('async', playMusicStart);
    final methodStart = audioSource.indexOf('{', asyncIdx);
    int braceDepth = 0;
    int methodEnd = methodStart;
    for (int i = methodStart; i < audioSource.length; i++) {
      if (audioSource[i] == '{') braceDepth++;
      if (audioSource[i] == '}') braceDepth--;
      if (braceDepth == 0) {
        methodEnd = i + 1;
        break;
      }
    }
    final playMusicBody = audioSource.substring(methodStart, methodEnd);

    // Must dispose old player
    expect(
      playMusicBody.contains('_musicPlayer.dispose()'),
      isTrue,
      reason:
          'playMusic must dispose the old _musicPlayer before creating a new one.',
    );

    // Must create fresh AudioPlayer
    expect(
      playMusicBody.contains('_musicPlayer = AudioPlayer()'),
      isTrue,
      reason:
          'playMusic must assign a fresh AudioPlayer() to _musicPlayer. '
          'Reusing a stuck player causes silent music on Android.',
    );

    // dispose must come before new AudioPlayer creation
    final disposeIdx = playMusicBody.indexOf('_musicPlayer.dispose()');
    final newPlayerIdx = playMusicBody.indexOf('_musicPlayer = AudioPlayer()');
    expect(
      disposeIdx < newPlayerIdx,
      isTrue,
      reason: 'Old player must be disposed BEFORE creating a new AudioPlayer.',
    );
  });

  test('Music health check exists with periodic ~5s timer', () {
    // A periodic timer must call ensureMusicPlaying to recover stuck music.
    // The timer should fire every ~5 seconds.

    // AudioService must expose ensureMusicPlaying
    expect(
      audioSource.contains('ensureMusicPlaying'),
      isTrue,
      reason: 'AudioService must have an ensureMusicPlaying method.',
    );

    // ensureMusicPlaying must check player state and restart if needed
    expect(
      audioSource.contains('PlayerState.playing'),
      isTrue,
      reason:
          'ensureMusicPlaying must check PlayerState to detect stuck player.',
    );

    // Brushing screen must set up a periodic timer that calls it
    expect(
      brushingSource.contains('ensureMusicPlaying'),
      isTrue,
      reason: 'Brushing screen must call ensureMusicPlaying periodically.',
    );

    // Timer should be periodic with 5-second interval
    expect(
      RegExp(
        r'Timer\.periodic\s*\(\s*const\s+Duration\(seconds:\s*5\)',
      ).hasMatch(brushingSource),
      isTrue,
      reason:
          'Brushing screen must use Timer.periodic with 5-second interval '
          'for music health checks.',
    );
  });

  test('Voice queue cleared on mute', () {
    // When the user mutes audio, any queued voice lines must be cleared
    // and the voice player stopped immediately.

    // Extract toggleMute method body
    final toggleMuteStart = audioSource.indexOf('toggleMute()');
    expect(toggleMuteStart, isNot(-1), reason: 'toggleMute method not found.');
    final methodStart = audioSource.indexOf('{', toggleMuteStart);
    int braceDepth = 0;
    int methodEnd = methodStart;
    for (int i = methodStart; i < audioSource.length; i++) {
      if (audioSource[i] == '{') braceDepth++;
      if (audioSource[i] == '}') braceDepth--;
      if (braceDepth == 0) {
        methodEnd = i + 1;
        break;
      }
    }
    final toggleMuteBody = audioSource.substring(methodStart, methodEnd);

    // Must clear the voice queue
    expect(
      toggleMuteBody.contains('_clearVoiceQueue()'),
      isTrue,
      reason:
          'toggleMute must call _clearVoiceQueue() when muting to prevent '
          'queued voice lines from playing after unmute.',
    );

    // Must stop the voice player
    expect(
      toggleMuteBody.contains('_voicePlayer.stop()'),
      isTrue,
      reason: 'toggleMute must stop _voicePlayer when muting.',
    );

    // Verify _clearVoiceQueue actually drains the queue
    expect(
      audioSource.contains('_voiceQueue.removeFirst()'),
      isTrue,
      reason: '_clearVoiceQueue must drain the queue by removing all entries.',
    );
  });

  // ── iOS audio work guards (release/v29) ───────────────────────────────
  // The iOS fixes are gated behind AudioService.isIOS so Android v28 audio
  // stays byte-identical (see test/audio/android_audio_golden_test.dart).

  test('debugIsIOSOverride is never assigned from lib/', () {
    final assignment = RegExp(r'debugIsIOSOverride\s*=(?!=)');
    final offenders = <String>[
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final m in assignment.allMatches(f.readAsStringSync()))
            '${f.path}@${m.start}',
    ];
    // The declaration `static bool? debugIsIOSOverride;` has no `=`.
    expect(
      offenders,
      isEmpty,
      reason:
          'debugIsIOSOverride is a host-test hook. Assigning it in lib/ would '
          'force the iOS audio branches on Android (or vice versa).',
    );
  });

  test('iOS gates go through AudioService.isIOS, not new Platform checks', () {
    // Exactly two Platform.isIOS reads in audio_service.dart: the isIOS
    // getter itself and the pre-existing awaited-dispose gate in playMusic.
    final audioCode = audioSource.replaceAll(RegExp('//.*'), '');
    expect(
      'Platform.isIOS'.allMatches(audioCode).length,
      2,
      reason:
          'New iOS-only audio behaviour must use AudioService.isIOS so host '
          'tests can exercise both branches.',
    );
    final brushingCode = brushingSource.replaceAll(RegExp('//.*'), '');
    expect(brushingCode.contains('Platform.is'), isFalse);
    expect(audioCode.contains('!Platform.isAndroid'), isFalse);
  });

  test('voice pump never listens to onPlayerStateChanged', () {
    // Hard rule (feedback_audio_behavior.md): no PlayerState.completed or
    // PlayerState.stopped listener in the pump; both false-fire.
    final pump = _methodBody(audioSource, 'Future<void> _pumpVoiceQueue(');
    expect(pump.contains('onPlayerStateChanged'), isFalse);
    expect(pump.contains('PlayerState.completed'), isFalse);
  });

  test('playMusic still resets the target volume to the 0.18 default', () {
    // Screens (e.g. brushing) call playMusic() with no setMusicVolume after
    // it. Keeping the previous screen's level inside playMusic would start
    // battle music at Home's 0.06. Keep-volume logic belongs to the callers
    // that need it (e.g. the iOS health-check restart), never to playMusic.
    final body = _methodBody(audioSource, 'Future<void> playMusic(');
    expect(body.contains('_musicTargetVolume = _musicVolume'), isTrue);
  });

  test('any stop() in the voice pump sits under an isIOS gate', () {
    // Android's pump has no pre-play stop (v28 baseline; the old
    // memory note "stop() before play() is necessary on Android" is stale).
    // The iOS pre-play reset must stay behind isIOS.
    final code = audioSource.replaceAll(RegExp('//.*'), '');
    final pump = _methodBody(code, 'Future<void> _pumpVoiceQueue(');
    final isIOS = RegExp(r'\bisIOS\b');
    for (final m in RegExp(r'_voicePlayer\.stop\(|\b_ios\w*\(').allMatches(
      pump,
    )) {
      expect(
        _isGuarded(pump, m.start, isIOS),
        isTrue,
        reason: 'pump: `${m.group(0)}` must be inside an isIOS branch',
      );
    }
  });

  test('iOS-only audio state and helpers are only touched under isIOS', () {
    // Every `_ios*` field/method use in audio_service.dart must be (a) its
    // declaration, (b) inside an `_ios*` helper, (c) behind an isIOS check,
    // or (d) inside a trace block. Keeps Android on the v28 code path.
    final code = audioSource.replaceAll(RegExp('//.*'), '');
    final isIOS = RegExp(r'\bisIOS\b');
    final trace = RegExp(r'if \(_trace\)');
    final iosHelperHeader = RegExp(r'^[\w<>?]+\s+_ios\w*\(');
    final declaration = RegExp(r'^\s*(bool|String\?|double\?|Future<void>\?)'
        r'\s+_ios\w*( = .*)?;');
    final offenders = <String>[];
    for (final m in RegExp(r'\b_ios\w*').allMatches(code)) {
      final lineStart = code.lastIndexOf('\n', m.start) + 1;
      final line = code.substring(lineStart, code.indexOf('\n', m.start));
      if (declaration.hasMatch(line)) continue;
      if (iosHelperHeader.hasMatch(line.trim())) continue;
      final headers = _enclosingHeaders(code, m.start);
      final ok =
          _isGuarded(code, m.start, isIOS) ||
          _isGuarded(code, m.start, trace) ||
          headers.any(iosHelperHeader.hasMatch);
      if (!ok) offenders.add(line.trim());
    }
    expect(offenders, isEmpty);
  });

  test('audio trace output is compiled out unless AUDIO_TRACE is set', () {
    expect(
      audioSource.contains(
        "static const bool traceEnabled = bool.fromEnvironment('AUDIO_TRACE')",
      ),
      isTrue,
    );
    final traceCall = RegExp(r'(?<![\w.])(_t|AudioService\.trace)\(');
    final guard = RegExp(r'if \((_trace|AudioService\.traceEnabled)\)');
    final unguarded = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in traceCall.allMatches(src)) {
        // Skip the definitions themselves.
        final lineStart = src.lastIndexOf('\n', m.start) + 1;
        final line = src.substring(lineStart, src.indexOf('\n', m.start));
        if (line.contains('static void')) continue;
        if (!_isGuarded(src, m.start, guard)) {
          unguarded.add('${f.path}: ${line.trim()}');
        }
      }
      // The v26 breadcrumbs must not print in production builds.
      expect(
        RegExp(r"debugPrint\(\s*'\[(AUD|MUSIC|VIC)\]").hasMatch(src),
        isFalse,
        reason: '${f.path} prints an audio breadcrumb outside the trace gate',
      );
    }
    expect(
      unguarded,
      isEmpty,
      reason:
          'Every trace call (and any work done only for it, e.g. an awaited '
          'getCurrentPosition) must sit inside `if (_trace)` / '
          '`if (AudioService.traceEnabled)`.',
    );
  });
}

/// Body (including braces) of the method whose declaration starts with
/// [signature]. Skips a `{...}` named-parameter list in the signature.
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature not found');
  // First `{` after the parameter list's closing `)`.
  var depth = 0;
  var i = source.indexOf('(', start);
  for (; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) break;
    }
  }
  final open = source.indexOf('{', i);
  depth = 0;
  for (var j = open; j < source.length; j++) {
    if (source[j] == '{') depth++;
    if (source[j] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, j + 1);
    }
  }
  fail('unbalanced braces in $signature');
}

/// Headers (text between the previous `;`/`{`/`}` and the `{`) of every
/// block enclosing [index], innermost first.
List<String> _enclosingHeaders(String src, int index) {
  final headers = <String>[];
  var depth = 0;
  for (var i = index - 1; i >= 0; i--) {
    final c = src[i];
    if (c == '}') {
      depth++;
    } else if (c == '{') {
      if (depth > 0) {
        depth--;
        continue;
      }
      var j = i - 1;
      while (j >= 0 && !';{}'.contains(src[j])) {
        j--;
      }
      headers.add(src.substring(j + 1, i).trim());
    }
  }
  return headers;
}

/// True when the statement at [index] is `guard stmt;` or sits in a block
/// whose header matches [guard].
bool _isGuarded(String src, int index, RegExp guard) {
  var j = index - 1;
  while (j >= 0 && !';{}'.contains(src[j])) {
    j--;
  }
  if (guard.hasMatch(src.substring(j + 1, index))) return true;
  return _enclosingHeaders(src, index).any(guard.hasMatch);
}
