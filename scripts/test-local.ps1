param(
    [string]$HostName = 'localhost',
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Wait-Health {
    param([int]$Port)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-RestMethod -Uri "http://${HostName}:$Port/health" -TimeoutSec 3
            if ($response.status -eq 'ok') {
                Write-Host "[OK] Health $Port"
                return
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Timeout aguardando o health check da porta $Port."
}

function Get-AnalyticsCount {
    $json = docker compose exec -T aws-local awslocal dynamodb scan `
        --table-name ToggleMasterAnalytics `
        --select COUNT `
        --output json
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível consultar o DynamoDB local.'
    }
    return [int](($json -join "`n") | ConvertFrom-Json).Count
}

$ports = 18001, 18002, 18003, 18004, 18005
$ports | ForEach-Object { Wait-Health -Port $_ }

$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$flagName = "local-test-$suffix"
$serviceKey = 'tm_key_local_evaluation_service_dev_only'
$serviceHeaders = @{ Authorization = "Bearer $serviceKey" }

$newKey = Invoke-RestMethod `
    -Method Post `
    -Uri "http://${HostName}:18001/admin/keys" `
    -Headers @{ Authorization = 'Bearer admin-secreto-123' } `
    -ContentType 'application/json' `
    -Body (@{ name = "teste-$suffix" } | ConvertTo-Json)

if (-not $newKey.key.StartsWith('tm_key_')) {
    throw 'O auth-service não retornou uma chave válida.'
}

$validation = Invoke-RestMethod `
    -Uri "http://${HostName}:18001/validate" `
    -Headers @{ Authorization = "Bearer $($newKey.key)" }
Write-Host "[OK] Auth: $($validation.message)"

$flagBody = @{
    name = $flagName
    description = 'Flag criada pelo teste ponta a ponta local'
    is_enabled = $true
} | ConvertTo-Json
Invoke-RestMethod `
    -Method Post `
    -Uri "http://${HostName}:18002/flags" `
    -Headers $serviceHeaders `
    -ContentType 'application/json' `
    -Body $flagBody | Out-Null
Write-Host "[OK] Flag criada: $flagName"

$ruleBody = @{
    flag_name = $flagName
    is_enabled = $true
    rules = @{ type = 'PERCENTAGE'; value = 100 }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod `
    -Method Post `
    -Uri "http://${HostName}:18003/rules" `
    -Headers $serviceHeaders `
    -ContentType 'application/json' `
    -Body $ruleBody | Out-Null
Write-Host '[OK] Regra de targeting criada (100%)'

$countBefore = Get-AnalyticsCount
$evaluation = Invoke-RestMethod `
    -Uri "http://${HostName}:18004/evaluate?user_id=teste-local&flag_name=$flagName"
if ($evaluation.result -ne $true) {
    throw 'A avaliação deveria retornar true para uma regra de 100%.'
}
Write-Host '[OK] Evaluation retornou true'

$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
    Start-Sleep -Seconds 2
    $countAfter = Get-AnalyticsCount
} while ($countAfter -le $countBefore -and [DateTime]::UtcNow -lt $deadline)

if ($countAfter -le $countBefore) {
    throw 'O evento não apareceu no DynamoDB local dentro do prazo.'
}

Write-Host "[OK] Analytics persistiu o evento no DynamoDB ($countBefore -> $countAfter)"
Write-Host "`nTeste ponta a ponta concluído com sucesso." -ForegroundColor Green
