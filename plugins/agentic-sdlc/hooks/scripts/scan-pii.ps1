# sessionEnd hook: scan changed files for personally identifiable information.
& (Join-Path $PSScriptRoot 'scan-common.ps1') -Set pii
exit $LASTEXITCODE
