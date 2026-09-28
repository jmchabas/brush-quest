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

  setUpAll(() {
    player = File('$src/WrappedMediaPlayer.swift').readAsStringSync();
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
    final body = _swiftFunc(player, 'func seek(');
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
