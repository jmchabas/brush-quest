#!/usr/bin/env bash
# Cyclepro Fitness Gates
# Run: bash scripts/fitness-gates.sh [--economy-guard]
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0

gate_pass() { echo -e "  ${GREEN}PASS${NC} -- $1"; ((PASS++)) || true; }
gate_fail() { echo -e "  ${RED}FAIL${NC} -- $1"; ((FAIL++)) || true; }

# Resolve project root (script lives in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================="
echo "  Cyclepro Fitness Gates"
echo "======================================="
echo ""

# ─────────────────────────────────────────
# Gate 1: Voice Coverage
# Every kid-facing screen must have at least one playVoice call.
# ─────────────────────────────────────────
echo "Gate 1: Voice Coverage"

MISSING_VOICE=()
for screen in "$PROJECT_ROOT"/lib/screens/*.dart; do
  basename_file="$(basename "$screen")"
  # Skip parent-facing screens
  [[ "$basename_file" == "settings_screen.dart" ]] && continue
  if ! grep -q 'playVoice' "$screen"; then
    MISSING_VOICE+=("$basename_file")
  fi
done

if [ ${#MISSING_VOICE[@]} -eq 0 ]; then
  gate_pass "All kid-facing screens have playVoice calls"
else
  gate_fail "Screens missing playVoice: ${MISSING_VOICE[*]}"
fi
echo ""

# ─────────────────────────────────────────
# Gate 2: Voice Asset Integrity
# Every literal audio file referenced in code must exist on disk and be non-zero bytes.
# ─────────────────────────────────────────
echo "Gate 2: Voice Asset Integrity"

MISSING_ASSETS=()
EMPTY_ASSETS=()

# Extract literal filenames from playVoice('...') and playSfx('...')
# Only match single-quoted string literals without $ (skip interpolated strings)
AUDIO_FILES=$(grep -roh "play\(Voice\|Sfx\)('[^'\$]*')" "$PROJECT_ROOT/lib/" 2>/dev/null \
  | grep -oh "'[^']*'" \
  | tr -d "'" \
  | sort -u) || true

for file in $AUDIO_FILES; do
  [ -z "$file" ] && continue

  found=false

  # Voice files (start with voice_) are in voices/<style>/ subdirectories
  if [[ "$file" == voice_* ]]; then
    for voice_dir in "$PROJECT_ROOT"/assets/audio/voices/*/; do
      if [ -f "${voice_dir}${file}" ]; then
        # Check non-zero
        fsize=$(stat -f %z "${voice_dir}${file}" 2>/dev/null || echo "0")
        if [ "$fsize" -eq 0 ]; then
          EMPTY_ASSETS+=("voices/$(basename "$voice_dir")/$file")
        fi
        found=true
        break
      fi
    done
  else
    # SFX / music files are directly under assets/audio/
    if [ -f "$PROJECT_ROOT/assets/audio/$file" ]; then
      fsize=$(stat -f %z "$PROJECT_ROOT/assets/audio/$file" 2>/dev/null || echo "0")
      if [ "$fsize" -eq 0 ]; then
        EMPTY_ASSETS+=("$file")
      fi
      found=true
    fi
    # Also check assets/audio/sfx/ subdirectory
    if [ -f "$PROJECT_ROOT/assets/audio/sfx/$file" ]; then
      fsize=$(stat -f %z "$PROJECT_ROOT/assets/audio/sfx/$file" 2>/dev/null || echo "0")
      if [ "$fsize" -eq 0 ]; then
        EMPTY_ASSETS+=("sfx/$file")
      fi
      found=true
    fi
  fi

  if [ "$found" = false ]; then
    MISSING_ASSETS+=("$file")
  fi
done

