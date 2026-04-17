# Sign in with Apple — Design Spec

> Created: 2026-04-17
> Status: Approved
> Trigger: Apple App Store Guideline 4.8 — must offer Sign in with Apple alongside Google Sign-In

## Summary

Add "Sign in with Apple" as a second auth provider on iOS. Hidden on Android. Firebase Auth handles both providers identically — same UID system, same Firestore sync, no code changes needed downstream.

## Constraints

- Apple Human Interface Guidelines mandate official button styling (black/white, specific shape)
- Apple Sign-In requires entitlements in Xcode project
- Cannot be tested end-to-end until Apple Developer account + provisioning profile exist
- No credential linking for v1 (user picks one provider per device)

## Changes

### 1. `pubspec.yaml`

Add dependencies:
```yaml
sign_in_with_apple: ^6.1.0
crypto: ^3.0.6
```

### 2. `lib/services/auth_service.dart`

Add `signInWithApple()` method:
- Generate secure random nonce (32 bytes)
- SHA256 hash the nonce for Apple's API
- Request Apple ID credential via `SignInWithApple.getAppleIDCredential()`
  - Scopes: `[AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]`
  - Nonce: raw nonce passed to Apple
- Create `OAuthProvider('apple.com').credential(idToken:, rawNonce:)`
- `_auth.signInWithCredential(credential)` → returns `User`
- Return null on cancel/error (same pattern as Google)

Update `signOut()`:
- Check `currentUser?.providerData` for provider ID
- Only call `GoogleSignIn.instance.signOut()` if provider is `google.com`
- Always call `_auth.signOut()`

### 3. `lib/screens/settings_screen.dart`

When **not signed in**:
- On iOS: two stacked buttons
  - **Sign in with Apple** (top) — official black button per Apple HIG
  - **Sign in with Google** (bottom) — existing blue button
- On Android: Google button only (unchanged)

Split `_handleSignIn()` into:
- `_handleGoogleSignIn()` — existing logic, extracted
- `_handleAppleSignIn()` — calls `_auth.signInWithApple()`, same post-flow (consent dialog, smartSync, snackbar, reload)

Platform check: `dart:io` `Platform.isIOS` to conditionally render Apple button.

### 4. `ios/Runner/Runner.entitlements`

Create entitlements file with:
```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
```

### 5. Files NOT changed

- `sync_service.dart` — already provider-agnostic (uses `user.uid`)
- `victory_screen.dart` — already checks `currentUser != null`
- Firestore rules — already use `{uid}` path, not provider-specific
- `analytics_service.dart` — `logSignIn()` already provider-agnostic

## UI Layout (iOS, signed out)

```
┌──────────────────────────────┐
│  ┌────────────────────────┐  │
│  │  ⬛ Sign in with Apple │  │  ← Official Apple button (black bg, white text)
│  └────────────────────────┘  │
│         8px spacing          │
│  ┌────────────────────────┐  │
│  │  🔵 Sign in with Google│  │  ← Existing Google button (blue gradient)
│  └────────────────────────┘  │
│                              │
│  Save your progress to the   │
│  cloud                       │
└──────────────────────────────┘
```

## UI Layout (Android, signed out)

```
┌──────────────────────────────┐
│  ┌────────────────────────┐  │
│  │  🔵 Sign in with Google│  │  ← Unchanged from today
│  └────────────────────────┘  │
│                              │
│  Save your progress to the   │
│  cloud                       │
└──────────────────────────────┘
```

## Testing

- `auth_service.dart` — unit test: `signInWithApple()` exists, returns `User?`
- `settings_screen.dart` — widget test: Apple button appears on iOS, hidden on Android
- End-to-end auth flow: blocked until Apple Developer provisioning exists
- Google Sign-In on Android: must remain unchanged (regression check)

## Future (not in scope)

- Credential linking (sign in with both providers, merge into one UID)
- Apple Sign-In on Android (web OAuth flow — clunky, low value)
- "Delete my account" via Apple (required within 30 days of rejection if Apple asks)
