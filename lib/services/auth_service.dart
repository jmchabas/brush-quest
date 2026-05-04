// CYCLE-PROTECT: This file contains iOS-conditional code (Sign in with Apple).
// Do not auto-remove "unused" imports, methods, or branches without verifying
// `flutter build ios --no-codesign` still succeeds. See docs/ios-port/PLAN.md.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _appleAuthCodePrefsKey = 'apple_authorization_code';

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

      // Cache the authorization code so deleteAccount() can revoke the
      // refresh token at Apple per Guideline 5.1.1(v). The code is one-time
      // and short-lived (~5 min), but Firebase Auth requires-recent-login
      // forces a fresh sign-in immediately before user.delete(), so the
      // cached code is fresh by the time deleteAccount() reads it.
      final code = appleCredential.authorizationCode;
      if (code.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_appleAuthCodePrefsKey, code);
      }

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

  /// Delete the signed-in user's account per Apple Guideline 5.1.1(v) and
  /// COPPA parental rights. Pipeline order:
  ///   1. Revoke Apple SIWA refresh token server-side (TODO until 2A-3 — the
  ///      `revokeAppleToken` Cloud Function is currently stubbed). Apple
  ///      requires this for SIWA users; Firebase `user.delete()` does NOT do
  ///      it. Phase 2 wires the real call.
  ///   2. Delete `/users/{uid}` Firestore document (cloud progress).
  ///   3. Delete the Firebase Auth user (`user.delete()`).
  ///   4. Clear local `SharedPreferences` except `onboarding_completed`
  ///      (kept so the child isn't forced through the tutorial again).
  ///
  /// Throws on the FIRST step that fails so the caller can surface an
  /// actionable error and leave local data intact for retry. Local clear is
  /// only reached if the auth user is gone — the destructive promise of
  /// "delete account" is honored only when both cloud sides succeed.
  ///
  /// `FirebaseAuthException(code: 'requires-recent-login')` is the most
  /// likely failure on step 3 — the caller should sign out + sign in again
  /// and retry. See docs/ios-port/delete-account-ux.md.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to delete.');
    }

    final isAppleUser = user.providerData.any(
      (p) => p.providerId == 'apple.com',
    );

    // 1. Apple SIWA token revoke. Best-effort: log + continue on failure
    //    so a stale auth code or Apple outage doesn't block local cleanup
    //    of the user's data. The fresh-code precondition is met because
    //    Firebase Auth's requires-recent-login forces a sign-in within
    //    ~5 min before step 3.
    if (isAppleUser) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final authCode = prefs.getString(_appleAuthCodePrefsKey);
        if (authCode != null && authCode.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('revokeAppleToken')
              .call({'authorizationCode': authCode});
        } else {
          debugPrint('Apple revoke skipped — no cached authorization code.');
        }
      } on Exception catch (e) {
        debugPrint('Apple revoke failed (continuing with delete): $e');
      }
    }

    // 2. Delete /users/{uid} Firestore document.
    final uid = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();

    // 3. Delete the Firebase Auth user. Throws on requires-recent-login.
    await user.delete();

    // 4. Clear local SharedPreferences. Keep onboarding flag so the kid
    //    isn't forced through the tutorial again.
    final prefs = await SharedPreferences.getInstance();
    const keysToKeep = {'onboarding_completed'};
    final allKeys = prefs.getKeys().toList();
    for (final key in allKeys) {
      if (!keysToKeep.contains(key)) {
        await prefs.remove(key);
      }
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
