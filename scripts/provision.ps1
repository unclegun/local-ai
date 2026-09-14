$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Invoke-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "Docker failed: $args" }
}

function Get-LocalSetting([string]$Name, [string]$Default) {
    $environmentValue = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) { return $environmentValue }
    if (Test-Path '.env') {
        $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$Name\s*=" } | Select-Object -Last 1
        if ($line) { return ($line -replace "^\s*$Name\s*=\s*", '') }
    }
    return $Default
}

$models = @(
    (Get-LocalSetting 'CHAT_MODEL' 'qwen3:8b'),
    (Get-LocalSetting 'AUTOCOMPLETE_MODEL' 'qwen2.5-coder:1.5b-base'),
    (Get-LocalSetting 'EMBED_MODEL' 'nomic-embed-text')
)
foreach ($model in $models) {
    if ($model -notmatch '^[a-zA-Z0-9._:/-]+$') { throw "Invalid model name: $model" }
}

Write-Host 'Provisioning uses Internet access only for artifacts that are not already cached.'
try {
    Invoke-Docker compose -f compose.yml down
    & docker image inspect alpine/socat:1.8.0.3 *> $null
    if ($LASTEXITCODE -ne 0) { Invoke-Docker pull alpine/socat:1.8.0.3 }
    Invoke-Docker compose -f compose.provision.yml up -d --wait
    foreach ($model in $models) {
        $installed = Invoke-Docker compose -f compose.provision.yml exec -T ollama ollama list
        $names = @($installed | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] })
        $taggedModel = if ($model.Contains(':')) { $model } else { "${model}:latest" }
        if ($model -in $names -or $taggedModel -in $names) {
            Write-Host "Already installed: $model"
        } else {
            Invoke-Docker compose -f compose.provision.yml exec -T ollama ollama pull $model
        }
    }
    Invoke-Docker compose -f compose.provision.yml exec -T ollama ollama list
    Write-Host 'Provisioning succeeded. The connected container will be removed; model data is preserved.'
} finally {
    Invoke-Docker compose -f compose.provision.yml down
}
