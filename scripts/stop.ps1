$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
& docker compose -f compose.yml down
if ($LASTEXITCODE -ne 0) { throw 'Could not stop runtime.' }
Write-Host 'Stopped. The local-code-ai-models volume is preserved.'
