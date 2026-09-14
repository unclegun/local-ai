param(
    [Parameter(Mandatory=$true)][string]$ContinueVsix,
    [string]$Output = 'dist/local-copilot-lite-offline.tar.gz'
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Test-Path $ContinueVsix -PathType Leaf)) { throw 'ContinueVsix must point to an approved VSIX.' }
& "$PSScriptRoot/provision.ps1"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("local-copilot-bundle-" + [guid]::NewGuid())
try {
    $projectStage = Join-Path $stage 'local-ai'
    $payload = Join-Path $stage 'payload'
    New-Item -ItemType Directory -Force -Path $projectStage, $payload | Out-Null
    Get-ChildItem -Force | Where-Object { $_.Name -notin @('.git', '.env', 'dist') } | Copy-Item -Destination $projectStage -Recurse
    Copy-Item $ContinueVsix (Join-Path $payload 'continue.vsix')
    & docker save -o (Join-Path $payload 'docker-images.tar') 'ollama/ollama@sha256:684d8674b4315fa18f4f0e973a118ec2652ed96f67563277839985175858e0ba' 'alpine/socat:1.8.0.3'
    if ($LASTEXITCODE -ne 0) { throw 'Could not export Docker images.' }
    & docker run --rm --entrypoint tar -v local-code-ai-models:/models -v "${payload}:/payload" alpine/socat:1.8.0.3 -C /models -cf /payload/models.tar .
    if ($LASTEXITCODE -ne 0) { throw 'Could not export model volume.' }
    "DOCKER_ARCH=$(& docker version --format '{{.Server.Arch}}')" | Set-Content (Join-Path $payload 'manifest.env')
    $checksumFiles = @('continue.vsix', 'docker-images.tar', 'models.tar', 'manifest.env')
    $checksums = foreach ($name in $checksumFiles) {
        $hash = (Get-FileHash (Join-Path $payload $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $name"
    }
    $checksums | Set-Content (Join-Path $payload 'SHA256SUMS') -Encoding ascii
    New-Item -ItemType Directory -Force -Path (Split-Path $Output) | Out-Null
    tar -C $stage -czf $Output local-ai payload
    if ($LASTEXITCODE -ne 0) { throw 'Could not create bundle archive.' }
    Write-Host "Created $Output"
} finally {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}
