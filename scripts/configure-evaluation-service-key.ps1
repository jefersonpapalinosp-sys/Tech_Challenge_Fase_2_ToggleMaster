param(
    [string]$ClusterName = "ekstogglemaster",
    [string]$Region = "us-east-1",
    [string]$CredentialsFile = "docs\LAB 2.txt"
)

$ErrorActionPreference = "Stop"

$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$awsDir = Split-Path -Parent $awsPath
$env:PATH = "$awsDir;$env:PATH"

$labCredentials = Get-Content -LiteralPath $CredentialsFile
$env:AWS_ACCESS_KEY_ID = (($labCredentials | Where-Object { $_ -match '^aws_access_key_id=' }) -split '=', 2)[1]
$env:AWS_SECRET_ACCESS_KEY = (($labCredentials | Where-Object { $_ -match '^aws_secret_access_key=' }) -split '=', 2)[1]
$env:AWS_SESSION_TOKEN = (($labCredentials | Where-Object { $_ -match '^aws_session_token=' }) -split '=', 2)[1]

$kubeconfigPath = Join-Path $env:TEMP "togglemaster-key-kubeconfig"

try {
    & $awsPath eks update-kubeconfig `
        --name $ClusterName `
        --region $Region `
        --kubeconfig $kubeconfigPath | Out-Null

    $env:KUBECONFIG = $kubeconfigPath

    $remoteScript = @'
wget -qO- \
  --header="Authorization: Bearer $MASTER_KEY" \
  --header="Content-Type: application/json" \
  --post-data='{"name":"evaluation-service"}' \
  http://127.0.0.1:8001/admin/keys
'@

    $encodedScript = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
    $remoteCommand = "echo $encodedScript | base64 -d | /bin/sh"

    $responseJson = kubectl exec `
        -n auth-service `
        deployment/auth-service `
        -- /bin/sh -c $remoteCommand

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao criar a API key interna no auth-service."
    }

    $response = $responseJson | ConvertFrom-Json
    $serviceKey = $response.key
    if (-not $serviceKey -or $serviceKey -notlike 'tm_key_*') {
        throw "O auth-service não retornou uma API key válida."
    }

    $evaluationSecret = (
        & $awsPath secretsmanager get-secret-value `
            --secret-id "togglemaster/evaluation" `
            --region $Region `
            --query "SecretString" `
            --output text `
            --no-cli-pager
    ) | ConvertFrom-Json

    $evaluationSecret.SERVICE_API_KEY = $serviceKey
    $secretJson = $evaluationSecret | ConvertTo-Json -Compress
    $temporaryJson = Join-Path $env:TEMP (([Guid]::NewGuid().ToString()) + ".json")

    try {
        [IO.File]::WriteAllText(
            $temporaryJson,
            $secretJson,
            (New-Object Text.UTF8Encoding($false))
        )

        & $awsPath secretsmanager put-secret-value `
            --secret-id "togglemaster/evaluation" `
            --secret-string "file://$temporaryJson" `
            --region $Region `
            --query "Name" `
            --output text `
            --no-cli-pager | Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $temporaryJson) {
            Remove-Item -LiteralPath $temporaryJson -Force
        }
    }

    $forceSync = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    kubectl annotate externalsecret evaluation-secret `
        -n evaluation-service `
        "force-sync=$forceSync" `
        --overwrite | Out-Null

    Start-Sleep -Seconds 8

    kubectl rollout restart deployment/evaluation-service `
        -n evaluation-service | Out-Null
    kubectl rollout status deployment/evaluation-service `
        -n evaluation-service `
        --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        throw "O rollout do evaluation-service não foi concluído."
    }

    Write-Output "SERVICE_KEY_CONFIGURED=True"
}
finally {
    if (Test-Path -LiteralPath $kubeconfigPath) {
        Remove-Item -LiteralPath $kubeconfigPath -Force
    }
}
