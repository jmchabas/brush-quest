import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether Apple Sign-In is available (iOS only).
  bool get isAppleSignInAvailable => Platform.isIOS;

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
      if (e.toString().contains('reauth failed') ||
          e.toString().contains('canceled')) {
        try {
          await GoogleSignIn.instance.disconnect();
        } on Exception catch (_) {}
        try {
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

  Future<User?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      final authResult = await _auth.signInWithCredential(oauthCredential);

      // Apple only sends the name on the FIRST sign-in. Persist it.
      final user = authResult.user;
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        final givenName = appleCredential.givenName ?? '';
        final familyName = appleCredential.familyName ?? '';
        final fullName = '$givenName $familyName'.trim();
        if (fullName.isNotEmpty) {
          await user.updateDisplayName(fullName);
          await user.reload();
        }
      }

      return _auth.currentUser;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('Apple sign-in authorization error: $e');
      return null;
    } on Exception catch (e) {
      debugPrint('Apple sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    // Only disconnect Google if the user signed in via Google.
    final isGoogleProvider =
        _auth.currentUser?.providerData.any(
          (info) => info.providerId == 'google.com',
        ) ??
        false;

    if (isGoogleProvider) {
      await _ensureGoogleInit();
      await GoogleSignIn.instance.signOut();
    }

    await _auth.signOut();
  }

  /// Generate a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
