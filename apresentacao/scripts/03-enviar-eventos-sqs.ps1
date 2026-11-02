param(
    [ValidateRange(1,1000)][int]$Count = 100,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
$runId = 'video-sqs-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
if ($Preview) {
    [pscustomobject]@{ Preview=$true; Queue='tgmqueue'; Count=$Count; RunId=$runId; WritesExecuted=0 }
    return
}
$account = aws sts get-caller-identity --query Account --output text --region us-east-1
if ($LASTEXITCODE -ne 0 -or "$account".Trim() -ne '533267349027') { throw 'Prepare a sessao com 01-preparar-sessao.ps1.' }
$queueUrl = aws sqs get-queue-url --queue-name tgmqueue --region us-east-1 --query QueueUrl --output text
if ($LASTEXITCODE -ne 0 -or $queueUrl -notmatch '/533267349027/tgmqueue$') { throw 'Fila diferente do destino esperado.' }
$batchPath = Join-Path $env:TEMP ('togglemaster-video-sqs-' + [guid]::NewGuid().ToString('N') + '.json')
$sent = 0
Write-Host "RunId=$runId (usar como filtro flag_name no DynamoDB)"
try {
    for ($offset=0; $offset -lt $Count; $offset+=10) {
        $entries = @()
        for ($j=$offset; $j -lt [Math]::Min($offset+10,$Count); $j++) {
            $body = @{ user_id="synthetic-video-$j"; flag_name=$runId; result=$true; timestamp=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json -Compress
            $entries += @{ Id="event-$j"; MessageBody=$body }
        }
        $payload = @{ QueueUrl="$queueUrl".Trim(); Entries=$entries } | ConvertTo-Json -Depth 6 -Compress
        [IO.File]::WriteAllText($batchPath,$payload,(New-Object Text.UTF8Encoding($false)))
        $response = aws sqs send-message-batch --region us-east-1 --cli-input-json "file://$batchPath" --output json
        if ($LASTEXITCODE -ne 0) { throw "Falha no envio. Mensagens confirmadas ate aqui: $sent" }
        $batch = $response | ConvertFrom-Json
        $sent += @($batch.Successful).Count
        if ($batch.Failed -and @($batch.Failed).Count -gt 0) { throw "Falha parcial no lote. Mensagens confirmadas: $sent" }
        Write-Host "Mensagens aceitas: $sent/$Count"
    }
    [pscustomobject]@{ RunId=$runId; MessagesSent=$sent; Queue='tgmqueue'; AnalyticsScaleOut='A verificar via kubectl'; DynamoDBPersistence='A verificar pelo RunId' }
}
finally {
    if (Test-Path -LiteralPath $batchPath) { Remove-Item -LiteralPath $batchPath -Force }
}
