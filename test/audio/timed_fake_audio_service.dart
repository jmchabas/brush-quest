// test/audio/timed_fake_audio_service.dart
import 'dart:async';
import 'dart:collection';

import 'fake_audio_service.dart';

/// One voice line sent to [TimedFakeAudioService], and what became of it.
class TimedVoice {
  TimedVoice(this.file, this.queuedAt);

  final String file;
  final Duration queuedAt;
  Duration? startedAt;
  Duration? endedAt;

  /// Stopped while playing (interrupt or stopVoice).
  bool cut = false;

  /// Removed from the queue before it played (clearQueue or stopVoice).
  bool dropped = false;

  final _done = Completer<void>();

  @override
  String toString() =>
      '$file queued=${queuedAt.inMilliseconds} '
      'start=${startedAt?.inMilliseconds} end=${endedAt?.inMilliseconds}'
      '${cut ? ' CUT' : ''}${dropped ? ' DROPPED' : ''}';
}

/// A voice channel that takes time, like the real one. [FakeAudioService]
/// finishes every line at once, so it can't show a line playing late, behind
/// others, or after the thing it explains is gone. This one follows
/// AudioService.playVoice and its queue:
///
/// - a line joins the end of the queue and plays for its length;
/// - `interrupt` stops only the line that is playing;
/// - `clearQueue` drops the lines still waiting;
/// - stopVoice does both;
/// - the returned future completes when the line ends, is cut or is dropped;
/// - [voicePipelineActiveNotifier] is true while a line plays or waits;
/// - muting stops what plays and drops what waits.
///
/// [playedVoiceLines] lists every line requested, dropped ones included; see
/// [voices] for what became of each.
///
/// Lengths come from [lengths], else [defaultLength]. Times are read from
/// [clock]: in a widget test, the fake-async time since the test began.
class TimedFakeAudioService extends FakeAudioService {
  TimedFakeAudioService({
    this.lengths = const {},
    this.defaultLength = const Duration(seconds: 2),
  });

  final Map<String, Duration> lengths;
  final Duration defaultLength;
  Duration Function() clock = () => Duration.zero;

  /// Every line sent, in order.
  final List<TimedVoice> voices = [];

  final Queue<TimedVoice> _waiting = Queue();
  TimedVoice? _playing;
  Timer? _timer;

  @override
  bool get isVoicePlaying => _playing != null;

  @override
  bool get isVoicePipelineActive => voicePipelineActiveNotifier.value;

  @override
  Future<void> toggleMute() async {
    await super.toggleMute();
    if (!isMuted) return;
    _dropWaiting();
    _cutPlaying();
    _update();
  }

  TimedVoice? voiceNamed(String file) {
    for (final voice in voices) {
      if (voice.file == file) return voice;
    }
    return null;
  }

  @override
  Future<void> playVoice(
    String fileName, {
    bool clearQueue = false,
    bool interrupt = false,
  }) async {
    calls.add(
      AudioCall('playVoice', {
        'fileName': fileName,
        'clearQueue': clearQueue,
        'interrupt': interrupt,
      }),
    );
    if (isMuted) return;
    if (clearQueue) _dropWaiting();
    final voice = TimedVoice(fileName, clock());
    voices.add(voice);
    playedVoiceLines.add(fileName);
    _waiting.add(voice);
    if (interrupt) _cutPlaying();
    _pump();
    await voice._done.future;
  }

  @override
  Future<void> stopVoice() async {
    calls.add(const AudioCall('stopVoice'));
    _dropWaiting();
    _cutPlaying();
    _update();
  }

  void _dropWaiting() {
    while (_waiting.isNotEmpty) {
      final voice = _waiting.removeFirst()..dropped = true;
      voice._done.complete();
    }
  }

  void _cutPlaying() {
    final voice = _playing;
    if (voice == null) return;
    _timer?.cancel();
    voice
      ..cut = true
      ..endedAt = clock();
    _playing = null;
    voice._done.complete();
  }

  void _pump() {
    if (_playing == null && _waiting.isNotEmpty) {
      final voice = _waiting.removeFirst()..startedAt = clock();
      _playing = voice;
      _timer = Timer(lengths[voice.file] ?? defaultLength, () {
        voice.endedAt = clock();
        _playing = null;
        voice._done.complete();
        _pump();
      });
    }
    _update();
  }

  void _update() {
    final active = _playing != null || _waiting.isNotEmpty;
    if (voicePipelineActiveNotifier.value != active) {
      voicePipelineActiveNotifier.value = active;
    }
  }
}
