import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the audioplayers family exactly as v28 (Android production) resolved
/// it. Only audioplayers_darwin (the iOS/macOS Swift implementation) is
/// vendored in packages/audioplayers_darwin so iOS fixes can be patched in;
/// everything Android runs must stay the hosted pub.dev package it was.
///
/// If one of these fails after a `flutter pub get` / `pub upgrade`, an
/// Android audio dependency moved: that needs its own reviewed release, not a
/// silent bump riding along with iOS work.
void main() {
  late String lock;

  setUpAll(() {
    lock = File('pubspec.lock').readAsStringSync();
  });

  const hosted = <String, ({String version, String sha256})>{
    'audioplayers': (
      version: '6.6.0',
      sha256:
          'a72dd459d1a48f61a6fb9c0134dba26597c9236af40639ff0eb70eb4e0baab70',
    ),
    'audioplayers_android': (
      version: '5.2.1',
      sha256:
          '60a6728277228413a85755bd3ffd6fab98f6555608923813ce383b190a360605',
    ),
    'audioplayers_platform_interface': (
      version: '7.1.1',
      sha256:
          '0e2f6a919ab56d0fec272e801abc07b26ae7f31980f912f24af4748763e5a656',
    ),
  };

  for (final entry in hosted.entries) {
    test('${entry.key} stays hosted ${entry.value.version}', () {
      final block = _lockEntry(lock, entry.key);
      expect(block, contains('source: hosted'));
      expect(block, contains('url: "https://pub.dev"'));
      expect(block, contains('version: "${entry.value.version}"'));
      expect(block, contains(entry.value.sha256));
    });
  }

  test('audioplayers_darwin resolves to the vendored 6.3.0 copy', () {
    final block = _lockEntry(lock, 'audioplayers_darwin');
    expect(block, contains('path: "packages/audioplayers_darwin"'));
    expect(block, contains('source: path'));
    expect(block, contains('version: "6.3.0"'));
    // darwin 6.4.0+ has the Swift continuation leak that hangs every voice.
    final pubspec = File(
      'packages/audioplayers_darwin/pubspec.yaml',
    ).readAsStringSync();
    expect(pubspec, contains('version: 6.3.0'));
  });

  test('vendored audioplayers_darwin only carries Darwin native code', () {
    // No Dart and no Android sources: the vendored package cannot change
    // what Android compiles or runs.
    const root = 'packages/audioplayers_darwin';
    expect(Directory('$root/lib').existsSync(), isFalse);
    expect(Directory('$root/android').existsSync(), isFalse);
    final pubspec = File('$root/pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('android:')));
    expect(pubspec, contains('implements: audioplayers'));
  });
}

/// The `  <name>:` block of pubspec.lock, up to the next package entry.
String _lockEntry(String lock, String name) {
  final start = lock.indexOf('\n  $name:\n');
  expect(start, isNot(-1), reason: '$name missing from pubspec.lock');
  final next = RegExp(
    r'\n  [a-z_0-9]+:\n',
  ).firstMatch(lock.substring(start + name.length + 4));
  final end = next == null ? lock.length : start + name.length + 4 + next.start;
  final block = lock.substring(start, end);
  // Exactly one package header, so a match can't come from a neighbour.
  expect(RegExp(r'\n  [a-z_0-9]+:\n').allMatches(block), hasLength(1));
  return block;
}
