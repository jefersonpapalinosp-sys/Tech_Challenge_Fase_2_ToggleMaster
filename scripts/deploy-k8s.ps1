param(
    [switch]$SkipBuild,
    [string]$ClusterName = 'togglemaster'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$localSecretPath = Join-Path $projectRoot 'k8s\secret-local.yaml'
if (-not (Test-Path -LiteralPath $localSecretPath)) {
    throw 'Segredo local ausente. Copie .\k8s\secret-local.example.yaml para .\k8s\secret-local.yaml e substitua os valores CHANGE_ME.'
}

$context = kubectl config current-context
if ($LASTEXITCODE -ne 0 -or -not $context) {
    throw 'Nenhum contexto Kubernetes está configurado. Execute .\scripts\setup-kind.ps1.'
}
Write-Host "Contexto Kubernetes: $context"

if (-not $SkipBuild) {
    & "$PSScriptRoot\build-images.ps1"
}

if ($context -eq "kind-$ClusterName") {
    $kindExe = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\kind.exe'
    if (-not (Test-Path $kindExe)) {
        throw 'kind.exe não encontrado. Execute .\scripts\setup-kind.ps1.'
    }

    foreach ($service in 'auth-service','flag-service','targeting-service','evaluation-service','analytics-service') {
        & $kindExe load docker-image "togglemaster/${service}:local" --name $ClusterName
        if ($LASTEXITCODE -ne 0) { throw "Falha ao carregar a imagem de $service no kind." }
    }
}

kubectl apply -k '.\k8s'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar os manifests.' }

foreach ($name in 'auth-db','apps-db') {
    kubectl rollout status "statefulset/$name" -n togglemaster --timeout=300s
    if ($LASTEXITCODE -ne 0) { throw "StatefulSet $name não ficou pronto." }
}

foreach ($name in 'redis','aws-local','auth-service','flag-service','targeting-service','evaluation-service','analytics-service') {
    kubectl rollout status "deployment/$name" -n togglemaster --timeout=300s
    if ($LASTEXITCODE -ne 0) { throw "Deployment $name não ficou pronto." }
}

kubectl get pods,svc,ingress,hpa -n togglemaster
