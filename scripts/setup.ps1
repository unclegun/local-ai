param([string]$OfflinePayload)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Invoke-Checked([string]$Command, [object[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed: $Arguments" }
}
function Get-LocalSetting([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    if (Test-Path '.env') {
        $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$Name\s*=" } | Select-Object -Last 1
        if ($line) { return ($line -replace "^\s*$Name\s*=\s*", '') }
    }
    return $Default
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker is required.' }
Invoke-Checked docker @('compose', 'version')
if (-not (Get-Command code -ErrorAction SilentlyContinue)) { throw 'VS Code command-line tool (code) is required.' }
if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env'; Write-Host 'Created .env from workstation defaults.' }
$runtimeMode = Get-LocalSetting 'RUNTIME_MODE' 'local'

if ($OfflinePayload) {
    if (-not (Test-Path $OfflinePayload -PathType Container)) { throw 'OfflinePayload must be a bundle payload directory.' }
    $checksumPath = Join-Path $OfflinePayload 'SHA256SUMS'
    if (-not (Test-Path $checksumPath -PathType Leaf)) { throw 'Offline bundle is missing SHA256SUMS.' }
    foreach ($line in Get-Content $checksumPath) {
        if ($line -notmatch '^([0-9a-fA-F]{64})\s+([^/\\]+)$') { throw "Invalid checksum entry: $line" }
        $expectedHash = $Matches[1].ToLowerInvariant()
        $fileName = $Matches[2]
        $filePath = Join-Path $OfflinePayload $fileName
        if (-not (Test-Path $filePath -PathType Leaf)) { throw "Offline bundle is missing $fileName." }
        $actualHash = (Get-FileHash $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) { throw "Offline bundle checksum failed for $fileName." }
    }
    $manifest = Get-Content (Join-Path $OfflinePayload 'manifest.env')
    $expectedArch = ($manifest | Where-Object { $_ -match '^DOCKER_ARCH=' }) -replace '^DOCKER_ARCH=', ''
    $actualArch = Invoke-Checked docker @('version', '--format', '{{.Server.Arch}}')
    if ($expectedArch -ne $actualArch) { throw "Bundle architecture $expectedArch does not match Docker $actualArch." }
    Invoke-Checked docker @('compose', '-f', 'compose.yml', 'down')
    Invoke-Checked docker @('load', '-i', (Join-Path $OfflinePayload 'docker-images.tar'))
    Invoke-Checked docker @('volume', 'create', 'local-code-ai-models')
    $payloadPath = (Resolve-Path $OfflinePayload).Path
    Invoke-Checked docker @('run', '--rm', '--entrypoint', 'tar', '-v', 'local-code-ai-models:/models', '-v', "${payloadPath}:/payload:ro", 'alpine/socat:1.8.0.3', '-C', '/models', '-xf', '/payload/models.tar')
    Invoke-Checked code @('--install-extension', (Join-Path $OfflinePayload 'continue.vsix'), '--force')
} else {
    $extensions = & code --list-extensions
    if ('continue.continue' -notin $extensions) {
        if ($env:CONTINUE_VSIX -and (Test-Path $env:CONTINUE_VSIX)) {
            Invoke-Checked code @('--install-extension', $env:CONTINUE_VSIX, '--force')
        } else {
            Invoke-Checked code @('--install-extension', 'Continue.continue')
        }
    }
}

if ($runtimeMode -eq 'local') {
    if (-not $OfflinePayload) { & "$PSScriptRoot/provision.ps1" }
    & "$PSScriptRoot/install-continue-config.ps1"
    & "$PSScriptRoot/start.ps1"
} elseif ($runtimeMode -eq 'remote') {
    & "$PSScriptRoot/install-continue-config.ps1"
    $apiBase = Get-LocalSetting 'OLLAMA_API_BASE' 'http://127.0.0.1:11434'
    $null = Invoke-RestMethod -Uri "$($apiBase.TrimEnd('/'))/api/tags" -TimeoutSec 10
    Write-Host "Remote profile installed for $apiBase. Local Docker runtime was not started."
} else { throw 'RUNTIME_MODE must be local or remote.' }
Write-Host 'Setup complete. Reload VS Code, choose Local Copilot Lite, and use Plan mode for project-wide questions.'
