#!/bin/bash
# Deploy latest code to Google Play Internal Testing
# Usage: ./scripts/deploy-internal.sh [--no-pull]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

echo "=== Brush Quest: Deploy to Internal Testing ==="

# 1. Pull latest (unless --no-pull)
if [[ "${1:-}" != "--no-pull" ]]; then
  echo ">> Pulling latest from main..."
  git pull origin main
fi

# 2. Bump version code
CURRENT_VERSION=$(grep 'version:' pubspec.yaml | head -1 | sed 's/.*+//')
NEW_VERSION=$((CURRENT_VERSION + 1))
BASE_VERSION=$(grep 'version:' pubspec.yaml | head -1 | sed 's/version: //' | sed 's/+.*//')
echo ">> Bumping version: ${BASE_VERSION}+${CURRENT_VERSION} -> ${BASE_VERSION}+${NEW_VERSION}"
sed -i '' "s/version: ${BASE_VERSION}+${CURRENT_VERSION}/version: ${BASE_VERSION}+${NEW_VERSION}/" pubspec.yaml

# 3. Build AAB
echo ">> Building release AAB..."
flutter build appbundle --release

# 4. Write changelog for fastlane
CHANGELOG_DIR="android/fastlane/metadata/android/en-US/changelogs"
mkdir -p "$CHANGELOG_DIR"
# Use the latest commit message as release notes
git log -1 --pretty=format:"%s" > "${CHANGELOG_DIR}/${NEW_VERSION}.txt"
echo "" >> "${CHANGELOG_DIR}/${NEW_VERSION}.txt"

# 5. Upload via fastlane
echo ">> Uploading to Play Store (internal testing)..."
cd android
fastlane internal
cd ..

echo "=== Done! Release ${BASE_VERSION}+${NEW_VERSION} deployed to internal testing ==="
