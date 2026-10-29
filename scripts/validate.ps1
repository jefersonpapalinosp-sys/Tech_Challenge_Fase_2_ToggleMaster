$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host '[1/4] Validando Docker Compose...'
docker-compose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'docker-compose.yml inválido.' }

Write-Host '[2/4] Validando Python...'
$python = Get-Command python -ErrorAction Stop
& $python.Source -m py_compile `
    '.\flag-service\app.py' `
    '.\targeting-service\app.py' `
    '.\analytics-service\app.py'
if ($LASTEXITCODE -ne 0) { throw 'Código Python inválido.' }

Write-Host '[3/4] Renderizando manifests Kubernetes...'
kubectl kustomize '.\k8s' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Manifests Kubernetes inválidos.' }

Write-Host '[4/4] Conferindo arquivos obrigatórios...'
$required = @(
    '.\auth-service\Dockerfile',
    '.\flag-service\Dockerfile',
    '.\targeting-service\Dockerfile',
    '.\evaluation-service\Dockerfile',
    '.\analytics-service\Dockerfile',
    '.\docker-compose.yml',
    '.\k8s\kustomization.yaml',
    '.\k8s\ingress.yaml',
    '.\k8s\hpa.yaml'
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatório ausente: $path" }
}

Write-Host 'Validação estática concluída.' -ForegroundColor Green
