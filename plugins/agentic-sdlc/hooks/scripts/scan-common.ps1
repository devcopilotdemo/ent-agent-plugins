<#
.SYNOPSIS
  Shared scanner core for the agentic-sdlc plugin hooks (Windows).

.DESCRIPTION
  Scans changed or staged files for secrets or PII.

  Environment variables:
    SCAN_MODE       - "warn" (report only) or "block" (exit 1 on findings). Default: warn
    SCAN_SCOPE      - "diff" (working tree + untracked) or "staged". Default: diff
    SKIP_SDLC_SCAN  - "true" disables all scanning
    SCAN_ALLOWLIST  - comma-separated substrings to ignore
#>
[CmdletBinding()]
param(
    [ValidateSet('secrets', 'pii')]
    [string]$Set = 'secrets'
)

$ErrorActionPreference = 'Stop'

if ($env:SKIP_SDLC_SCAN -eq 'true') {
    Write-Output "SKIPPED: $Set scan disabled via SKIP_SDLC_SCAN"
    exit 0
}

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output "Not a git repository - skipping $Set scan"
    exit 0
}

$mode = if ($env:SCAN_MODE) { $env:SCAN_MODE } else { 'warn' }
$scope = if ($env:SCAN_SCOPE) { $env:SCAN_SCOPE } else { 'diff' }

$secretPatterns = @(
    @{ Name = 'AWS_ACCESS_KEY';         Severity = 'critical'; Regex = 'AKIA[0-9A-Z]{16}' }
    @{ Name = 'AWS_SECRET_KEY';         Severity = 'critical'; Regex = 'aws_secret_access_key\s*[:=]\s*["'']?[A-Za-z0-9/+=]{40}' }
    @{ Name = 'GCP_SERVICE_ACCOUNT';    Severity = 'critical'; Regex = '"type"\s*:\s*"service_account"' }
    @{ Name = 'GCP_API_KEY';            Severity = 'high';     Regex = 'AIza[0-9A-Za-z_\-]{35}' }
    @{ Name = 'AZURE_CLIENT_SECRET';    Severity = 'critical'; Regex = 'azure[_-]?client[_-]?secret\s*[:=]\s*["'']?[A-Za-z0-9_~.\-]{34,}' }
    @{ Name = 'AZURE_STORAGE_KEY';      Severity = 'critical'; Regex = 'AccountKey=[A-Za-z0-9+/=]{60,}' }
    @{ Name = 'GITHUB_PAT';             Severity = 'critical'; Regex = 'ghp_[0-9A-Za-z]{36}' }
    @{ Name = 'GITHUB_OAUTH';           Severity = 'critical'; Regex = 'gho_[0-9A-Za-z]{36}' }
    @{ Name = 'GITHUB_APP_TOKEN';       Severity = 'critical'; Regex = 'ghs_[0-9A-Za-z._\-]{36,}' }
    @{ Name = 'GITHUB_REFRESH_TOKEN';   Severity = 'critical'; Regex = 'ghr_[0-9A-Za-z]{36}' }
    @{ Name = 'GITHUB_FINE_GRAINED_PAT';Severity = 'critical'; Regex = 'github_pat_[0-9A-Za-z_]{82}' }
    @{ Name = 'PRIVATE_KEY';            Severity = 'critical'; Regex = '-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----' }
    @{ Name = 'GENERIC_SECRET';         Severity = 'high';     Regex = '(secret|token|password|passwd|pwd|api[_-]?key|apikey|access[_-]?key|auth[_-]?token|client[_-]?secret)\s*[:=]\s*["'']?[A-Za-z0-9_/+=~.\-]{8,}' }
    @{ Name = 'CONNECTION_STRING';      Severity = 'high';     Regex = '(mongodb(\+srv)?|postgres(ql)?|mysql|redis|amqp|mssql)://[^\s"'']{10,}' }
    @{ Name = 'SLACK_TOKEN';            Severity = 'high';     Regex = 'xox[baprs]-[0-9]{10,}-[0-9A-Za-z\-]+' }
    @{ Name = 'SLACK_WEBHOOK';          Severity = 'high';     Regex = 'https://hooks\.slack\.com/services/T[0-9A-Z]{8,}/B[0-9A-Z]{8,}/[0-9A-Za-z]{24}' }
    @{ Name = 'STRIPE_SECRET_KEY';      Severity = 'critical'; Regex = 'sk_live_[0-9A-Za-z]{24,}' }
    @{ Name = 'SENDGRID_API_KEY';       Severity = 'high';     Regex = 'SG\.[0-9A-Za-z_\-]{22}\.[0-9A-Za-z_\-]{43}' }
    @{ Name = 'TWILIO_API_KEY';         Severity = 'high';     Regex = 'SK[0-9a-fA-F]{32}' }
    @{ Name = 'NPM_TOKEN';              Severity = 'high';     Regex = 'npm_[0-9A-Za-z]{36}' }
    @{ Name = 'JWT_TOKEN';              Severity = 'medium';   Regex = 'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}' }
)

