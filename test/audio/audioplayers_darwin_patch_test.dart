import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guards for the Brush Quest patches in the vendored
/// audioplayers_darwin 6.3.0 (packages/audioplayers_darwin). Host tests can't
/// run the Swift, so these pin that each patch is still present after an
/// upgrade or re-vendor. Behaviour is covered on the iOS Simulator by
/// integration_test/ios_audio_real_test.dart.
void main() {
  const src =
      'packages/audioplayers_darwin/darwin/audioplayers_darwin/Sources/'
      'audioplayers_darwin';
  late String player;
  late String plugin;

  setUpAll(() {
    player = File('$src/WrappedMediaPlayer.swift').readAsStringSync();
    plugin = File('$src/AudioplayersDarwinPlugin.swift').readAsStringSync();
  });

  test('N1: natural-completion rewind is bound to the item that finished', () {
    final body = _swiftFunc(player, 'private func onSoundComplete()');
    final capture = body.indexOf('let finishedItem = player.currentItem');
    final guard = body.indexOf(
      'guard self.player.currentItem === finishedItem else',
    );
    final release = body.indexOf('self.release()');
    expect(capture, isNot(-1), reason: 'finished item must be captured');
    expect(guard, greaterThan(capture));
    expect(
      release,
      greaterThan(guard),
      reason: 'release() must sit behind the item-identity guard',
    );
    expect(body, contains('NSLog('));
  });

  test('N1: a seek handler never pauses a replaced item', () {
    final body = _swiftFunc(player, 'private func seekThen(');
    final identity = body.indexOf('self.player.currentItem === ');
    final pause = body.indexOf('self.player.pause()');
    expect(identity, isNot(-1));
    expect(pause, greaterThan(identity));
  });

  test('H5: stop answers Dart without waiting on its rewind seek', () {
    final body = _swiftFunc(player, 'func stop(');
    // The rewind carries no completer, so a cancelled seek can't lose the
    // reply, and release mode can't reply twice.
    expect(body, contains('seek(time: toCMTime(millis: 0))\n'));
    expect(body, isNot(contains('seek(time: toCMTime(millis: 0), completer')));
    expect(body, contains('release(completer: completer)'));
    final elseBranch = body.indexOf('} else {');
    expect(elseBranch, isNot(-1));
    expect(body.indexOf('completer?()', elseBranch), greaterThan(elseBranch));
  });

  test('H3: a loop wrap resumes natively and sends no onComplete', () {
    final body = _swiftFunc(player, 'private func onSoundComplete()');
    final loop = body.indexOf('if releaseMode == ReleaseMode.loop {');
    expect(loop, isNot(-1), reason: 'loop mode must be handled up front');
    final loopBranch = _swiftBlockAt(body, loop);
    // Resume regardless of the rewind's `finished`, unless paused/stopped
    // (isPlaying cleared) or the item was replaced.
    expect(loopBranch, contains('seekThen(time: toCMTime(millis: 0))'));
    expect(
      loopBranch,
      contains('guard self.player.currentItem === finishedItem'),
    );
    expect(loopBranch, contains('if self.isPlaying {'));
    expect(loopBranch, contains('self.resume()'));
    expect(loopBranch, contains('return'));
    expect(loopBranch, isNot(contains('onComplete')));
    // Non-loop modes still report the natural end to Dart.
    expect(body.indexOf('eventHandler.onComplete()'), greaterThan(loop));
  });

  test('H6: a seek on a not-ready item is parked until .readyToPlay', () {
    final seek = _swiftFunc(player, 'private func seekThen(');
    final readyCheck = seek.indexOf('if currentItem.status != .readyToPlay {');
    final park = seek.indexOf('pendingSeek = (item: currentItem');
    final realSeek = seek.indexOf('currentItem.seek(to: time)');
    expect(readyCheck, isNot(-1));
    expect(park, greaterThan(readyCheck));
    expect(realSeek, greaterThan(park));
    final observer = _swiftFunc(
      player,
      'private func setUpPlayerItemStatusObservation(',
    );
    expect(observer, contains('self.runPendingSeek(for: playerItem)'));
    expect(
      _swiftFunc(player, 'private func reset()'),
      contains('cancelPendingSeek()'),
    );
  });

  test('C5: AVFoundation callbacks and event sinks run on the main thread', () {
    // Every FlutterEventSink call sits inside runOnMainThread { ... }.
    final sinks = RegExp(r'eventSink\(').allMatches(plugin).toList();
    expect(sinks, hasLength(8));
    for (final m in sinks) {
      final before = plugin.substring(0, m.start);
      final wrap = before.lastIndexOf('runOnMainThread {');
      final func = before.lastIndexOf('  func ');
      expect(
        wrap,
        greaterThan(func),
        reason: 'eventSink @${m.start} must be inside runOnMainThread',
      );
    }
    expect(
      _swiftFunc(player, 'private func setUpPlayerItemStatusObservation('),
      contains('self.onMainThread(for: playerItem) {'),
    );
    expect(
      _swiftFunc(player, 'private func setUpSoundCompletedObserver('),
      contains('self.onMainThread(for: playerItem) {'),
    );
    final seek = _swiftFunc(player, 'private func seekThen(');
    expect(
      'runOnMainThread { handler(finished) }'.allMatches(seek),
      hasLength(1),
    );
    expect(
      _swiftFunc(player, 'private func runPendingSeek('),
      contains('runOnMainThread { pending.handler(finished) }'),
    );
  });
}

/// The `{...}` block that opens at or after [index] in [source].
String _swiftBlockAt(String source, int index) {
  final open = source.indexOf('{', index);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(index, i + 1);
    }
  }
  fail('unbalanced braces at $index');
}

/// Text of the Swift function starting at [signature], braces included.
String _swiftFunc(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature not found');
  final open = source.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  fail('unbalanced braces after $signature');
}
