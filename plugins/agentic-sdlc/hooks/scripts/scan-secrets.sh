#!/usr/bin/env bash
# sessionEnd hook: scan changed files for leaked secrets.
set -uo pipefail
exec "$(dirname "$0")/scan-common.sh" secrets
