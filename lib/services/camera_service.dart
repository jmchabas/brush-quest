import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:permission_handler/permission_handler.dart';

/// Callback with motion intensity 0.0 (still) to 1.0 (fast movement)
typedef MotionCallback = void Function(double intensity);

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _initialized = false;
  bool _initFailed = false;
  bool _permissionDenied = false;
  bool _streamingMotion = false;

  // Motion detection state
  Uint8List? _previousFrame;
  static const int _sampleSize = 32; // Downsample to 32x32
  double _motionIntensity = 0.0;
  MotionCallback? _motionCallback;

  bool get isAvailable =>
      _initialized && !_initFailed && !_permissionDenied && _controller != null;
  bool get permissionDenied => _permissionDenied;
  CameraController? get controller => _controller;
  double get motionIntensity => _motionIntensity;

  /// Check camera permission, then initialize the front camera.
  /// Returns true if camera is ready, false if permission is missing or no
  /// camera.
  ///
  /// Only CHECKS the permission, never asks for it: this runs at brush start
  /// while the child holds the phone. The OS camera dialog belongs to the
  /// parent-gated flows (onboarding camera page, Settings) only.
  Future<bool> initialize() async {
    if (_initialized && !_initFailed) return isAvailable;

    // Reset state for retry
    _initialized = true;
    _initFailed = false;
    _permissionDenied = false;

    try {
      // Step 1: Check (never request) camera permission
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        _permissionDenied = true;
        _initFailed = true;
        return false;
      }

      // Step 2: Find available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _initFailed = true;
        return false;
      }

      // Step 3: Find front camera (prefer front, fallback to any)
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Step 4: Initialize camera controller
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low, // Low res is enough — we downsample to 32x32
        // Must stay false: ios/Runner/Info.plist's NSMicrophoneUsageDescription
        // promises the microphone is never used or requested.
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      return true;
    } on Exception catch (_) {
      _initFailed = true;
      unawaited(_controller?.dispose());
      _controller = null;
      return false;
    }
  }

  /// Start processing camera frames for motion detection.
  /// [onMotion] fires ~10 times/sec with intensity 0.0-1.0.
  void startMotionDetection(MotionCallback onMotion) {
    if (!isAvailable || _streamingMotion) return;
    _motionCallback = onMotion;
    _previousFrame = null;
    _motionIntensity = 0.0;
    _streamingMotion = true;

    int frameSkip = 0;
    _controller!.startImageStream((CameraImage image) {
      // Process every 3rd frame (~10fps from typical 30fps camera)
      frameSkip++;
      if (frameSkip % 3 != 0) return;

      final intensity = _processFrame(image);
      _motionIntensity = intensity;
      _motionCallback?.call(intensity);
    });
  }

  /// Stop motion detection and image stream.
  void stopMotionDetection() {
    if (!_streamingMotion || !isAvailable) return;
    _streamingMotion = false;
    _motionCallback = null;
    _previousFrame = null;
    _motionIntensity = 0.0;
    try {
      _controller?.stopImageStream();
    } on Exception catch (_) {}
  }

  /// Downsample a luma (Y) plane to [size] x [size] grayscale samples.
  ///
  /// Rows are addressed with [bytesPerRow] (the row stride), NOT [width]:
  /// iOS delivers ImageFormatGroup.yuv420 as a 2-plane
  /// kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange buffer whose plane 0
  /// (luma) rows are usually padded past the pixel width, and Android
  /// YUV_420_888 planes can be padded too. Padding bytes are never sampled.
  /// Orientation and front-camera mirroring don't matter: motion is a sum of
  /// per-sample differences between consecutive frames.
  @visibleForTesting
  static Uint8List sampleLuma(
    Uint8List bytes, {
    required int width,
    required int height,
    required int bytesPerRow,
    int size = _sampleSize,
  }) {
    final sampled = Uint8List(size * size);
    if (width <= 0 || height <= 0) return sampled;
    final double stepX = width / size;
    final double stepY = height / size;

    for (int sy = 0; sy < size; sy++) {
      final int srcY = (sy * stepY).toInt().clamp(0, height - 1);
      for (int sx = 0; sx < size; sx++) {
        final int srcX = (sx * stepX).toInt().clamp(0, width - 1);
        final int index = srcY * bytesPerRow + srcX;
        sampled[sy * size + sx] = index < bytes.length ? bytes[index] : 0;
      }
    }
    return sampled;
  }

  /// Process a single camera frame: downsample Y plane to 32x32,
  /// compare with previous frame, return motion intensity 0.0-1.0.
  double _processFrame(CameraImage image) {
    if (image.planes.isEmpty) return 0.0;

    // Y plane (luminance/grayscale) is the first plane in YUV420
    final yPlane = image.planes[0];
    final sampled = sampleLuma(
      yPlane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: yPlane.bytesPerRow,
    );

    if (_previousFrame == null) {
      _previousFrame = sampled;
      return 0.0;
    }

    // Sum absolute differences
    int totalDiff = 0;
    for (int i = 0; i < sampled.length; i++) {
      totalDiff += (sampled[i] - _previousFrame![i]).abs();
    }

    _previousFrame = sampled;

    // Normalize: max possible diff = 255 * 1024 pixels = 261120
    // Typical brushing motion range: 0-40000 for noticeable movement
    // Map to 0.0-1.0 with a practical ceiling
    final normalized = (totalDiff / 25000.0).clamp(0.0, 1.0);

    // Smooth with exponential moving average
    return _motionIntensity * 0.3 + normalized * 0.7;
  }

  void dispose() {
    stopMotionDetection();
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initFailed = false;
    _permissionDenied = false;
  }
}