$piiPatterns = @(
    @{ Name = 'US_SSN';           Severity = 'critical'; Regex = '(?<![0-9\-])[0-9]{3}-[0-9]{2}-[0-9]{4}(?![0-9\-])' }
    @{ Name = 'CREDIT_CARD';      Severity = 'critical'; Regex = '(?<![0-9])(4[0-9]{12}([0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(011|5[0-9]{2})[0-9]{12})(?![0-9])' }
    @{ Name = 'IBAN';             Severity = 'critical'; Regex = '(?<![A-Z0-9])[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}(?![A-Z0-9])' }
    @{ Name = 'US_PASSPORT';      Severity = 'high';     Regex = 'passport[_-]?(number|no|num)?\s*[:=]\s*["'']?[A-Z0-9]{6,9}' }
    @{ Name = 'DRIVERS_LICENSE';  Severity = 'high';     Regex = '(driver''?s?[_-]?licen[sc]e|dl[_-]?number)\s*[:=]\s*["'']?[A-Z0-9]{5,15}' }
    @{ Name = 'EMAIL_ADDRESS';    Severity = 'medium';   Regex = '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}' }
    @{ Name = 'US_PHONE';         Severity = 'medium';   Regex = '(?<![0-9])(\+1[\s\-]?)?\(?[2-9][0-9]{2}\)?[\s.\-][0-9]{3}[\s.\-][0-9]{4}(?![0-9])' }
    @{ Name = 'DATE_OF_BIRTH';    Severity = 'high';     Regex = '(date[_-]?of[_-]?birth|dob|birth[_-]?date)\s*[:=]\s*["'']?[0-9]{1,4}[-/][0-9]{1,2}[-/][0-9]{1,4}' }
    @{ Name = 'US_BANK_ROUTING';  Severity = 'high';     Regex = 'routing[_-]?(number|no)\s*[:=]\s*["'']?[0-9]{9}' }
    @{ Name = 'MEDICAL_RECORD';   Severity = 'high';     Regex = '(medical[_-]?record[_-]?(number|no)|mrn)\s*[:=]\s*["'']?[A-Za-z0-9\-]{5,}' }
    @{ Name = 'NATIONAL_ID';      Severity = 'high';     Regex = '(national[_-]?id|tax[_-]?id|nino|sin[_-]?number)\s*[:=]\s*["'']?[A-Za-z0-9\-]{6,}' }
)

if ($Set -eq 'pii') {
    $patterns = $piiPatterns
    $label = 'PII'; $plural = 'PII findings'
}
else {
    $patterns = $secretPatterns
    $label = 'secret'; $plural = 'secrets'
}

# Collect candidate files
$files = @()
if ($scope -eq 'staged') {
    $files = @(git diff --cached --name-only --diff-filter=ACMR 2>$null | Where-Object { $_ })
}
else {
    $files = @(git diff --name-only --diff-filter=ACMR HEAD 2>$null | Where-Object { $_ })
    $files += @(git ls-files --others --exclude-standard 2>$null | Where-Object { $_ })
}
$files = $files | Select-Object -Unique

if ($files.Count -eq 0) {
    Write-Output "No modified files to scan for $plural"
    exit 0
}

