#!/bin/bash
# Claude Code PostToolUse hook: run dart analyze after .dart file edits
# Informational only — prints warnings but does not block (exit 0)
FILE=$(python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)
if [[ "$FILE" == *.dart ]]; then
  OUTPUT=$(dart analyze --no-fatal-infos 2>&1)
  ERRORS=$(echo "$OUTPUT" | grep -c " error " || true)
  WARNINGS=$(echo "$OUTPUT" | grep -c " warning " || true)
  if [[ "$ERRORS" -gt 0 || "$WARNINGS" -gt 0 ]]; then
    echo "$OUTPUT" | tail -25
  fi
fi
exit 0
