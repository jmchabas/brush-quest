#!/usr/bin/env bash
# Apple Kids Category binary gate for Brush Quest iOS.
#
# Fails (exit 1) if any analytics / crash-reporting / advertising-identifier
# SDK code is present anywhere in an iOS build: the main Runner executable AND
# every Mach-O under Frameworks/ and PlugIns/. Looking for framework folders is
# NOT enough: builds 21-26 passed a folder check while GoogleAppMeasurement,
# APMIdentity (IDFA), GoogleAdsOnDeviceConversion and Crashlytics were
# statically linked into Runner. See memory decision_ios_kids_category.md and
# packages/firebase_analytics/README.md.
#
# Usage:
#   scripts/check_ios_kids_binary.sh                      # build/ios/iphoneos/Runner.app
#   scripts/check_ios_kids_binary.sh path/to/Runner.app
#   scripts/check_ios_kids_binary.sh build/ios/ipa/brush_quest.ipa
#   scripts/check_ios_kids_binary.sh build/ios/archive/Runner.xcarchive
#
# Exit codes: 0 = clean, 1 = forbidden strings found, 2 = usage / input error.

set -euo pipefail

# Case-sensitive fixed strings. Chosen to match SDK code (class names, log
# tags, endpoints, CocoaPods dummy symbols), not ordinary English words.
FORBIDDEN_TOKENS=(
  AppMeasurement
  GoogleAppMeasurement
  APMMeasurement
  APMIdentity
  ASIdentifierManager
  advertisingIdentifier
  ATTrackingManager
  GoogleAdsOnDeviceConversion
  app-measurement.com
  app-analytics-services.com
  PodsDummy_FirebaseAnalytics
  FirebaseAnalyticsPlugin
  FIRCrashlytics
  FirebaseCrashlytics
  X-Crashlytics
  crashlytics
  firebase-settings
)

# Known-benign hits, as "<path relative to the .app>|<token>". Keep this list
# tiny and justified; every entry is printed on each run.
#  - GoogleUtilities/Network (needed by FirebaseAuth / GoogleSignIn via
#    GoogleUtilities/AppDelegateSwizzler) hard-codes its default reachability
#    host: GULNetworkConstants.m `kGULNetworkReachabilityHost =
#    @"app-measurement.com"`. It is a string constant in a shared utility
#    library, not the Analytics SDK.
ALLOWED_HITS=(
  "Frameworks/GoogleUtilities.framework/GoogleUtilities|app-measurement.com"
)

usage() {
  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$REPO_ROOT/build/ios/iphoneos/Runner.app}"
TARGET="${TARGET%/}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/kids_binary_check.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

case "$TARGET" in
  *.ipa)
    [[ -f "$TARGET" ]] || { echo "error: IPA not found: $TARGET" >&2; exit 2; }
    unzip -q "$TARGET" -d "$WORK/ipa"
    APP="$(find "$WORK/ipa/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1)"
    ;;
  *.xcarchive)
    APP="$(find "$TARGET/Products/Applications" -maxdepth 1 -type d -name '*.app' 2>/dev/null | head -n 1)"
    ;;
  *)
    APP="$TARGET"
    ;;
esac

if [[ -z "${APP:-}" || ! -d "$APP" ]]; then
  echo "error: .app bundle not found for: $TARGET" >&2
  echo "Build first: flutter build ios --release --no-codesign" >&2
  exit 2
fi

is_allowed() { # $1 = relative path, $2 = token
  local entry
  for entry in "${ALLOWED_HITS[@]}"; do
    [[ "$entry" == "$1|$2" ]] && return 0
  done
  return 1
}

# Candidate files: top level of the bundle (main executable) + everything under
# Frameworks/ and PlugIns/, skipping Flutter's asset directory.
BINARIES="$WORK/binaries.txt"
: > "$BINARIES"
while IFS= read -r f; do
  if file -b "$f" | grep -q 'Mach-O'; then
    echo "$f" >> "$BINARIES"
  fi
done < <(
  find "$APP" -maxdepth 1 -type f
  for sub in Frameworks PlugIns Extensions; do
    [[ -d "$APP/$sub" ]] || continue
    find "$APP/$sub" -path '*/flutter_assets' -prune -o -type f -print
  done
)

scanned=0
hits=0
allowed=0
echo "Kids Category binary check: $APP"
while IFS= read -r bin; do
  scanned=$((scanned + 1))
  rel="${bin#"$APP"/}"
  strings -a "$bin" > "$WORK/strings.txt" 2>/dev/null || true
  for token in "${FORBIDDEN_TOKENS[@]}"; do
    if grep -qF -- "$token" "$WORK/strings.txt"; then
      sample="$(grep -F -- "$token" "$WORK/strings.txt" | head -n 1 | cut -c1-120)"
      if is_allowed "$rel" "$token"; then
        allowed=$((allowed + 1))
        echo "  allowed  $rel: '$token' (known benign, see ALLOWED_HITS) -> $sample"
      else
        hits=$((hits + 1))
        echo "  HIT      $rel: '$token' -> $sample"
      fi
    fi
  done
done < "$BINARIES"

if [[ "$scanned" -eq 0 ]]; then
  echo "error: no Mach-O binaries found in $APP" >&2
  exit 2
fi

echo "Scanned $scanned Mach-O binaries; forbidden hits: $hits; allowed: $allowed."
if [[ "$hits" -gt 0 ]]; then
  echo "FAIL: analytics / crash / ad-ID SDK code is in the iOS binary (Apple Kids Category)." >&2
  exit 1
fi
echo "PASS: no analytics, crash-reporting or advertising-identifier SDK code found."
