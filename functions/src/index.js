/**
 * Brush Quest Cloud Functions.
 *
 * `revokeAppleToken` is invoked by `AuthService.deleteAccount()` BEFORE
 * Firebase Auth user deletion. It revokes the user's Apple Sign-In refresh
 * token at Apple — Firebase deleteUser does NOT propagate to Apple, so
 * without this the user keeps appearing in Settings → Apple ID → Apps
 * Using Apple ID. Apple flags that as a Guideline 5.1.1(v) violation at
 * App Review.
 *
 * The client may pass either:
 *   - `authorizationCode` (one-time, ~5 min lifetime, what the iOS plugin
 *     `sign_in_with_apple` returns at sign-in). The function exchanges it
 *     for a refresh token via Apple's `/auth/token`, then revokes.
 *   - `refreshToken` (long-lived, if the client cached one). Goes
 *     directly to `/auth/revoke`.
 *
 * Firebase Auth requires re-authentication for `user.delete()` (throws
 * `requires-recent-login` after ~5 min). So in practice, by the time
 * deleteAccount() reaches us, the user has just signed in fresh and the
 * authorization code is valid.
 *
 * Config:
 *   APPLE_SIWA_KEY_P8     — secret, contents of the .p8 private key
 *   APPLE_SIWA_KEY_ID     — env, Key ID from developer.apple.com → Keys
 *   APPLE_SIWA_TEAM_ID    — env, Team ID from developer.apple.com → Membership
 *   APPLE_SIWA_CLIENT_ID  — env, app's bundle ID (com.brushquest.brushQuest)
 *
 * 2nd Gen functions: client-side `httpsCallable` from the cloud_functions
 * Flutter plugin works identically to v1.
 *
 * See:
 * - docs/ios-port/PLAN.md task 2A-3
 * - https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens
 * - https://developer.apple.com/documentation/sign_in_with_apple/generate_and_validate_tokens
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions/v2');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

admin.initializeApp();

const APPLE_SIWA_KEY_P8 = defineSecret('APPLE_SIWA_KEY_P8');

const APPLE_TOKEN_URL = 'https://appleid.apple.com/auth/token';
const APPLE_REVOKE_URL = 'https://appleid.apple.com/auth/revoke';

function buildClientSecret({ teamId, clientId, keyId, privateKey }) {
  return jwt.sign({}, privateKey, {
    algorithm: 'ES256',
    issuer: teamId,
    subject: clientId,
    audience: 'https://appleid.apple.com',
    expiresIn: 3600,
    notBefore: 0,
    header: { alg: 'ES256', kid: keyId },
  });
}

async function exchangeCodeForRefreshToken({ authorizationCode, clientId, clientSecret }) {
  const params = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: 'authorization_code',
  });
  const res = await fetch(APPLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });
  if (!res.ok) {
    const body = await res.text();
    logger.error('Apple /auth/token exchange failed', { status: res.status, body });
    throw new HttpsError(
      'internal',
      `Apple token exchange failed: ${res.status}`,
    );
  }
  const json = await res.json();
  if (!json.refresh_token) {
    logger.error('Apple /auth/token returned no refresh_token', { keys: Object.keys(json) });
    throw new HttpsError('internal', 'Apple did not return a refresh_token.');
  }
  return json.refresh_token;
}

async function revokeRefreshToken({ refreshToken, clientId, clientSecret }) {
  const params = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  });
  const res = await fetch(APPLE_REVOKE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });
  if (!res.ok) {
    const body = await res.text();
    logger.error('Apple /auth/revoke failed', { status: res.status, body });
    throw new HttpsError('internal', `Apple revoke failed: ${res.status}`);
  }
}

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
    if (!data.authorizationCode && !data.refreshToken) {
      throw new HttpsError(
        'invalid-argument',
        'authorizationCode or refreshToken is required.',
      );
    }

    const clientSecret = buildClientSecret({ teamId, clientId, keyId, privateKey });

    let refreshToken = data.refreshToken;
    if (!refreshToken) {
      refreshToken = await exchangeCodeForRefreshToken({
        authorizationCode: data.authorizationCode,
        clientId,
        clientSecret,
      });
    }

    await revokeRefreshToken({ refreshToken, clientId, clientSecret });

    return { revoked: true };
  },
);
