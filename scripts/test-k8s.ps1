param(
    [string]$IngressAddress = '127.0.0.1',
    [int]$IngressPort = 18080,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Invoke-ToggleRequest {
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Get','Post','Put','Delete')][string]$Method = 'Get',
        [hashtable]$Headers = @{},
        [object]$Body
    )

    $requestHeaders = @{ Host = 'togglemaster.local' }
    foreach ($item in $Headers.GetEnumerator()) { $requestHeaders[$item.Key] = $item.Value }
    $parameters = @{
        Uri = "http://${IngressAddress}:$IngressPort$Path"
        Method = $Method
        Headers = $requestHeaders
        TimeoutSec = 10
    }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body | ConvertTo-Json -Depth 5
    }
    Invoke-RestMethod @parameters
}

$health = $null
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
do {
    try {
        $health = Invoke-ToggleRequest -Path '/auth/health'
        if ($health.status -eq 'ok') { break }
    } catch {
        Start-Sleep -Seconds 2
    }
} while ([DateTime]::UtcNow -lt $deadline)
if ($null -eq $health -or $health.status -ne 'ok') { throw 'Ingress não respondeu dentro do prazo.' }
Write-Host '[OK] Ingress e auth-service saudáveis'

$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$flagName = "k8s-test-$suffix"
$serviceKey = 'tm_key_local_evaluation_service_dev_only'
$serviceHeaders = @{ Authorization = "Bearer $serviceKey" }

$newKey = Invoke-ToggleRequest -Path '/auth/admin/keys' -Method Post `
    -Headers @{ Authorization = 'Bearer admin-secreto-123' } `
    -Body @{ name = "teste-k8s-$suffix" }
if (-not $newKey.key.StartsWith('tm_key_')) { throw 'O auth-service não retornou uma chave válida.' }

$validation = Invoke-ToggleRequest -Path '/auth/validate' `
    -Headers @{ Authorization = "Bearer $($newKey.key)" }
Write-Host "[OK] Auth: $($validation.message)"

Invoke-ToggleRequest -Path '/flags/flags' -Method Post -Headers $serviceHeaders -Body @{
    name = $flagName
    description = 'Flag criada pelo teste Kubernetes local'
    is_enabled = $true
} | Out-Null
Write-Host "[OK] Flag criada: $flagName"

Invoke-ToggleRequest -Path '/targeting/rules' -Method Post -Headers $serviceHeaders -Body @{
    flag_name = $flagName
    is_enabled = $true
    rules = @{ type = 'PERCENTAGE'; value = 100 }
} | Out-Null
Write-Host '[OK] Regra de targeting criada (100%)'

function Get-AnalyticsCount {
    $json = kubectl exec -n togglemaster deployment/aws-local -- `
        awslocal dynamodb scan --table-name ToggleMasterAnalytics --select COUNT --output json
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar o DynamoDB local no Kubernetes.' }
    [int](($json -join "`n") | ConvertFrom-Json).Count
}

$countBefore = Get-AnalyticsCount
$evaluation = Invoke-ToggleRequest -Path "/evaluation/evaluate?user_id=teste-k8s&flag_name=$flagName"
if ($evaluation.result -ne $true) { throw 'A avaliação deveria retornar true para uma regra de 100%.' }
Write-Host '[OK] Evaluation retornou true'

$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
    Start-Sleep -Seconds 2
    $countAfter = Get-AnalyticsCount
} while ($countAfter -le $countBefore -and [DateTime]::UtcNow -lt $deadline)

if ($countAfter -le $countBefore) { throw 'O evento não apareceu no DynamoDB local dentro do prazo.' }
Write-Host "[OK] Analytics persistiu o evento no DynamoDB ($countBefore -> $countAfter)"
Write-Host "`nTeste Kubernetes ponta a ponta concluído com sucesso." -ForegroundColor Green
