param([switch]$NoBuild)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path '.env')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env'
    Write-Host 'Arquivo .env criado a partir de .env.example.'
}

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop não está acessível. Abra-o e aguarde o Engine iniciar.'
}

$arguments = @('compose', 'up', '-d', '--wait', '--wait-timeout', '240')
if (-not $NoBuild) {
    $arguments += '--build'
}
docker @arguments
if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao subir o ambiente Docker Compose.'
}

$running = @(docker compose ps --services --status running)
if ($running.Count -ne 9) {
    docker compose ps
    throw "Eram esperados 9 containers em execução, mas foram encontrados $($running.Count)."
}

docker compose ps
Write-Host "`nAmbiente local pronto. Execute .\scripts\test-local.ps1" -ForegroundColor Green
