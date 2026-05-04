/**
 * Brush Quest Cloud Functions.
 *
 * `revokeAppleToken` is invoked by `AuthService.deleteAccount()` BEFORE
 * Firebase Auth user deletion. It calls Apple's `auth/revoke` endpoint to
 * invalidate the Apple Sign-In refresh token — Firebase deleteUser does NOT
 * propagate to Apple, so without this the user keeps appearing in
 * Settings → Apple ID → Apps Using Apple ID. Apple flags that as a
 * Guideline 5.1.1(v) violation at App Review.
 *
 * Config (set via `firebase functions:secrets:set` and functions/.env.<project>):
 *   APPLE_SIWA_KEY_P8     — secret, contents of the .p8 private key
 *   APPLE_SIWA_KEY_ID     — env, Key ID from developer.apple.com → Keys
 *   APPLE_SIWA_TEAM_ID    — env, Team ID from developer.apple.com → Membership
 *   APPLE_SIWA_CLIENT_ID  — env, app's bundle ID (com.brushquest.brushQuest)
 *
 * 2nd Gen functions: onCall is from firebase-functions/v2/https. Client-side
 * `httpsCallable` from the cloud_functions Flutter plugin works identically.
 *
 * See:
 * - docs/ios-port/PLAN.md task 2A-3
 * - https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions/v2');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

admin.initializeApp();

const APPLE_SIWA_KEY_P8 = defineSecret('APPLE_SIWA_KEY_P8');

exports.revokeAppleToken = onCall(
  {
    secrets: [APPLE_SIWA_KEY_P8],
    region: 'us-central1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'revokeAppleToken requires an authenticated caller.',
      );
    }

    const keyId = process.env.APPLE_SIWA_KEY_ID;
    const teamId = process.env.APPLE_SIWA_TEAM_ID;
    const clientId = process.env.APPLE_SIWA_CLIENT_ID;
    const privateKey = APPLE_SIWA_KEY_P8.value();

    if (!keyId || !teamId || !clientId || !privateKey) {
      throw new HttpsError(
        'failed-precondition',
        'Apple SIWA config missing — see PLAN.md task 2A-3.',
      );
    }

    const data = request.data || {};
    const tokenToRevoke = data.authorizationCode || data.refreshToken;
    if (!tokenToRevoke) {
      throw new HttpsError(
        'invalid-argument',
        'authorizationCode or refreshToken is required.',
      );
    }
    const tokenTypeHint = data.authorizationCode ? 'access_token' : 'refresh_token';

    const clientSecret = jwt.sign({}, privateKey, {
      algorithm: 'ES256',
      issuer: teamId,
      subject: clientId,
      audience: 'https://appleid.apple.com',
      expiresIn: 3600,
      notBefore: 0,
      header: { alg: 'ES256', kid: keyId },
    });

    const params = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token: tokenToRevoke,
      token_type_hint: tokenTypeHint,
    });

    const res = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    if (!res.ok) {
      const body = await res.text();
      logger.error('Apple revoke failed', {
        status: res.status,
        body,
        uid: request.auth.uid,
      });
      throw new HttpsError(
        'internal',
        `Apple revoke failed: ${res.status}`,
      );
    }

    return { revoked: true };
  },
);
