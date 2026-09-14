$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
& docker compose -f compose.yml ps
if ($LASTEXITCODE -ne 0) { throw 'Could not query runtime status.' }
try {
    $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5
} catch {
    throw 'Local Copilot Lite is not reachable. Run .\scripts\start.ps1'
}
Write-Host 'API: ready'
Write-Host 'Installed models:'
$tags.models.name | ForEach-Object { Write-Host "  $_" }
