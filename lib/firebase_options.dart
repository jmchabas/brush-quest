// PLACEHOLDER — will be replaced by `flutterfire configure`
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPW2YvhSRZt_WV2dpJo9ol5TtHPspTXlY',
    appId: '1:722700244830:android:4c853fb0ff20d0bf07a1cf',
    messagingSenderId: '722700244830',
    projectId: 'brush-quest',
    storageBucket: 'brush-quest.firebasestorage.app',
  );
}
