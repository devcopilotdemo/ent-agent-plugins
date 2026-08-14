# preToolUse hook: block `git commit` when staged changes contain secrets or PII.
#
# Emits a preToolUse decision object on stdout. Non-commit shell commands pass through.

$payload = @($input) -join "`n"
if ([string]::IsNullOrWhiteSpace($payload)) {
    try { $payload = [Console]::In.ReadToEnd() } catch { $payload = '' }
}

if ($payload -notmatch 'git[^"]*commit') {
    Write-Output '{}'
    exit 0
}

if ($env:SKIP_SDLC_SCAN -eq 'true') {
    Write-Output '{"permissionDecision":"allow"}'
    exit 0
}

Write-Output '{"type": "progress", "message": "Scanning staged changes for secrets and PII...", "temporary": true}'

$scanner = Join-Path $PSScriptRoot 'scan-common.ps1'
$env:SCAN_MODE = 'block'
$env:SCAN_SCOPE = 'staged'

$output = New-Object System.Collections.Generic.List[string]
$failed = $false

foreach ($set in @('secrets', 'pii')) {
    $result = & $scanner -Set $set 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
        $result | ForEach-Object { $output.Add([string]$_) }
    }
}

if (-not $failed) {
    Write-Output '{"permissionDecision":"allow"}'
    exit 0
}

$reason = "Commit blocked by agentic-sdlc scanners. Remove or externalize the findings below, then retry.`n" + ($output -join "`n")
$decision = @{
    permissionDecision       = 'deny'
    permissionDecisionReason = $reason
} | ConvertTo-Json -Compress -Depth 3

Write-Output $decision
exit 0