$allowlist = @()
if ($env:SCAN_ALLOWLIST) {
    $allowlist = $env:SCAN_ALLOWLIST.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$skipExact = @('package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'Cargo.lock', 'go.sum')
$skipExt = @('.lock', '.sum', '.map', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.gz', '.exe', '.dll')
$scanExt = @(
    '.md', '.txt', '.json', '.yaml', '.yml', '.xml', '.toml', '.ini', '.cfg', '.conf', '.csv', '.tsv',
    '.sh', '.bash', '.ps1', '.bat', '.cmd',
    '.py', '.rb', '.js', '.ts', '.jsx', '.tsx', '.go', '.rs', '.java', '.kt', '.cs', '.cpp', '.c', '.h',
    '.php', '.swift', '.scala', '.lua', '.pl', '.ex', '.exs',
    '.html', '.css', '.scss', '.less', '.vue', '.svelte',
    '.sql', '.graphql', '.proto', '.tf', '.tfvars',
    '.env', '.properties'
)
$scanNamePrefix = @('Dockerfile', 'Makefile', 'Gemfile', 'Rakefile', '.env')

function Test-ShouldScan {
    param([string]$Path)
    $name = Split-Path $Path -Leaf
    if ($skipExact -contains $name) { return $false }
    $ext = [System.IO.Path]::GetExtension($name)
    if ($skipExt -contains $ext) { return $false }
    if ($name -like '*.min.js') { return $false }
    if ($scanExt -contains $ext) { return $true }
    foreach ($p in $scanNamePrefix) { if ($name.StartsWith($p)) { return $true } }
    return $false
}

$placeholder = 'example|placeholder|your[_-]|xxx|changeme|todo|fixme|replace[_-]?me|dummy|fake|sample|test[_-]?(key|user|data)|noreply|localhost|@example\.(com|org)|555-01[0-9]{2}|0{4,}|1234567890'

$findings = New-Object System.Collections.Generic.List[string]

function Invoke-ScanFile {
    param([string]$DisplayPath, [string]$ReadPath)

    if (-not (Test-Path -LiteralPath $ReadPath -PathType Leaf)) { return }
    if (-not (Test-ShouldScan $DisplayPath)) { return }

    $lines = @(Get-Content -LiteralPath $ReadPath -ErrorAction SilentlyContinue)
    if ($lines.Count -eq 0) { return }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        foreach ($p in $patterns) {
            $m = [regex]::Match($line, $p.Regex)
            if (-not $m.Success) { continue }

            $match = $m.Value
            if ($allowlist | Where-Object { $match -like "*$_*" }) { continue }
            if ($match -match "(?i)$placeholder") { continue }

            $redacted = if ($match.Length -le 12) {
                '[REDACTED]'
            }
            else {
                '{0}...{1}' -f $match.Substring(0, 3), $match.Substring($match.Length - 3)
            }

            $findings.Add(('  {0}:{1}  {2}  {3}  {4}' -f $DisplayPath, ($i + 1), $p.Name, $p.Severity, $redacted))
        }
    }
}

Write-Output "Scanning $($files.Count) file(s) for $plural (mode=$mode, scope=$scope)..."

foreach ($f in $files) {
    if ($scope -eq 'staged') {
        $tmp = [System.IO.Path]::GetTempFileName()
        git show ":$f" 2>$null | Set-Content -LiteralPath $tmp -Encoding UTF8
        Invoke-ScanFile -DisplayPath $f -ReadPath $tmp
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    else {
        Invoke-ScanFile -DisplayPath $f -ReadPath $f
    }
}

if ($findings.Count -eq 0) {
    Write-Output "PASS: no $plural detected in $($files.Count) scanned file(s)"
    exit 0
}

Write-Output ''
Write-Output "Found $($findings.Count) potential $label finding(s):"
$findings | ForEach-Object { Write-Output $_ }
Write-Output ''

if ($mode -eq 'block') {
    Write-Output "BLOCKED: remove or externalize the $label findings above before committing."
    Write-Output 'If a finding is a false positive, add a distinctive substring to SCAN_ALLOWLIST.'
    exit 1
}

Write-Output 'Review the findings above. Set SCAN_MODE=block to fail on findings.'
exit 0

