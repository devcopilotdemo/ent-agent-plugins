# sessionEnd hook: scan changed files for leaked secrets.
& (Join-Path $PSScriptRoot 'scan-common.ps1') -Set secrets
exit $LASTEXITCODE
