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

$kubeconfigPath = Join-Path $env:TEMP "togglemaster-smoke-kubeconfig"
$dynamoValuesPath = Join-Path $env:TEMP "togglemaster-dynamo-values.json"

function Invoke-CurlJson {
    param(
        [string]$Method,
        [string]$Url,
        [string]$ApiKey,
        [string]$Body
    )

    $bodyPath = $null
    try {
        $arguments = @(
            "-sS",
            "--fail-with-body",
            "-X", $Method,
            "-H", "Authorization: Bearer $ApiKey",
            "-H", "Content-Type: application/json"
        )
        if ($Body) {
            $bodyPath = Join-Path $env:TEMP (([Guid]::NewGuid().ToString()) + ".json")
            [IO.File]::WriteAllText(
                $bodyPath,
                $Body,
                (New-Object Text.UTF8Encoding($false))
            )
            $arguments += @("--data-binary", "@$bodyPath")
        }
        $arguments += $Url

        $response = & curl.exe @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Falha HTTP em $Method $Url. Resposta: $response"
        }
        return $response
    }
    finally {
        if ($bodyPath -and (Test-Path -LiteralPath $bodyPath)) {
            Remove-Item -LiteralPath $bodyPath -Force
        }
    }
}

try {
    & $awsPath eks update-kubeconfig `
        --name $ClusterName `
        --region $Region `
        --kubeconfig $kubeconfigPath | Out-Null
    $env:KUBECONFIG = $kubeconfigPath

    $loadBalancer = kubectl get service `
        my-release-ingress-nginx-controller `
        -n ingress-nginx `
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    if (-not $loadBalancer) {
        throw "Load Balancer do Ingress ainda não possui hostname."
    }

    $remoteScript = @'
wget -qO- \
  --header="Authorization: Bearer $MASTER_KEY" \
  --header="Content-Type: application/json" \
  --post-data='{"name":"smoke-test-aws"}' \
  http://127.0.0.1:8001/admin/keys
'@
    $encodedScript = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
    $remoteCommand = "echo $encodedScript | base64 -d | /bin/sh"
    $keyResponseJson = kubectl exec `
        -n auth-service `
        deployment/auth-service `
        -- /bin/sh -c $remoteCommand

    if ($LASTEXITCODE -ne 0) {
        throw "Não foi possível criar a chave do smoke test."
    }

    $apiKey = ($keyResponseJson | ConvertFrom-Json).key
    if (-not $apiKey -or $apiKey -notlike 'tm_key_*') {
        throw "O auth-service não retornou uma chave válida para o smoke test."
    }

    $flagName = "smoke-aws-" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    $flagBody = @{
        name = $flagName
        description = "Smoke test AWS"
        is_enabled = $true
    } | ConvertTo-Json -Compress
    Invoke-CurlJson `
        -Method "POST" `
        -Url "http://$loadBalancer/flags" `
        -ApiKey $apiKey `
        -Body $flagBody | Out-Null

    $ruleBody = @{
        flag_name = $flagName
        is_enabled = $true
        rules = @{
            type = "PERCENTAGE"
            value = 100
        }
    } | ConvertTo-Json -Compress
    Invoke-CurlJson `
        -Method "POST" `
        -Url "http://$loadBalancer/rules" `
        -ApiKey $apiKey `
        -Body $ruleBody | Out-Null

    $evaluationJson = & curl.exe `
        -sS `
        --fail-with-body `
        "http://$loadBalancer/evaluate?user_id=smoke-user&flag_name=$flagName"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao consultar o evaluation-service: $evaluationJson"
    }
    $evaluation = $evaluationJson | ConvertFrom-Json
    if ($evaluation.result -ne $true) {
        throw "O evaluation-service respondeu, mas result não foi true."
    }

    $expressionValues = @{
        ":flag" = @{ S = $flagName }
    } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText(
        $dynamoValuesPath,
        $expressionValues,
        (New-Object Text.UTF8Encoding($false))
    )

    $dynamoCount = 0
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        Start-Sleep -Seconds 5
        $countText = & $awsPath dynamodb scan `
            --table-name "ToggleMasterAnalytics" `
            --region $Region `
            --filter-expression "flag_name = :flag" `
            --expression-attribute-values "file://$dynamoValuesPath" `
            --select COUNT `
            --query "Count" `
            --output text `
            --no-cli-pager
        $dynamoCount = [int]$countText
        if ($dynamoCount -gt 0) {
            break
        }
    }

    if ($dynamoCount -lt 1) {
        throw "O evento não apareceu no DynamoDB dentro do tempo esperado."
    }

    [pscustomobject]@{
        LoadBalancer = $loadBalancer
        Flag = $flagName
        EvaluationResult = $evaluation.result
        DynamoDBItems = $dynamoCount
    }
}
finally {
    foreach ($path in @($kubeconfigPath, $dynamoValuesPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}
