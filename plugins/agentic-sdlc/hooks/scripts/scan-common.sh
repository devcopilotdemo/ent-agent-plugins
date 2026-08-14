#!/usr/bin/env bash
# Shared scanner core for the agentic-sdlc plugin hooks.
#
# Usage: scan-common.sh <secrets|pii>
#
# Environment variables:
#   SCAN_MODE       - "warn" (report only) or "block" (exit 1 on findings). Default: warn
#   SCAN_SCOPE      - "diff" (working tree changes + untracked) or "staged". Default: diff
#   SKIP_SDLC_SCAN  - "true" disables all scanning
#   SCAN_ALLOWLIST  - comma-separated substrings to ignore

set -uo pipefail

SET_NAME="${1:-secrets}"

if [[ "${SKIP_SDLC_SCAN:-}" == "true" ]]; then
  echo "SKIPPED: ${SET_NAME} scan disabled via SKIP_SDLC_SCAN"
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository - skipping ${SET_NAME} scan"
  exit 0
fi

MODE="${SCAN_MODE:-warn}"
SCOPE="${SCAN_SCOPE:-diff}"

# Each entry: NAME|SEVERITY|EXTENDED_REGEX
SECRET_PATTERNS=(
  "AWS_ACCESS_KEY|critical|AKIA[0-9A-Z]{16}"
  "AWS_SECRET_KEY|critical|aws_secret_access_key[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+=]{40}"
  "GCP_SERVICE_ACCOUNT|critical|\"type\"[[:space:]]*:[[:space:]]*\"service_account\""
  "GCP_API_KEY|high|AIza[0-9A-Za-z_-]{35}"
  "AZURE_CLIENT_SECRET|critical|azure[_-]?client[_-]?secret[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_~.-]{34,}"
  "AZURE_STORAGE_KEY|critical|AccountKey=[A-Za-z0-9+/=]{60,}"
  "GITHUB_PAT|critical|ghp_[0-9A-Za-z]{36}"
  "GITHUB_OAUTH|critical|gho_[0-9A-Za-z]{36}"
  "GITHUB_APP_TOKEN|critical|ghs_[0-9A-Za-z._-]{36,}"
  "GITHUB_REFRESH_TOKEN|critical|ghr_[0-9A-Za-z]{36}"
  "GITHUB_FINE_GRAINED_PAT|critical|github_pat_[0-9A-Za-z_]{82}"
  "PRIVATE_KEY|critical|-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"
  "GENERIC_SECRET|high|(secret|token|password|passwd|pwd|api[_-]?key|apikey|access[_-]?key|auth[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_/+=~.-]{8,}"
  "CONNECTION_STRING|high|(mongodb(\\+srv)?|postgres(ql)?|mysql|redis|amqp|mssql)://[^[:space:]'\"]{10,}"
  "SLACK_TOKEN|high|xox[baprs]-[0-9]{10,}-[0-9A-Za-z-]+"
  "SLACK_WEBHOOK|high|https://hooks\.slack\.com/services/T[0-9A-Z]{8,}/B[0-9A-Z]{8,}/[0-9A-Za-z]{24}"
  "STRIPE_SECRET_KEY|critical|sk_live_[0-9A-Za-z]{24,}"
  "SENDGRID_API_KEY|high|SG\.[0-9A-Za-z_-]{22}\.[0-9A-Za-z_-]{43}"
  "TWILIO_API_KEY|high|SK[0-9a-fA-F]{32}"
  "NPM_TOKEN|high|npm_[0-9A-Za-z]{36}"
  "JWT_TOKEN|medium|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
)

PII_PATTERNS=(
  "US_SSN|critical|(^|[^0-9-])[0-9]{3}-[0-9]{2}-[0-9]{4}([^0-9-]|$)"
  "CREDIT_CARD|critical|(^|[^0-9])(4[0-9]{12}([0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(011|5[0-9]{2})[0-9]{12})([^0-9]|$)"
  "IBAN|critical|(^|[^A-Z0-9])[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}([^A-Z0-9]|$)"
  "US_PASSPORT|high|passport[_-]?(number|no|num)?[[:space:]]*[:=][[:space:]]*['\"]?[A-Z0-9]{6,9}"
  "DRIVERS_LICENSE|high|(driver'?s?[_-]?licen[sc]e|dl[_-]?number)[[:space:]]*[:=][[:space:]]*['\"]?[A-Z0-9]{5,15}"
  "EMAIL_ADDRESS|medium|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
  "US_PHONE|medium|(^|[^0-9])(\+1[[:space:]-]?)?\(?[2-9][0-9]{2}\)?[[:space:].-][0-9]{3}[[:space:].-][0-9]{4}([^0-9]|$)"
  "DATE_OF_BIRTH|high|(date[_-]?of[_-]?birth|dob|birth[_-]?date)[[:space:]]*[:=][[:space:]]*['\"]?[0-9]{1,4}[-/][0-9]{1,2}[-/][0-9]{1,4}"
  "US_BANK_ROUTING|high|(routing[_-]?(number|no))[[:space:]]*[:=][[:space:]]*['\"]?[0-9]{9}"
  "MEDICAL_RECORD|high|(medical[_-]?record[_-]?(number|no)|mrn)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9-]{5,}"
  "NATIONAL_ID|high|(national[_-]?id|tax[_-]?id|nino|sin[_-]?number)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9-]{6,}"
)

