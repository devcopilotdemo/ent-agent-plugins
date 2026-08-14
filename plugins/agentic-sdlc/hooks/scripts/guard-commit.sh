#!/usr/bin/env bash
# preToolUse hook: block `git commit` when staged changes contain secrets or PII.
#
# Emits a preToolUse decision object on stdout. Any non-commit shell command is
# allowed through without scanning.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$(cat 2>/dev/null || true)"

# Only inspect git commit invocations.
if ! printf '%s' "$PAYLOAD" | grep -qE 'git[^"]*commit'; then
  echo '{}'
  exit 0
fi

if [[ "${SKIP_SDLC_SCAN:-}" == "true" ]]; then
  echo '{"permissionDecision":"allow"}'
  exit 0
fi

echo '{"type": "progress", "message": "Scanning staged changes for secrets and PII...", "temporary": true}'

OUTPUT=""
FAILED=0

if ! RESULT="$(SCAN_MODE=block SCAN_SCOPE=staged "$DIR/scan-common.sh" secrets 2>&1)"; then
  FAILED=1
fi
OUTPUT="$RESULT"

if ! RESULT="$(SCAN_MODE=block SCAN_SCOPE=staged "$DIR/scan-common.sh" pii 2>&1)"; then
  FAILED=1
fi
OUTPUT="$OUTPUT
$RESULT"

if [[ $FAILED -eq 0 ]]; then
  echo '{"permissionDecision":"allow"}'
  exit 0
fi

REASON="$(printf '%s' "$OUTPUT" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')"
printf '{"permissionDecision":"deny","permissionDecisionReason":"Commit blocked by agentic-sdlc scanners. Remove or externalize the findings below, then retry.\\n%s"}\n' "$REASON"
exit 0
