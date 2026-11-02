# Linha do tempo do analytics-service: fila SQS x CPU do HPA x replicas.
# Uso (depois de 01-preparar-sessao.ps1 no mesmo terminal):
#   .\apresentacao\scripts\05-acompanhar-analytics.ps1 -Seconds 420
param(
    [ValidateRange(30,1800)][int]$Seconds = 420,
    [ValidateRange(5,60)][int]$Interval = 10
)
$ErrorActionPreference = 'Stop'
if (-not $env:AWS_SESSION_TOKEN -or -not $env:KUBECONFIG) { . (Join-Path $PSScriptRoot '01-preparar-sessao.ps1') }
$queueUrl = aws sqs get-queue-url --queue-name tgmqueue --region us-east-1 --query QueueUrl --output text
if ($LASTEXITCODE -ne 0) { throw 'Prepare a sessao com 01-preparar-sessao.ps1.' }
$queueUrl = "$queueUrl".Trim()
$maxReady = 0
$end = (Get-Date).AddSeconds($Seconds)
Write-Host '=== ANALYTICS-SERVICE: FILA SQS x HPA (alvo de CPU 30%) ==='
while ((Get-Date) -lt $end) {
    $fila = aws sqs get-queue-attributes --queue-url $queueUrl --region us-east-1 --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query Attributes --output json | ConvertFrom-Json
    $hpa = kubectl get hpa analytics-service-hpa -n analytics-service -o json | ConvertFrom-Json
    $deploy = kubectl get deployment analytics-service -n analytics-service -o json | ConvertFrom-Json
    $cpu = if ($hpa.status.currentMetrics) { "$($hpa.status.currentMetrics[0].resource.current.averageUtilization)%" } else { 'n/d' }
    $ready = [int]$deploy.status.readyReplicas
    $maxReady = [Math]::Max($maxReady, $ready)
    '{0}  fila={1,6}  em_processamento={2,4}  cpu={3,5}/30%  replicas atual={4} desejada={5} prontas={6}' -f `
        (Get-Date -Format 'HH:mm:ss'), $fila.ApproximateNumberOfMessages, $fila.ApproximateNumberOfMessagesNotVisible,
        $cpu, $hpa.status.currentReplicas, $hpa.status.desiredReplicas, $ready
    Start-Sleep -Seconds $Interval
}
"Maximo de replicas prontas observado: $maxReady"
