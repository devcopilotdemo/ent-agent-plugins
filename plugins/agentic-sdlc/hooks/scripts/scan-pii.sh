#!/usr/bin/env bash
# sessionEnd hook: scan changed files for personally identifiable information.
set -uo pipefail
exec "$(dirname "$0")/scan-common.sh" pii
