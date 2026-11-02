# Dot-source: . .\apresentacao\scripts\01-preparar-sessao.ps1
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$credentialPath = Join-Path $projectRoot 'docs\LAB 2.txt'
$awsCommand = Get-Command aws -ErrorAction SilentlyContinue
if (-not $awsCommand) {
    $awsDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Amazon\AWSCLIV2'
    if (-not (Test-Path (Join-Path $awsDirectory 'aws.exe'))) { throw 'Instale AWS CLI antes de continuar.' }
    $env:PATH = "$awsDirectory;$env:PATH"
}
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw 'kubectl nao encontrado.' }
$credentialMap = @{}
foreach ($line in (Get-Content -LiteralPath $credentialPath)) {
    if ($line -match '^\s*(aws_access_key_id|aws_secret_access_key|aws_session_token)\s*=\s*(.+?)\s*$') {
        $credentialMap[$matches[1]] = $matches[2]
    }
}
foreach ($name in @('aws_access_key_id','aws_secret_access_key','aws_session_token')) {
    if (-not $credentialMap[$name]) { throw "Credencial ausente em LAB 2.txt: $name" }
    [Environment]::SetEnvironmentVariable($name.ToUpperInvariant(),$credentialMap[$name],'Process')
}
$credentialMap.Clear()
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_PAGER = ''
$account = aws sts get-caller-identity --query Account --output text --region us-east-1
if ($LASTEXITCODE -ne 0 -or "$account".Trim() -ne '533267349027') { throw 'Credenciais invalidas ou conta diferente do LAB esperado.' }
$sessionKubeconfig = Join-Path $env:TEMP 'togglemaster-video-kubeconfig'
aws eks update-kubeconfig --name ekstogglemaster --region us-east-1 --kubeconfig $sessionKubeconfig | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Falha no acesso ao EKS. Conferir Lab ativo e credenciais.' }
$env:KUBECONFIG = $sessionKubeconfig
kubectl get nodes
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar os nos.' }
Write-Host 'Sessao preparada: conta 533267349027 / ekstogglemaster / us-east-1. Valores de credenciais nao exibidos.'
