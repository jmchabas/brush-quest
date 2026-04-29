/**
 * Brush Quest Cloud Functions.
 *
 * Phase 1 (current): SCAFFOLD ONLY. The Apple Sign-In private key
 * (`APPLE_SIWA_KEY_P8`, `APPLE_SIWA_KEY_ID`, `APPLE_SIWA_TEAM_ID`,
 * `APPLE_SIWA_CLIENT_ID`) is filled in Phase 2 task 2A-3 after the
 * Apple Developer Program enrollment completes.
 *
 * Phase 2: deploy via `firebase deploy --only functions`. The
 * `revokeAppleToken` callable is invoked by `AuthService.deleteAccount()`
 * (plan task 1G-2) BEFORE Firebase Auth user deletion.
 *
 * See:
 * - docs/ios-port/PLAN.md tasks 1G-1..1G-4, 2A-3
 * - https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens
 * - https://firebase.google.com/docs/auth/admin/manage-users#delete_a_user
 *   (Firebase deleteUser does NOT revoke Apple tokens — they must be revoked
 *   directly with Apple via this Function. Failing to do so means the user
 *   keeps appearing in the app's Apple ID Settings → "Apps Using Apple ID"
 *   list, which Apple flags as a Guideline 5.1.1(v) violation.)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

admin.initializeApp();

/**
 * revokeAppleToken (HTTPS callable).
 * Called by AuthService.deleteAccount() before Firebase Auth user deletion.
 *
 * Input:  { authorizationCode: string }  (from the user's most recent SIWA login)
 *         OR { refreshToken: string }    (if the client cached one)
 * Output: { revoked: true } on 200 from Apple, otherwise throws HttpsError.
 *
 * Phase 2 wiring: Replace the throw below with a real implementation that
 * (1) generates a client_secret JWT signed with the Apple SIWA .p8 key,
 * (2) POSTs to https://appleid.apple.com/auth/revoke, (3) returns success.
 */
exports.revokeAppleToken = functions.https.onCall(async (data, context) => {
  // Auth gate: only an authenticated user can revoke their own token.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'revokeAppleToken requires an authenticated caller.',
    );
  }

  // TODO(2A-3): replace this stub with the real Apple revoke call.
  // The stub returns success so client-side wiring (1G-2) can be tested
  // end-to-end before Phase 2. Server-side revocation is the missing
  // piece — Apple's account-deletion compliance check happens at App
  // Store review, NOT at runtime, so a stub is safe in pre-submission
  // builds. This stub MUST be replaced before any Phase 2 TestFlight
  // build that real users can install.
  functions.logger.warn(
    'revokeAppleToken called but is a Phase-1 stub — see PLAN.md task 2A-3',
    { uid: context.auth.uid, dataKeys: Object.keys(data || {}) },
  );

  return { revoked: false, stub: true };

  /* eslint-disable no-unreachable */
  // ─── Phase 2 implementation (uncomment after 2A-3) ─────────────────
  //
  // const APPLE_KEY_ID = functions.config().apple?.siwa_key_id;
  // const APPLE_TEAM_ID = functions.config().apple?.siwa_team_id;
  // const APPLE_CLIENT_ID = functions.config().apple?.siwa_client_id; // bundle id
  // const APPLE_PRIVATE_KEY = functions.config().apple?.siwa_key_p8;  // multi-line .p8 contents
  //
  // if (!APPLE_KEY_ID || !APPLE_TEAM_ID || !APPLE_CLIENT_ID || !APPLE_PRIVATE_KEY) {
  //   throw new functions.https.HttpsError('failed-precondition',
  //     'Apple SIWA secrets not configured — see PLAN.md task 2A-3.');
  // }
  //
  // // Sign client_secret JWT.
  // const now = Math.floor(Date.now() / 1000);
  // const clientSecret = jwt.sign({}, APPLE_PRIVATE_KEY, {
  //   algorithm: 'ES256',
  //   keyid: APPLE_KEY_ID,
  //   issuer: APPLE_TEAM_ID,
  //   subject: APPLE_CLIENT_ID,
  //   audience: 'https://appleid.apple.com',
  //   expiresIn: 3600,
  //   notBefore: 0,
  //   header: { alg: 'ES256', kid: APPLE_KEY_ID },
  // });
  //
  // const tokenToRevoke = data.authorizationCode || data.refreshToken;
  // const tokenTypeHint = data.authorizationCode ? 'access_token' : 'refresh_token';
  // if (!tokenToRevoke) {
  //   throw new functions.https.HttpsError('invalid-argument',
  //     'authorizationCode or refreshToken is required.');
  // }
  //
  // const params = new URLSearchParams({
  //   client_id: APPLE_CLIENT_ID,
  //   client_secret: clientSecret,
  //   token: tokenToRevoke,
  //   token_type_hint: tokenTypeHint,
  // });
  //
  // const res = await fetch('https://appleid.apple.com/auth/revoke', {
  //   method: 'POST',
  //   headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  //   body: params.toString(),
  // });
  //
  // if (!res.ok) {
  //   const body = await res.text();
  //   throw new functions.https.HttpsError('internal',
  //     `Apple revoke failed: ${res.status} ${body}`);
  // }
  //
  // return { revoked: true };
  /* eslint-enable no-unreachable */
});
