$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Get-LocalSetting([string]$Name, [string]$Default) {
    $environmentValue = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) { return $environmentValue }
    if (Test-Path '.env') {
        $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$Name\s*=" } | Select-Object -Last 1
        if ($line) { return ($line -replace "^\s*$Name\s*=\s*", '') }
    }
    return $Default
}

$chatModel = Get-LocalSetting 'CHAT_MODEL' 'qwen3:8b'
$autocompleteModel = Get-LocalSetting 'AUTOCOMPLETE_MODEL' 'qwen2.5-coder:1.5b-base'
$embedModel = Get-LocalSetting 'EMBED_MODEL' 'nomic-embed-text'
$apiBase = Get-LocalSetting 'OLLAMA_API_BASE' 'http://127.0.0.1:11434'
foreach ($model in @($chatModel, $autocompleteModel, $embedModel)) {
    if ($model -notmatch '^[a-zA-Z0-9._:/-]+$') { throw "Invalid model name: $model" }
}
if ($apiBase -notmatch '^https?://\S+$') { throw 'OLLAMA_API_BASE must be an HTTP(S) URL.' }

$directory = Join-Path $HOME '.continue'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($name in @('config.yaml', '.continueignore', '.continuerc.json')) {
    $target = Join-Path $directory $name
    if (Test-Path $target) { Copy-Item $target "$target.backup.$stamp" }
}

$content = Get-Content 'continue/config.yaml' -Raw
$content = $content -replace '(?m)^    model: qwen3:8b$', "    model: $chatModel"
$content = $content -replace '(?m)^    model: qwen2\.5-coder:1\.5b-base$', "    model: $autocompleteModel"
$content = $content -replace '(?m)^    model: nomic-embed-text$', "    model: $embedModel"
$content = $content -replace 'apiBase: http://127\.0\.0\.1:11434', "apiBase: $apiBase"
Set-Content -Path (Join-Path $directory 'config.yaml') -Value $content -Encoding utf8
Copy-Item 'continue/continueignore' (Join-Path $directory '.continueignore')
Copy-Item 'continue/continuerc.json' (Join-Path $directory '.continuerc.json')
Write-Host "Installed Continue configuration at $(Join-Path $directory 'config.yaml')"
Write-Host "Chat: $chatModel | Autocomplete: $autocompleteModel | Embeddings: $embedModel"
Write-Host "Endpoint: $apiBase"
