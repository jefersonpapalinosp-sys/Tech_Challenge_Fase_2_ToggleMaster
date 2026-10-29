$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$services = @(
    'auth-service',
    'flag-service',
    'targeting-service',
    'evaluation-service',
    'analytics-service'
)

foreach ($service in $services) {
    Write-Host "Construindo togglemaster/${service}:local" -ForegroundColor Cyan
    docker build --tag "togglemaster/${service}:local" ".\$service"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao construir $service."
    }
}

docker images --filter 'reference=togglemaster/*:local'
