import 'dart:typed_data';

import 'package:brush_quest/services/camera_service.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';

/// Motion detection samples the luma (Y) plane of each camera frame.
///
/// On iOS, camera_avfoundation delivers ImageFormatGroup.yuv420 as a 2-plane
/// kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange buffer. Plane 0 is luma
/// and is copied as `bytesPerRow * height` bytes, where bytesPerRow is the
/// CVPixelBuffer row stride, usually padded past the pixel width
/// (ResolutionPreset.low = 352x288, stride 384 on typical iPhones). Sampling
/// must step rows by the stride and never read the padding.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const padding = 255; // sentinel: pixel values below never reach it

  int pixel(int x, int y) => (x * 7 + y * 13) % 200;

  /// A luma plane of [width] x [height] pixels with rows [stride] bytes long.
  /// Bytes past [width] in each row are [padding].
  Uint8List plane(int width, int height, int stride) {
    final bytes = Uint8List(stride * height)
      ..fillRange(0, stride * height, padding);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        bytes[y * stride + x] = pixel(x, y);
      }
    }
    return bytes;
  }

  group('CameraService.sampleLuma', () {
    test('iOS-style padded stride: samples pixels, never padding', () {
      const width = 352, height = 288, stride = 384;
      final sampled = CameraService.sampleLuma(
        plane(width, height, stride),
        width: width,
        height: height,
        bytesPerRow: stride,
      );

      expect(sampled.length, 32 * 32);
      expect(sampled.contains(padding), isFalse);
      for (var sy = 0; sy < 32; sy++) {
        for (var sx = 0; sx < 32; sx++) {
          final x = (sx * width / 32).floor();
          final y = (sy * height / 32).floor();
          expect(
            sampled[sy * 32 + sx],
            pixel(x, y),
            reason: 'sample ($sx,$sy) -> pixel ($x,$y)',
          );
        }
      }
    });

    test('padded and unpadded planes of the same image sample identically', () {
      const width = 352, height = 288;
      final padded = CameraService.sampleLuma(
        plane(width, height, 384),
        width: width,
        height: height,
        bytesPerRow: 384,
      );
      final tight = CameraService.sampleLuma(
        plane(width, height, width),
        width: width,
        height: height,
        bytesPerRow: width,
      );
      expect(padded, tight);
    });

    test('stepping rows by width instead of stride would be wrong', () {
      // Guards the reason bytesPerRow is used: on a padded plane, width-based
      // row addressing drifts into other rows and the padding.
      const width = 352, height = 288, stride = 384;
      final bytes = plane(width, height, stride);
      final byStride = CameraService.sampleLuma(
        bytes,
        width: width,
        height: height,
        bytesPerRow: stride,
      );
      final byWidth = CameraService.sampleLuma(
        bytes,
        width: width,
        height: height,
        bytesPerRow: width,
      );
      expect(byWidth, isNot(byStride));
    });

    test('portrait-rotated buffer (288x352) samples inside the image', () {
      const width = 288, height = 352, stride = 320;
      final sampled = CameraService.sampleLuma(
        plane(width, height, stride),
        width: width,
        height: height,
        bytesPerRow: stride,
      );
      expect(sampled.contains(padding), isFalse);
      expect(sampled[31 * 32 + 31], pixel(279, 341));
    });

    test('truncated plane reads zeros instead of throwing', () {
      const width = 352, height = 288, stride = 384;
      final bytes = Uint8List.sublistView(
        plane(width, height, stride),
        0,
        stride * 10,
      );
      final sampled = CameraService.sampleLuma(
        bytes,
        width: width,
        height: height,
        bytesPerRow: stride,
      );
      expect(sampled.length, 32 * 32);
      expect(sampled[1], pixel(11, 0)); // row 0 is present
      expect(sampled[31 * 32 + 31], 0); // row 279 is past the end
    });

    test('empty frame dimensions return a blank sample', () {
      final sampled = CameraService.sampleLuma(
        Uint8List(0),
        width: 0,
        height: 0,
        bytesPerRow: 0,
      );
      expect(sampled, everyElement(0));
    });
  });

  /// Brushing calls initialize() at every brush start, while the child holds
  /// the phone. It may only CHECK the camera permission: the OS dialog is
  /// reserved for the parent-gated flows (onboarding camera page, Settings).
  group('CameraService.initialize permission', () {
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const cameraChannel = MethodChannel('plugins.flutter.io/camera');
    // permission_handler wire values.
    const cameraPermission = 1; // Permission.camera
    const denied = 0;
    const granted = 1;
    const restricted = 2;
    const permanentlyDenied = 4;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> permissionCalls;
    late int statusResult;

    setUp(() {
      CameraService().dispose(); // singleton: start every test fresh
      permissionCalls = <MethodCall>[];
      statusResult = denied;
      messenger
        ..setMockMethodCallHandler(permissionChannel, (call) async {
          permissionCalls.add(call);
          switch (call.method) {
            case 'checkPermissionStatus':
              return statusResult;
            case 'requestPermissions':
              // What the OS dialog would answer if it were (wrongly) shown.
              return <int, int>{cameraPermission: statusResult};
          }
          return null;
        })
        // The test host has no camera.
        ..setMockMethodCallHandler(
          cameraChannel,
          (call) async => call.method == 'availableCameras' ? <Object>[] : null,
        );
    });

    tearDown(() {
      messenger
        ..setMockMethodCallHandler(permissionChannel, null)
        ..setMockMethodCallHandler(cameraChannel, null);
      CameraService().dispose();
    });

    List<String> permissionMethods() =>
        permissionCalls.map((c) => c.method).toList();

    for (final (name, status) in [
      ('denied', denied),
      ('restricted', restricted),
      ('permanentlyDenied', permanentlyDenied),
    ]) {
      test('$name -> false + permissionDenied, never asks the OS', () async {
        statusResult = status;
        final camera = CameraService();

        expect(await camera.initialize(), isFalse);

        expect(camera.permissionDenied, isTrue);
        expect(camera.isAvailable, isFalse);
        expect(
          permissionMethods(),
          isNot(contains('requestPermissions')),
          reason: 'the OS camera dialog must never open from brushing',
        );
        expect(permissionMethods(), ['checkPermissionStatus']);
        expect(permissionCalls.single.arguments, cameraPermission);
      });
    }

    test('granted -> no OS dialog, goes on to look for a camera', () async {
      statusResult = granted;
      final camera = CameraService();

      // No camera on the test host: init fails, but not as a refusal.
      expect(await camera.initialize(), isFalse);

      expect(camera.permissionDenied, isFalse);
      expect(permissionMethods(), ['checkPermissionStatus']);
    });
  });
}
