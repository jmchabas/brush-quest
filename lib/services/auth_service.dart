import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureGoogleInit() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '722700244830-5ou3ilo0nuq0a71jb92uiaempif5ki24.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }

  Future<User?> signInWithGoogle() async {
    await _ensureGoogleInit();

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final authResult = await _auth.signInWithCredential(credential);
      return authResult.user;
    } on Exception catch (e) {
      // If reauth fails (stale cached token), disconnect and retry fresh
      if (e.toString().contains('reauth failed') ||
          e.toString().contains('canceled')) {
        try {
          await GoogleSignIn.instance.disconnect();
        } on Exception catch (_) {}
        try {
          // Retry with a clean slate
          final account = await GoogleSignIn.instance.authenticate();
          final idToken = account.authentication.idToken;
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          final authResult = await _auth.signInWithCredential(credential);
          return authResult.user;
        } on Exception catch (_) {
          return null;
        }
      }
      debugPrint('Unexpected sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _ensureGoogleInit();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
