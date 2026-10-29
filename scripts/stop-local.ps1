param([switch]$RemoveVolumes)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if ($RemoveVolumes) {
    docker compose down --volumes --remove-orphans
} else {
    docker compose down --remove-orphans
}

if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao encerrar o ambiente local.'
}
