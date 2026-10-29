param(
    [string]$ClusterName = 'togglemaster',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$kindVersion = 'v0.33.0'
$toolsDir = Join-Path $projectRoot 'tools'
$kindExe = Join-Path $toolsDir 'kind.exe'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker não foi encontrado no PATH.'
}
docker info | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop não está disponível.' }

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl não foi encontrado no PATH.'
}

if (-not (Test-Path $kindExe)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    $downloadUrl = "https://kind.sigs.k8s.io/dl/$kindVersion/kind-windows-amd64"
    Write-Host "Baixando kind $kindVersion..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $kindExe
}

$installedVersion = & $kindExe version
if ($LASTEXITCODE -ne 0) { throw 'O executável do kind não pôde ser validado.' }
Write-Host $installedVersion

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$clusters = @(& $kindExe get clusters 2>$null)
$ErrorActionPreference = $previousErrorPreference
if ($clusters -notcontains $ClusterName) {
    Write-Host "Criando cluster local $ClusterName..." -ForegroundColor Cyan
    & $kindExe create cluster --name $ClusterName --config '.\kind-config.yaml' --wait 5m
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o cluster kind.' }
} else {
    & $kindExe export kubeconfig --name $ClusterName
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao selecionar o cluster kind.' }
}

& "$PSScriptRoot\install-k8s-addons.ps1"
& "$PSScriptRoot\deploy-k8s.ps1" -SkipBuild:$SkipBuild -ClusterName $ClusterName

Write-Host "`nCluster local pronto." -ForegroundColor Green
Write-Host 'Execute: .\scripts\test-k8s.ps1'
