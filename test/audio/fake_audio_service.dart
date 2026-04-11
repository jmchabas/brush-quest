import 'dart:async';

import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter/foundation.dart';

/// A recorded method call on [FakeAudioService].
@immutable
class AudioCall {
  final String method;
  final Map<String, dynamic> args;
  const AudioCall(this.method, [this.args = const {}]);

  @override
  String toString() => 'AudioCall($method, $args)';

  @override
  bool operator ==(Object other) =>
      other is AudioCall && other.method == method && _mapsEqual(other.args, args);

  @override
  int get hashCode => Object.hash(method, args.toString());

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Fake [AudioService] that records method calls instead of playing audio.
///
/// Use [calls] to inspect what was called, and [callsFor] to filter by method.
class FakeAudioService extends AudioService {
  FakeAudioService() : super.forTesting();

  final List<AudioCall> calls = [];

  bool _muted = false;
  bool _voicePlaying = false;
  bool _musicPlaying = false;
  double _musicVolume = 0.18;
  String? _currentMusicFile;
  final List<String> _voiceQueue = [];

  // ── Queries ───────────────────────────────────────────────────

  @override
  bool get isMuted => _muted;

  @override
  bool get isVoicePlaying => _voicePlaying;

  @override
  bool get isVoicePipelineActive => _voicePlaying || _voiceQueue.isNotEmpty;

  @override
  bool get isMusicPlaying => _musicPlaying;
  double get musicVolume => _musicVolume;
  String? get currentMusicFile => _currentMusicFile;

  /// Return all calls matching a given method name.
  List<AudioCall> callsFor(String method) =>
      calls.where((c) => c.method == method).toList();

  /// Clear recorded calls (useful between test stages).
  void clearCalls() => calls.clear();

  // ── Overrides ─────────────────────────────────────────────────

  @override
  Future<void> preloadAll() async {
    calls.add(const AudioCall('preloadAll'));
  }

  @override
  Future<void> setVoiceStyle(String style) async {
    calls.add(AudioCall('setVoiceStyle', {'style': style}));
  }

  @override
  Future<void> toggleMute() async {
    _muted = !_muted;
    calls.add(AudioCall('toggleMute', {'newState': _muted}));
    if (_muted) {
      _clearVoiceQueue();
      _voicePlaying = false;
      _musicPlaying = false;
    }
  }

  @override
  Future<void> playSfx(String fileName) async {
    calls.add(AudioCall('playSfx', {'fileName': fileName}));
    if (_muted) return;
    // No-op beyond recording.
  }

  @override
  String nextHitSound() {
    calls.add(const AudioCall('nextHitSound'));
    return 'zap.mp3';
  }

  @override
  Future<void> playVoice(
    String fileName, {
    bool clearQueue = false,
    bool interrupt = false,
  }) async {
    calls.add(AudioCall('playVoice', {
      'fileName': fileName,
      'clearQueue': clearQueue,
      'interrupt': interrupt,
    }));
    if (_muted) return;
    if (clearQueue) {
      _clearVoiceQueue();
    }
    if (interrupt && _voicePlaying) {
      calls.add(const AudioCall('_voiceInterrupted'));
      _voicePlaying = false;
    }
    _voicePlaying = true;
    // Simulate ducking: record it so tests can verify the sequence.
    if (_musicPlaying) {
      _musicVolume = 0.08;
      calls.add(AudioCall('_musicDucked', {'volume': _musicVolume}));
    }
    // Simulate instant completion.
    _voicePlaying = false;
    if (_musicPlaying) {
      _musicVolume = 0.18;
      calls.add(AudioCall('_musicRestored', {'volume': _musicVolume}));
    }
  }

  void _clearVoiceQueue() {
    if (_voiceQueue.isNotEmpty) {
      calls.add(AudioCall('_voiceQueueCleared', {'count': _voiceQueue.length}));
      _voiceQueue.clear();
    }
  }

  @override
  Future<void> stopVoice() async {
    calls.add(const AudioCall('stopVoice'));
    _clearVoiceQueue();
    _voicePlaying = false;
  }

  @override
  Future<void> playMusic(String fileName) async {
    calls.add(AudioCall('playMusic', {'fileName': fileName}));
    if (_muted) return;
    _musicPlaying = true;
    _musicVolume = 0.18;
    _currentMusicFile = fileName;
  }

  @override
  Future<void> ensureMusicPlaying() async {
    calls.add(const AudioCall('ensureMusicPlaying'));
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    calls.add(AudioCall('setMusicVolume', {'volume': volume}));
    if (_musicPlaying) {
      _musicVolume = volume;
    }
  }

  @override
  Future<void> stopMusic() async {
    calls.add(const AudioCall('stopMusic'));
    _musicPlaying = false;
    _currentMusicFile = null;
  }

  @override
  List<String> get encouragementVoices => [
        'voice_keep_going.mp3',
        'voice_youre_doing_great.mp3',
        'voice_nice_combo.mp3',
      ];

  @override
  void dispose() {
    calls.add(const AudioCall('dispose'));
  }

  /// Simulate queueing a voice (for queue-related tests).
  void simulateQueueVoice(String fileName) {
    _voiceQueue.add(fileName);
  }

  /// Expose queue length for testing.
  int get voiceQueueLength => _voiceQueue.length;
}
