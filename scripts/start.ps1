$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
# Remove any interrupted provisioning deployment before starting offline.
& docker compose -f compose.provision.yml down
if ($LASTEXITCODE -ne 0) { throw 'Could not remove provisioning deployment.' }
& docker compose -f compose.yml up -d --wait
if ($LASTEXITCODE -ne 0) { throw 'Could not start runtime.' }
for ($i = 0; $i -lt 60; $i++) {
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:11434/' -TimeoutSec 2
        Write-Host 'Local Copilot Lite is ready at http://127.0.0.1:11434.'
        return
    } catch { Start-Sleep -Seconds 2 }
}
throw 'Ollama did not respond locally; inspect docker compose logs.'