if [ ${#MISSING_ASSETS[@]} -eq 0 ] && [ ${#EMPTY_ASSETS[@]} -eq 0 ]; then
  gate_pass "All referenced audio files exist and are non-zero"
else
  details=""
  if [ ${#MISSING_ASSETS[@]} -gt 0 ]; then
    details="Missing: ${MISSING_ASSETS[*]}"
  fi
  if [ ${#EMPTY_ASSETS[@]} -gt 0 ]; then
    [ -n "$details" ] && details="$details; "
    details="${details}Empty: ${EMPTY_ASSETS[*]}"
  fi
  gate_fail "$details"
fi
echo ""

# ─────────────────────────────────────────
# Gate 3: Interactive Feedback
# Every kid-facing screen/widget with tap handlers must also have audio or haptic feedback.
# ─────────────────────────────────────────
echo "Gate 3: Interactive Feedback"

NO_FEEDBACK=()
for dart_file in "$PROJECT_ROOT"/lib/screens/*.dart "$PROJECT_ROOT"/lib/widgets/*.dart; do
  basename_file="$(basename "$dart_file")"
  # Skip parent-facing screens
  [[ "$basename_file" == "settings_screen.dart" ]] && continue

  # Check if file has interactive handlers
  if grep -qE 'onTap|onPressed|onTapDown|onTapUp' "$dart_file"; then
    # Check if file has any feedback mechanism
    if ! grep -qE 'playSfx|playVoice|HapticFeedback' "$dart_file"; then
      NO_FEEDBACK+=("$basename_file")
    fi
  fi
done

if [ ${#NO_FEEDBACK[@]} -eq 0 ]; then
  gate_pass "All interactive kid-facing files have audio/haptic feedback"
else
  gate_fail "Files with handlers but no feedback: ${NO_FEEDBACK[*]}"
fi
echo ""

# ─────────────────────────────────────────
# Gate 4: COPPA Dependency Scan
# Every pubspec.yaml dependency must be on the COPPA allowlist.
# ─────────────────────────────────────────
echo "Gate 4: COPPA Dependency Scan"

ALLOWLIST_FILE="$PROJECT_ROOT/docs/coppa-allowlist.txt"

if [ ! -f "$ALLOWLIST_FILE" ]; then
  gate_fail "Allowlist file not found: docs/coppa-allowlist.txt"
else
  # Extract allowed package names (non-blank, non-comment lines, first word)
  ALLOWED=()
  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    pkg=$(echo "$line" | awk '{print $1}')
    ALLOWED+=("$pkg")
  done < "$ALLOWLIST_FILE"

  # Extract dependencies from pubspec.yaml
  # Read lines between 'dependencies:' and the next top-level key
  IN_DEPS=false
  UNLISTED=()
  while IFS= read -r line; do
    # Detect start of dependencies block
    if [[ "$line" == "dependencies:" ]]; then
      IN_DEPS=true
      continue
    fi
    # Detect end of dependencies block (next top-level key — no leading whitespace)
    if $IN_DEPS && [[ "$line" =~ ^[a-z] ]]; then
      IN_DEPS=false
      continue
    fi
    if $IN_DEPS; then
      # Skip blank lines, comments, sdk/path deps
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ sdk: ]] && continue
      [[ "$line" =~ path: ]] && continue

      # Extract package name: indented lines like "  package_name: version" or "  package_name:"
      pkg=$(echo "$line" | awk '{print $1}' | tr -d ':')
      [ -z "$pkg" ] && continue

      # Skip YAML keys that aren't packages
      [[ "$pkg" == "flutter" || "$pkg" == "sdk" ]] && continue

      # Check against allowlist
      found_in_list=false
      for allowed_pkg in "${ALLOWED[@]}"; do
        if [[ "$pkg" == "$allowed_pkg" ]]; then
          found_in_list=true
          break
        fi
      done

      if [ "$found_in_list" = false ]; then
        UNLISTED+=("$pkg")
      fi
    fi
  done < "$PROJECT_ROOT/pubspec.yaml"

  if [ ${#UNLISTED[@]} -eq 0 ]; then
    gate_pass "All dependencies are on the COPPA allowlist"
  else
    gate_fail "Dependencies not on allowlist: ${UNLISTED[*]}"
  fi
fi
echo ""

# ─────────────────────────────────────────
# Gate 5: Economy Guard (only with --economy-guard flag)
# Check if economy-related values were modified vs the merge base with main.
# ─────────────────────────────────────────
if [[ "${1:-}" == "--economy-guard" ]]; then
  echo "Gate 5: Economy Guard"

  ECONOMY_FILES=(
    "lib/services/hero_service.dart"
    "lib/services/weapon_service.dart"
    "lib/services/streak_service.dart"
    "lib/services/world_service.dart"
  )
  ECONOMY_KEYWORDS="unlockAt|earnRate|starCost|bonusStars|dailyBonus"

  # Find merge base with main
  MERGE_BASE=$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || echo "")

  if [ -z "$MERGE_BASE" ]; then
    echo -e "  ${YELLOW}SKIP${NC} -- Could not determine merge base with main"
  else
    CHANGED_ECONOMY=()
    for efile in "${ECONOMY_FILES[@]}"; do
      full_path="$PROJECT_ROOT/$efile"
      [ ! -f "$full_path" ] && continue

      # Check if file was modified since merge base
      diff_output=$(git -C "$PROJECT_ROOT" diff "$MERGE_BASE" -- "$efile" 2>/dev/null || echo "")
      if [ -n "$diff_output" ]; then
        # Check if diff contains economy keywords
        if echo "$diff_output" | grep -qE "$ECONOMY_KEYWORDS"; then
          CHANGED_ECONOMY+=("$efile")
        fi
      fi
    done

    if [ ${#CHANGED_ECONOMY[@]} -eq 0 ]; then
      gate_pass "No economy values modified since merge base"
    else
      gate_fail "Economy values changed in: ${CHANGED_ECONOMY[*]}"
    fi
  fi
  echo ""
fi

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo "======================================="
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "======================================="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