if [[ "$SET_NAME" == "pii" ]]; then
  PATTERNS=("${PII_PATTERNS[@]}")
  LABEL="PII"; PLURAL="PII findings"
else
  PATTERNS=("${SECRET_PATTERNS[@]}")
  LABEL="secret"; PLURAL="secrets"
fi

# Collect candidate files
FILES=()
if [[ "$SCOPE" == "staged" ]]; then
  while IFS= read -r f; do [[ -n "$f" ]] && FILES+=("$f"); done \
    < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
else
  while IFS= read -r f; do [[ -n "$f" ]] && FILES+=("$f"); done \
    < <(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null || git diff --name-only --diff-filter=ACMR 2>/dev/null)
  while IFS= read -r f; do [[ -n "$f" ]] && FILES+=("$f"); done \
    < <(git ls-files --others --exclude-standard 2>/dev/null)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No modified files to scan for $PLURAL"
  exit 0
fi

ALLOWLIST=()
if [[ -n "${SCAN_ALLOWLIST:-}" ]]; then
  IFS=',' read -ra ALLOWLIST <<< "$SCAN_ALLOWLIST"
fi

is_allowlisted() {
  local match="$1" pattern
  for pattern in "${ALLOWLIST[@]:-}"; do
    pattern="$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$pattern" ]] && continue
    [[ "$match" == *"$pattern"* ]] && return 0
  done
  return 1
}

should_scan() {
  local f="$1"
  case "$f" in
    *.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|go.sum|*.sum|*.min.js|*.map) return 1 ;;
  esac
  case "$f" in
    *.md|*.txt|*.json|*.yaml|*.yml|*.xml|*.toml|*.ini|*.cfg|*.conf|*.csv|*.tsv|\
    *.sh|*.bash|*.zsh|*.ps1|*.bat|*.cmd|\
    *.py|*.rb|*.js|*.ts|*.jsx|*.tsx|*.go|*.rs|*.java|*.kt|*.cs|*.cpp|*.c|*.h|\
    *.php|*.swift|*.scala|*.lua|*.pl|*.ex|*.exs|\
    *.html|*.css|*.scss|*.less|*.vue|*.svelte|\
    *.sql|*.graphql|*.proto|*.tf|*.tfvars|\
    *.env|*.env.*|*.properties|\
    Dockerfile*|Makefile*|Gemfile|Rakefile) return 0 ;;
    *) return 1 ;;
  esac
}

FINDINGS=()
COUNT=0

scan_file() {
  local filepath="$1" read_path="${2:-$1}" entry name severity regex line_num line match redacted
  [[ -f "$read_path" ]] || return 0
  should_scan "$filepath" || return 0

  for entry in "${PATTERNS[@]}"; do
    IFS='|' read -r name severity regex <<< "$entry"
    while IFS=: read -r line_num line; do
      [[ -z "${line_num:-}" ]] && continue
      match="$(printf '%s\n' "$line" | grep -oE "$regex" 2>/dev/null | head -1)"
      [[ -z "$match" ]] && continue
      if [[ ${#ALLOWLIST[@]} -gt 0 ]] && is_allowlisted "$match"; then continue; fi
      # Ignore obvious placeholders and test fixtures
      if printf '%s\n' "$match" | grep -qiE '(example|placeholder|your[_-]|xxx|changeme|todo|fixme|replace[_-]?me|dummy|fake|sample|test[_-]?(key|user|data)|noreply|localhost|@example\.(com|org)|555-01[0-9]{2}|0{4,}|1234567890)'; then
        continue
      fi
      if [[ ${#match} -le 12 ]]; then redacted="[REDACTED]"; else redacted="${match:0:3}...${match: -3}"; fi
      FINDINGS+=("$filepath:$line_num  $name  $severity  $redacted")
      COUNT=$((COUNT + 1))
    done < <(grep -nE "$regex" "$read_path" 2>/dev/null || true)
  done
}

echo "Scanning ${#FILES[@]} file(s) for $PLURAL (mode=$MODE, scope=$SCOPE)..."

for f in "${FILES[@]}"; do
  if [[ "$SCOPE" == "staged" ]]; then
    tmp="$(mktemp)"
    git show ":$f" > "$tmp" 2>/dev/null || true
    scan_file "$f" "$tmp"
    rm -f "$tmp"
  else
    scan_file "$f"
  fi
done

if [[ $COUNT -eq 0 ]]; then
  echo "PASS: no $PLURAL detected in ${#FILES[@]} scanned file(s)"
  exit 0
fi

echo ""
echo "Found $COUNT potential ${LABEL} finding(s):"
printf '  %s\n' "${FINDINGS[@]}"
echo ""

if [[ "$MODE" == "block" ]]; then
  echo "BLOCKED: remove or externalize the ${LABEL} findings above before committing."
  echo "If a finding is a false positive, add a distinctive substring to SCAN_ALLOWLIST."
  exit 1
fi

echo "Review the findings above. Set SCAN_MODE=block to fail on findings."
exit 0

