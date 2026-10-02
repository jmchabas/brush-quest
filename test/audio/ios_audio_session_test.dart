import 'dart:async';
import 'dart:io';

import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_audio_service_harness.dart';

/// AVAudioSession recovery (interruptions, headphones lost, media-services
/// reset): AppDelegate.swift forwards the native notifications on the
/// `brushquest/audio_session` channel and the REAL AudioService reacts. Host
/// runs with `debugIsIOSOverride` (HYBRID, see real_audio_service_harness);
/// real interruptions (calls, Siri, alarms, AirPods) need a device.
void main() {
  setUpAll(AudioHarness.install);
  tearDown(() {
    const MethodChannel('brushquest/audio_session').setMethodCallHandler(null);
  });

  const codec = StandardMethodCodec();

  /// Deliver a native -> Dart call on the session channel. Returns whether
  /// a Dart handler answered (false = no handler registered).
  bool Function() sendSessionEvent(
    AudioHarness h,
    String method, [
    Object? arguments,
  ]) {
    var answered = false;
    unawaited(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'brushquest/audio_session',
            codec.encodeMethodCall(MethodCall(method, arguments)),
            (reply) => answered = reply != null,
          ),
    );
    h.elapseMs(0);
    return () => answered;
  }

  int msOf(String line) => int.parse(line.trim().split('ms').first);

  test('wiring: iOS-only registration, native name matches, Dart never '
      'invokes the channel', () {
    const name = 'brushquest/audio_session';
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      main,
      contains(
        'if (Platform.isIOS) AudioService.listenForIosAudioSessionEvents();',
      ),
    );
    final uses = <String>[
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.readAsStringSync().contains(name)) f.path,
    ];
    expect(uses, ['lib/services/audio_service.dart']);
    final audio = File('lib/services/audio_service.dart').readAsStringSync();
    expect(audio, isNot(contains('_iosSessionChannel.invokeMethod')));
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, contains('"$name"'));
    expect(delegate, contains('engineBridge.applicationRegistrar.messenger()'));
    for (final event in [
      'interruptionBegan',
      'interruptionEnded',
      'routeLost',
      'mediaServicesReset',
    ]) {
      expect(delegate, contains('"$event"'));
      expect(audio, contains("'$event'"));
    }
  });

  test('Android: no session listener is ever registered', () {
    AudioHarness.run((h) {
      AudioService.listenForIosAudioSessionEvents();
      unawaited(h.service.playVoice('voice_super.mp3'));
      h.elapseMs(200);
      final answered = sendSessionEvent(h, 'interruptionEnded', {
        'shouldResume': true,
      });
      h.elapse(const Duration(seconds: 2));
      expect(answered(), isFalse);
      expect(h.callsOf('stop', label: 'V'), isEmpty);
    });
  });

  test('iOS: interruption ended ends the stuck voice at once; the queue '
      'carries on with no 15 s timeout', () {
    AudioHarness.run(
      (h) {
        AudioService.listenForIosAudioSessionEvents();
        unawaited(h.service.playVoice('voice_world_candy_crater.mp3'));
        unawaited(h.service.playVoice('voice_arc2_beat1.mp3'));
        // The system paused the player mid-line: its complete never comes.
        h.elapseMs(1000);
        final answered = sendSessionEvent(h, 'interruptionEnded', {
          'shouldResume': true,
        });
        h.elapseMs(500);
        expect(answered(), isTrue);
        final next = h.log.firstWhere(
          (l) => l.contains('setSourceUrl voice_arc2_beat1.mp3'),
        );
        expect(msOf(next), lessThan(1100));
        h.elapse(const Duration(seconds: 3));
        // Drained ~1.5 s after the event, not after the 15 s pump timeout.
        // (The pump reports any externally ended item as `voice_timeout`,
        // the same as an interrupt; that label is pre-existing.)
        expect(h.service.isVoicePipelineActive, isFalse);
      },
      ios: true,
      voiceDurations: const {
        'voice_world_candy_crater.mp3': Duration(seconds: 30),
        'voice_arc2_beat1.mp3': Duration(milliseconds: 900),
      },
    );
  });

  test('iOS: interruption ended restarts the music at the screen volume', () {
    AudioHarness.run((h) {
      AudioService.listenForIosAudioSessionEvents();
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.setMusicVolume(0.06));
      h.elapseMs(100);
      sendSessionEvent(h, 'interruptionBegan');
      h.elapseMs(3000);
      expect(h.callsOf('create', label: 'M2'), isEmpty);
      sendSessionEvent(h, 'interruptionEnded', {'shouldResume': true});
      h.elapseMs(500);
      expect(h.callsOf('setSourceUrl', label: 'M2'), hasLength(1));
      expect(h.callsOf('resume', label: 'M2'), hasLength(1));
      expect(h.callsOf('setVolume', label: 'M2').last, endsWith(' 0.06'));
      expect(s.isMusicPlaying, isTrue);
    }, ios: true);
  });

  test('iOS: media-services reset also restarts the music', () {
    AudioHarness.run((h) {
      AudioService.listenForIosAudioSessionEvents();
      unawaited(h.service.playMusic('battle_music_loop.mp3'));
      h.elapseMs(200);
      sendSessionEvent(h, 'mediaServicesReset');
      h.elapseMs(500);
      expect(h.callsOf('resume', label: 'M2'), hasLength(1));
    }, ios: true);
  });

  test('iOS: no music restart while the kid has the session paused; '
      'RESUME resumes the same player', () {
    AudioHarness.run((h) {
      AudioService.listenForIosAudioSessionEvents();
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.pauseMusic()); // PAUSE overlay (or iOS inactive auto-pause)
      h.elapseMs(100);
      sendSessionEvent(h, 'interruptionEnded', {'shouldResume': true});
      h.elapseMs(500);
      expect(h.callsOf('create', label: 'M2'), isEmpty);
      unawaited(s.resumeMusic());
      h.elapseMs(200);
      expect(h.callsOf('resume', label: 'M1'), hasLength(2));
      expect(h.callsOf('create', label: 'M2'), isEmpty);
    }, ios: true);
  });

  test('iOS: nothing restarts when muted or when no music was playing', () {
    AudioHarness.run((h) {
      AudioService.listenForIosAudioSessionEvents();
      sendSessionEvent(h, 'interruptionEnded', {'shouldResume': true});
      h.elapseMs(500);
      expect(h.callsOf('create'), isEmpty);
      expect(h.callsOf('setSourceUrl'), isEmpty);
    }, ios: true);
    AudioHarness.run(
      (h) {
        AudioService.listenForIosAudioSessionEvents();
        sendSessionEvent(h, 'mediaServicesReset');
        h.elapseMs(500);
        expect(h.callsOf('create'), isEmpty);
      },
      ios: true,
      prefs: const {'muted': true},
    );
  });

  test('iOS: interruption began drops the voice in flight and the queue', () {
    AudioHarness.run(
      (h) {
        AudioService.listenForIosAudioSessionEvents();
        unawaited(h.service.playVoice('voice_greet_streak_high_1.mp3'));
        unawaited(h.service.playVoice('voice_streak_teach_high.mp3'));
        h.elapseMs(500);
        sendSessionEvent(h, 'interruptionBegan');
        h.elapse(const Duration(seconds: 3));
        expect(h.callsOf('setSourceUrl', label: 'V'), hasLength(1));
        expect(h.callsOf('stop', label: 'V'), hasLength(1));
        expect(h.service.isVoicePipelineActive, isFalse);
      },
      ios: true,
      voiceDurations: const {
        'voice_greet_streak_high_1.mp3': Duration(seconds: 2),
      },
    );
  });

  test('iOS: headphones lost ends the stuck voice but leaves music alone', () {
    AudioHarness.run(
      (h) {
        AudioService.listenForIosAudioSessionEvents();
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(100);
        unawaited(s.playVoice('voice_three.mp3'));
        unawaited(s.playVoice('voice_two.mp3'));
        h.elapseMs(500);
        sendSessionEvent(h, 'routeLost');
        h.elapseMs(200);
        final next = h.callsOf('setSourceUrl', label: 'V').last;
        expect(next, contains('voice_two.mp3'));
        expect(msOf(next), lessThan(700));
        h.elapse(const Duration(seconds: 2));
        expect(h.service.isVoicePipelineActive, isFalse);
        expect(h.callsOf('create', label: 'M2'), isEmpty);
      },
      ios: true,
      voiceDurations: const {'voice_three.mp3': Duration(seconds: 30)},
    );
  });
}
