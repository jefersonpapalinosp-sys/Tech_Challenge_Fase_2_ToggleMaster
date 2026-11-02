param(
    [string]$EnvironmentFile = ".env.aws"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $projectRoot $EnvironmentFile

if (-not (Test-Path -LiteralPath $environmentPath)) {
    throw "Arquivo não encontrado: $environmentPath. Execute start-local-aws-tunnel.ps1 primeiro."
}

$values = @{}
Get-Content -LiteralPath $environmentPath |
    Where-Object { $_ -match '^[A-Z][A-Z0-9_]*=' } |
    ForEach-Object {
        $parts = $_ -split '=', 2
        $values[$parts[0]] = $parts[1]
    }

$required = @(
    "SERVICE_API_KEY",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN"
)
foreach ($name in $required) {
    if ([string]::IsNullOrWhiteSpace($values[$name])) {
        throw "Variável obrigatória ausente em ${EnvironmentFile}: $name"
    }
}

$ports = [ordered]@{
    auth       = 28001
    flag       = 28002
    targeting  = 28003
    evaluation = 28004
    analytics  = 28005
}

Write-Output "=== HEALTH LOCAL APONTANDO PARA AWS ==="
foreach ($entry in $ports.GetEnumerator()) {
    $response = Invoke-RestMethod `
        -Uri "http://localhost:$($entry.Value)/health" `
        -TimeoutSec 15
    Write-Output ("{0,-12} porta {1}: {2}" -f $entry.Key, $entry.Value, $response.status)
}

$headers = @{ Authorization = "Bearer $($values.SERVICE_API_KEY)" }
$flagName = "local-aws-e2e-" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$expressionValuesPath = Join-Path $env:TEMP ("togglemaster-e2e-" + [guid]::NewGuid() + ".json")

try {
    $flagBody = @{
        name = $flagName
        description = "Teste end-to-end local apontando para AWS"
        is_enabled = $true
    } | ConvertTo-Json -Compress

    Invoke-RestMethod `
        -Method Post `
        -Uri "http://localhost:28002/flags" `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $flagBody | Out-Null

    $ruleBody = @{
        flag_name = $flagName
        is_enabled = $true
        rules = @{
            type = "PERCENTAGE"
            value = 100
        }
    } | ConvertTo-Json -Depth 4 -Compress

    Invoke-RestMethod `
        -Method Post `
        -Uri "http://localhost:28003/rules" `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $ruleBody | Out-Null

    $evaluation = Invoke-RestMethod `
        -Uri "http://localhost:28004/evaluate?user_id=local-e2e-user&flag_name=$flagName" `
        -TimeoutSec 15
    if ($evaluation.result -ne $true) {
        throw "Evaluation retornou false."
    }

    $env:AWS_ACCESS_KEY_ID = $values.AWS_ACCESS_KEY_ID
    $env:AWS_SECRET_ACCESS_KEY = $values.AWS_SECRET_ACCESS_KEY
    $env:AWS_SESSION_TOKEN = $values.AWS_SESSION_TOKEN
    [IO.File]::WriteAllText(
        $expressionValuesPath,
        (ConvertTo-Json @{ ":flag" = @{ S = $flagName } } -Compress),
        (New-Object Text.UTF8Encoding($false))
    )

    $dynamoCount = 0
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        Start-Sleep -Seconds 5
        $arguments = @(
            "dynamodb", "scan",
            "--table-name", "ToggleMasterAnalytics",
            "--filter-expression", "flag_name = :flag",
            "--expression-attribute-values", "file://$expressionValuesPath",
            "--select", "COUNT",
            "--region", "us-east-1",
            "--query", "Count",
            "--output", "text"
        )
        $dynamoCount = [int](& $awsPath @arguments)
        if ($dynamoCount -gt 0) {
            break
        }
    }

    if ($dynamoCount -lt 1) {
        throw "Evento não encontrado no DynamoDB dentro do tempo esperado."
    }

    Write-Output ""
    Write-Output "=== RESULTADO END-TO-END ==="
    Write-Output "Flag temporária: $flagName"
    Write-Output "Evaluation result: true"
    Write-Output "Eventos encontrados no DynamoDB: $dynamoCount"
    Write-Output "END_TO_END_LOCAL_AWS=True"
}
finally {
    try {
        Invoke-RestMethod `
            -Method Delete `
            -Uri "http://localhost:28003/rules/$flagName" `
            -Headers $headers `
            -TimeoutSec 15 | Out-Null
    }
    catch {}

    try {
        Invoke-RestMethod `
            -Method Delete `
            -Uri "http://localhost:28002/flags/$flagName" `
            -Headers $headers `
            -TimeoutSec 15 | Out-Null
    }
    catch {}

    Remove-Item -LiteralPath $expressionValuesPath -Force -ErrorAction SilentlyContinue
    $headers = $null
    $values = $null
}
