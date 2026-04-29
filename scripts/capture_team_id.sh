#!/usr/bin/env bash
# capture_team_id.sh — pre-staged for Phase 2A-2 of the iOS port.
#
# Day-of usage (after Apple Developer Program enrollment is paid + Team ID assigned):
#
#     bash scripts/capture_team_id.sh ABC1234567
#
# Where ABC1234567 is the 10-char alphanumeric Apple Developer Team ID.
#
# What it does (idempotent — re-running with the same Team ID is a no-op):
#   1. Validates Team ID format (^[A-Z0-9]{10}$).
#   2. Patches /Users/jimchabas/Projects/anemosgp-business/REGISTRY.md:
#      - "Apple Developer Team ID" row in §4 "Apple Developer Program".
#   3. Patches ios/Runner.xcodeproj/project.pbxproj:
#      - Adds `DEVELOPMENT_TEAM = <ID>;` to the THREE Runner-target build configs
#        (Debug 97C147061CF9000F007C117D, Release 97C147071CF9000F007C117D,
#        Profile 249021D4217E4FDB00AE95B9). Project-level configs untouched.
#   4. Patches ios/fastlane/Matchfile:
#      - Replaces PLACEHOLDER_REPLACE_AT_2A-2 with the real Team ID.
#   5. Prints diffs + a summary.
#
# What it does NOT do:
#   - Commit or push. Jim inspects, then commits manually.
#   - Touch the project-level XCBuildConfiguration entries (97C14703 / 97C14704 /
#     249021D3) — those are the PBXProject configs, not the Runner target.
#   - Run any Apple/match commands.
#
# Exit codes:
#   0  success (changes applied or already in place)
#   1  invalid argument / wrong Team ID format
#   2  one or more files missing or unreadable
#   3  unexpected file content (e.g. pbxproj structure not as expected)
#   4  patch verification failed (post-edit grep didn't find the change)

set -euo pipefail

# -------- argv & format validation --------

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <TEAM_ID>" >&2
    echo "       Team ID is the 10-character alphanumeric Apple Developer Team ID." >&2
    echo "       Example: $0 ABC1234567" >&2
    exit 1
fi

TEAM_ID="$1"

