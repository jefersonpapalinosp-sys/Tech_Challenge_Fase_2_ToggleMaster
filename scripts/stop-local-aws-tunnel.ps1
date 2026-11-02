$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot
$telepresence = Join-Path $projectRoot "tools\telepresence\telepresence.exe"
$env:KUBECONFIG = Join-Path $projectRoot "tools\kubeconfig-aws"
$env:APPDATA = Join-Path $projectRoot "tools\telepresence-appdata"

Push-Location $projectRoot
try {
    & $telepresence compose `
        --use togglemaster `
        -f docker-compose.aws.yml `
        -f docker-compose.telepresence.yml `
        --env-file .env.aws `
        --env-file .env.aws.local `
        down

    & $telepresence quit --use togglemaster
    Write-Output "Containers locais e túnel Telepresence encerrados."
    Write-Output "O Traffic Manager permanece no EKS para o próximo uso."
}
finally {
    Pop-Location
}
