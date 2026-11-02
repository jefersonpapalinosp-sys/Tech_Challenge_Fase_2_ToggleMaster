param(
    [string]$CredentialsFile = "docs\LAB 2.txt",
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$telepresence = Join-Path $projectRoot "tools\telepresence\telepresence.exe"
$kubeconfig = Join-Path $projectRoot "tools\kubeconfig-aws"
$telepresenceAppData = Join-Path $projectRoot "tools\telepresence-appdata"

if (-not (Test-Path -LiteralPath $awsPath)) {
    throw "AWS CLI não encontrada em $awsPath"
}
if (-not (Test-Path -LiteralPath $telepresence)) {
    throw "Telepresence não encontrado. Use a instalação preparada em tools\telepresence."
}

Push-Location $projectRoot
try {
    & (Join-Path $PSScriptRoot "generate-env-aws.ps1") -CredentialsFile $CredentialsFile
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao gerar .env.aws"
    }

    $credentialLines = Get-Content -LiteralPath $CredentialsFile
    $env:AWS_ACCESS_KEY_ID = (($credentialLines | Where-Object { $_ -match '^aws_access_key_id=' }) -split '=', 2)[1]
    $env:AWS_SECRET_ACCESS_KEY = (($credentialLines | Where-Object { $_ -match '^aws_secret_access_key=' }) -split '=', 2)[1]
    $env:AWS_SESSION_TOKEN = (($credentialLines | Where-Object { $_ -match '^aws_session_token=' }) -split '=', 2)[1]
    $env:PATH = "$(Split-Path -Parent $awsPath);$env:PATH"

    & $awsPath eks update-kubeconfig `
        --name ekstogglemaster `
        --region us-east-1 `
        --kubeconfig $kubeconfig | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao atualizar o kubeconfig do EKS."
    }

    $env:KUBECONFIG = $kubeconfig
    $env:APPDATA = $telepresenceAppData

    kubectl get statefulset traffic-manager -n ambassador | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & $telepresence helm install `
            --manager-namespace ambassador `
            --also-proxy 10.0.0.0/16 `
            --progress plain
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao instalar o Traffic Manager."
        }
    }

    & $telepresence connect `
        --docker `
        --name togglemaster `
        --progress plain
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao conectar o túnel Telepresence."
    }

    $ecrPassword = & $awsPath ecr get-login-password --region us-east-1
    $ecrPassword | docker login `
        --username AWS `
        --password-stdin `
        533267349027.dkr.ecr.us-east-1.amazonaws.com | Out-Null
    $ecrPassword = $null
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao autenticar no ECR."
    }

    $composeArgs = @(
        "compose",
        "--use", "togglemaster",
        "-f", "docker-compose.aws.yml",
        "-f", "docker-compose.telepresence.yml",
        "--env-file", ".env.aws",
        "--env-file", ".env.aws.local"
    )

    if (-not $SkipPull) {
        & $telepresence @composeArgs pull
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao baixar as imagens do ECR."
        }
    }

    & $telepresence @composeArgs up -d --wait
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao iniciar os serviços locais."
    }

    Write-Output "ToggleMaster local conectado à AWS:"
    Write-Output "  Auth:       http://localhost:28001/health"
    Write-Output "  Flag:       http://localhost:28002/health"
    Write-Output "  Targeting:  http://localhost:28003/health"
    Write-Output "  Evaluation: http://localhost:28004/health"
    Write-Output "  Analytics:  http://localhost:28005/health"
}
finally {
    Pop-Location
}