if ! [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "ERROR: Team ID '$TEAM_ID' is not 10-char alphanumeric (uppercase A-Z + 0-9)." >&2
    echo "       Apple Team IDs are exactly 10 characters, e.g. 'ABC1234567'." >&2
    exit 1
fi

# -------- absolute paths (no surprises if cwd is unexpected) --------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="/Users/jimchabas/Projects/anemosgp-business/REGISTRY.md"
PBXPROJ="$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj"
MATCHFILE="$REPO_ROOT/ios/fastlane/Matchfile"

for f in "$REGISTRY" "$PBXPROJ" "$MATCHFILE"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: required file not found: $f" >&2
        exit 2
    fi
    if [[ ! -w "$f" ]]; then
        echo "ERROR: required file not writable: $f" >&2
        exit 2
    fi
done

CHANGED_FILES=()
SKIPPED_FILES=()

# -------- 1. REGISTRY.md --------
#
# REGISTRY.md §4 "Apple" → "Apple Developer Program" subsection has a
# "**Team ID:** _pending_ ..." line today. We replace it (or, defensively,
# append a row if the line is gone).

# REGISTRY.md line today (2026-04-28) reads:
#   - **Team ID:** _pending_ (assigned after approval + payment)
# Note the list-item prefix "- " — match optionally so future formatting
# tweaks don't break us.
if grep -qE '^(- )?\*\*Team ID:\*\*[[:space:]]+_pending_' "$REGISTRY"; then
    # Replace the placeholder line with the real Team ID.
    cp "$REGISTRY" "$REGISTRY.bak.captureteamid"
    sed -i '' "s|^\(- \)\{0,1\}\*\*Team ID:\*\*[[:space:]]\{1,\}_pending_.*|\1**Team ID:** $TEAM_ID (assigned $(date +%Y-%m-%d) via scripts/capture_team_id.sh)|" "$REGISTRY"
    rm "$REGISTRY.bak.captureteamid"
    if ! grep -qE "^(- )?\*\*Team ID:\*\*[[:space:]]+$TEAM_ID" "$REGISTRY"; then
        echo "ERROR: REGISTRY.md patch did not stick — placeholder substitution failed." >&2
        exit 4
    fi
    CHANGED_FILES+=("$REGISTRY")
elif grep -qE "^(- )?\*\*Team ID:\*\*[[:space:]]+$TEAM_ID\b" "$REGISTRY"; then
    # Already set to the same Team ID — no-op.
    SKIPPED_FILES+=("$REGISTRY (already set to $TEAM_ID)")
elif grep -qE "^(- )?\*\*Team ID:\*\*[[:space:]]+[A-Z0-9]{10}\b" "$REGISTRY"; then
    # Set to a DIFFERENT Team ID. Refuse — Jim must resolve manually.
    echo "ERROR: REGISTRY.md already has a Team ID set to a different value." >&2
    echo "       Refusing to overwrite. Inspect: grep -n 'Team ID' '$REGISTRY'" >&2
    exit 3
else
    # No placeholder, no existing entry. Defensively append a TODO marker.
    # TODO: REGISTRY.md placeholder line did not exist as expected — appending
    # a new line; verify the §4 "Apple Developer Program" subsection is intact.
    {
        echo ""
        echo "<!-- capture_team_id.sh appended this row $(date +%Y-%m-%d). Verify it lives under §4 \"Apple Developer Program\" and tidy if needed. -->"
        echo "**Team ID:** $TEAM_ID (assigned $(date +%Y-%m-%d) via scripts/capture_team_id.sh)"
    } >> "$REGISTRY"
    CHANGED_FILES+=("$REGISTRY (appended — verify section)")
fi

# -------- 2. project.pbxproj --------
#
# We need DEVELOPMENT_TEAM = <ID>; inside the buildSettings of THREE specific
# build configurations (the Runner *target* configs, not the project-level ones):
#
#   97C147061CF9000F007C117D  /* Debug   */
#   97C147071CF9000F007C117D  /* Release */
#   249021D4217E4FDB00AE95B9  /* Profile */
#
# These IDs are listed in the XCConfigurationList
# `97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */`.
#
# Strategy: an awk pass that opens each of those three blocks, and when it sees
# the `buildSettings = {` line inside that block, inserts a
# `DEVELOPMENT_TEAM = <ID>;` line right after it (sorted alphabetically among
# the existing settings is nice-to-have but not required by Xcode — it
# tolerates any order).
#
# Idempotent: if DEVELOPMENT_TEAM is already inside the block with the SAME
# value, we leave it alone. If it's there with a DIFFERENT value, we replace.

PBX_TARGET_CONFIGS=(
    "97C147061CF9000F007C117D"
    "97C147071CF9000F007C117D"
    "249021D4217E4FDB00AE95B9"
)

# Pre-flight: confirm all three blocks exist; bail loudly if pbxproj structure shifted.
for cfg in "${PBX_TARGET_CONFIGS[@]}"; do
    if ! grep -q "^[[:space:]]*$cfg /\*" "$PBXPROJ"; then
        echo "ERROR: expected build configuration $cfg not found in pbxproj." >&2
        echo "       The Runner target structure may have changed. Inspect:" >&2
        echo "       grep -n 'Build configuration list for PBXNativeTarget \"Runner\"' '$PBXPROJ'" >&2
        exit 3
    fi
done

# Check current state across all three blocks.
ALREADY_OK=0
NEEDS_CHANGE=0
for cfg in "${PBX_TARGET_CONFIGS[@]}"; do
    block=$(awk -v id="$cfg" '
        $0 ~ id" /\\*" { inblock=1 }
        inblock { print }
        inblock && /^[[:space:]]*\};[[:space:]]*$/ { exit }
    ' "$PBXPROJ")

    if echo "$block" | grep -qE "DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*$TEAM_ID[[:space:]]*;"; then
        ALREADY_OK=$((ALREADY_OK + 1))
    else
        NEEDS_CHANGE=$((NEEDS_CHANGE + 1))
    fi
done

if [[ $ALREADY_OK -eq 3 && $NEEDS_CHANGE -eq 0 ]]; then
    SKIPPED_FILES+=("$PBXPROJ (DEVELOPMENT_TEAM already $TEAM_ID in all 3 Runner configs)")
else
    cp "$PBXPROJ" "$PBXPROJ.bak.captureteamid"

    # Use awk to rewrite the file with proper brace-depth tracking.
    #
    # Each XCBuildConfiguration block looks like:
    #   <ID> /* <name> */ = {        <-- depth 0 -> 1 (block opener)
    #     isa = XCBuildConfiguration;
    #     buildSettings = {           <-- depth 1 -> 2
    #       KEY = value;
    #     };                          <-- depth 2 -> 1 (settings close)
    #     name = Debug;
    #   };                            <-- depth 1 -> 0 (block close)
    #
    # We enter `in_target` when the block opener line for one of the three target
    # IDs is seen, and exit when depth returns to 0. Inside, we ensure
    # DEVELOPMENT_TEAM is set to TEAM_ID and any pre-existing line is dropped.

    awk -v team="$TEAM_ID" -v ids="97C147061CF9000F007C117D 97C147071CF9000F007C117D 249021D4217E4FDB00AE95B9" '
        BEGIN {
            n = split(ids, arr, " ")
            for (i = 1; i <= n; i++) target[arr[i]] = 1
            in_target = 0
            depth = 0
            in_settings = 0
        }
        {
            line = $0

            # Detect entry into one of the target XCBuildConfiguration blocks:
            # the line must contain the ID + " /*" AND end with "= {".
            if (!in_target) {
                for (id in target) {
                    if (index(line, id " /*") > 0 && line ~ /=[[:space:]]*\{[[:space:]]*$/) {
                        in_target = 1
                        depth = 1
                        in_settings = 0
                        break
                    }
                }
                print line
                next
            }

            # We are inside a target block. Track buildSettings sub-block opener.
            if (in_target && !in_settings && line ~ /^[[:space:]]*buildSettings[[:space:]]*=[[:space:]]*\{[[:space:]]*$/) {
                in_settings = 1
                depth = 2
                print line
                # Insert DEVELOPMENT_TEAM at the top of buildSettings.
                indent = line
                sub(/buildSettings.*/, "", indent)
                printf "%s\tDEVELOPMENT_TEAM = %s;\n", indent, team
                next
            }

            # Inside buildSettings: drop any pre-existing DEVELOPMENT_TEAM line.
            if (in_target && in_settings && line ~ /^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=/) {
                next
            }

            # Closing "};" inside the target block.
            if (in_target && line ~ /^[[:space:]]*\};[[:space:]]*$/) {
                if (in_settings) {
                    in_settings = 0
                    depth = 1
                    print line
                    next
                } else {
                    # This closes the outer XCBuildConfiguration block.
                    in_target = 0
                    depth = 0
                    print line
                    next
                }
            }

            print line
        }
    ' "$PBXPROJ.bak.captureteamid" > "$PBXPROJ.tmp.captureteamid"

    # Verify the temp file has DEVELOPMENT_TEAM in exactly the three target blocks.
    for cfg in "${PBX_TARGET_CONFIGS[@]}"; do
        block=$(awk -v id="$cfg" '
            $0 ~ id" /\\*" { inblock=1 }
            inblock { print }
            inblock && /^[[:space:]]*\};[[:space:]]*$/ { exit }
        ' "$PBXPROJ.tmp.captureteamid")
        if ! echo "$block" | grep -qE "DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*$TEAM_ID[[:space:]]*;"; then
            echo "ERROR: pbxproj patch did not produce DEVELOPMENT_TEAM = $TEAM_ID; in block $cfg." >&2
            echo "       Original preserved at: $PBXPROJ.bak.captureteamid" >&2
            echo "       Failed candidate at:  $PBXPROJ.tmp.captureteamid" >&2
            exit 4
        fi
    done

    mv "$PBXPROJ.tmp.captureteamid" "$PBXPROJ"

    # Also confirm we didn't accidentally inject DEVELOPMENT_TEAM into the
    # PROJECT-level configs (97C147031CF9000F007C117D, 97C147041CF9000F007C117D,
    # 249021D3217E4FDB00AE95B9). If we did, refuse to leave the file in that state.
    PROJECT_CONFIGS=("97C147031CF9000F007C117D" "97C147041CF9000F007C117D" "249021D3217E4FDB00AE95B9")
    for cfg in "${PROJECT_CONFIGS[@]}"; do
        block=$(awk -v id="$cfg" '
            $0 ~ id" /\\*" { inblock=1 }
            inblock { print }
            inblock && /^[[:space:]]*\};[[:space:]]*$/ { exit }
        ' "$PBXPROJ")
        if echo "$block" | grep -qE "^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*="; then
            echo "ERROR: DEVELOPMENT_TEAM accidentally inserted into PROJECT-level config $cfg." >&2
            echo "       This is not what the script should do. Restoring backup." >&2
            mv "$PBXPROJ.bak.captureteamid" "$PBXPROJ"
            exit 4
        fi
    done

    rm -f "$PBXPROJ.bak.captureteamid"
    CHANGED_FILES+=("$PBXPROJ (3 target configs patched)")
fi

# -------- 3. Matchfile --------

if grep -q "PLACEHOLDER_REPLACE_AT_2A-2" "$MATCHFILE"; then
    cp "$MATCHFILE" "$MATCHFILE.bak.captureteamid"
    sed -i '' "s|PLACEHOLDER_REPLACE_AT_2A-2|$TEAM_ID|g" "$MATCHFILE"
    rm "$MATCHFILE.bak.captureteamid"
    if grep -q "PLACEHOLDER_REPLACE_AT_2A-2" "$MATCHFILE"; then
        echo "ERROR: Matchfile placeholder substitution failed." >&2
        exit 4
    fi
    CHANGED_FILES+=("$MATCHFILE")
elif grep -qE "team_id\\(\"$TEAM_ID\"\\)" "$MATCHFILE"; then
    SKIPPED_FILES+=("$MATCHFILE (already set to $TEAM_ID)")
else
    SKIPPED_FILES+=("$MATCHFILE (no placeholder + no matching team_id — inspect manually)")
fi

# -------- summary --------

echo ""
echo "=========================================="
echo " capture_team_id.sh — Team ID: $TEAM_ID"
echo "=========================================="

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    echo ""
    echo "Changed:"
    for f in "${CHANGED_FILES[@]}"; do
        echo "  - $f"
    done
fi

if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
    echo ""
    echo "Skipped (already in desired state):"
    for f in "${SKIPPED_FILES[@]}"; do
        echo "  - $f"
    done
fi

# -------- diffs (best-effort: only if we're inside the brush-quest git repo
#         and the registry / matchfile / pbxproj are tracked there) --------

echo ""
echo "Diff summary (against HEAD; REGISTRY.md is in a different repo so its diff is shown via diff against working copy):"
( cd "$REPO_ROOT" && git --no-pager diff --stat -- ios/Runner.xcodeproj/project.pbxproj ios/fastlane/Matchfile 2>/dev/null ) || true

if [[ -d "/Users/jimchabas/Projects/anemosgp-business/.git" ]]; then
    echo ""
    echo "REGISTRY.md diff (separate repo):"
    ( cd "/Users/jimchabas/Projects/anemosgp-business" && git --no-pager diff --stat -- REGISTRY.md 2>/dev/null ) || true
fi

echo ""
echo "Next steps:"
echo "  1. Inspect the diffs above (and via 'git diff' in each repo)."
echo "  2. If they look right, commit them — this script intentionally does not commit."
echo "  3. Continue with plan task 2A-3 (SIWA key) and 2B (match)."

exit 0
