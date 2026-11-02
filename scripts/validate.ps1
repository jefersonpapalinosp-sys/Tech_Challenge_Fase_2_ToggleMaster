$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host '[1/5] Validando Docker Compose...'
docker compose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'docker-compose.yml inválido.' }

Write-Host '[2/5] Validando Python...'
$python = Get-Command python -ErrorAction Stop
& $python.Source -m py_compile `
    '.\flag-service\app.py' `
    '.\targeting-service\app.py' `
    '.\analytics-service\app.py'
if ($LASTEXITCODE -ne 0) { throw 'Código Python inválido.' }

Write-Host '[3/5] Renderizando Kubernetes local com Secret de exemplo...'
$validationTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$validationDir = Join-Path $validationTempRoot ('togglemaster-validate-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $validationDir | Out-Null
    Get-ChildItem -LiteralPath '.\k8s' -Filter '*.yaml' -File |
        Where-Object { $_.Name -notin @('secret-local.yaml','secret.yaml') } |
        Copy-Item -Destination $validationDir
    Copy-Item -LiteralPath '.\k8s\secret-local.example.yaml' -Destination (Join-Path $validationDir 'secret-local.yaml')
    kubectl kustomize $validationDir | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Manifests Kubernetes locais invalidos.' }
} finally {
    if (Test-Path -LiteralPath $validationDir) {
        $resolvedValidationDir = (Resolve-Path -LiteralPath $validationDir).Path
        $validationPrefix = $validationTempRoot.TrimEnd('\') + '\'
        if (-not $resolvedValidationDir.StartsWith($validationPrefix,[StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedValidationDir) -notlike 'togglemaster-validate-*') {
            throw 'Diretorio temporario fora do caminho esperado; limpeza cancelada.'
        }
        Remove-Item -LiteralPath $resolvedValidationDir -Recurse -Force
    }
}

Write-Host '[4/5] Renderizando manifestos AWS...'
kubectl kustomize '.\k8s-aws' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Manifests Kubernetes AWS invalidos.' }

Write-Host '[5/5] Conferindo arquivos obrigatórios...'
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
    '.\k8s-aws\kustomization.yaml'
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatório ausente: $path" }
}

Write-Host 'Validação estática concluída.' -ForegroundColor Green
