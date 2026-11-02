param(
    [string]$FlagName = "load-postman-fiap",
    [string]$ClusterName = "ekstogglemaster",
    [string]$Region = "us-east-1",
    [string]$CredentialsFile = "docs\LAB 2.txt",
    [string]$OutputDirectory = "docs\evidencias_aws_2026-10-30",
    [int]$LoadPods = 4,
    [int]$LoadSeconds = 240,
    [int]$ScaleDownTimeoutSeconds = 420
)

$ErrorActionPreference = "Stop"
$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$awsDir = Split-Path -Parent $awsPath
$env:PATH = "$awsDir;$env:PATH"

$credentialLines = Get-Content -LiteralPath $CredentialsFile
$env:AWS_ACCESS_KEY_ID = (($credentialLines | Where-Object { $_ -match '^aws_access_key_id=' }) -split '=', 2)[1]
$env:AWS_SECRET_ACCESS_KEY = (($credentialLines | Where-Object { $_ -match '^aws_secret_access_key=' }) -split '=', 2)[1]
$env:AWS_SESSION_TOKEN = (($credentialLines | Where-Object { $_ -match '^aws_session_token=' }) -split '=', 2)[1]

$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$textPath = Join-Path $outputPath "13_hpa_antes_durante_depois.txt"
$htmlPath = Join-Path $outputPath "13_hpa_antes_durante_depois.html"
$pngPath = Join-Path $outputPath "13_hpa_antes_durante_depois.png"
$kubeconfigPath = Join-Path $env:TEMP "togglemaster-hpa-evidence-kubeconfig"
$loadLabel = "togglemaster-test=hpa-evidence"
$records = New-Object System.Collections.Generic.List[string]
$scaledOut = $false
$scaledIn = $false
$maxEvaluationReplicas = 1
$maxAnalyticsReplicas = 1

function Add-Record {
    param([string]$Text)
    $records.Add($Text)
    Write-Output $Text
}

function Add-CommandOutput {
    param([scriptblock]$Command)
    $result = & $Command 2>&1 | Out-String -Width 220
    foreach ($line in ($result.TrimEnd() -split "`r?`n")) {
        $records.Add($line)
    }
    Write-Output $result.TrimEnd()
}

try {
    & $awsPath eks update-kubeconfig --name $ClusterName --region $Region --kubeconfig $kubeconfigPath | Out-Null
    $env:KUBECONFIG = $kubeconfigPath

    Add-Record "TOGGLEMASTER - EVIDENCIA HPA NO AMAZON EKS"
    Add-Record "Conta: 533267349027 | Regiao: $Region | Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    Add-Record "Flag usada na carga: $FlagName"
    Add-Record ""
    Add-Record "=== ANTES DA CARGA ==="
    Add-CommandOutput { kubectl get hpa -A }
    Add-CommandOutput { kubectl get deployment -n evaluation-service evaluation-service }
    Add-CommandOutput { kubectl get deployment -n analytics-service analytics-service }

    $url = "http://evaluation-service.evaluation-service.svc.cluster.local:8004/evaluate?user_id=hpa-evidence&flag_name=$FlagName"
    $loadCommand = "timeout $LoadSeconds /bin/sh -c 'while true; do wget -qO- `"$url`" >/dev/null; done'"
    Add-Record ""
    Add-Record "Criando $LoadPods pods temporarios de carga por ate $LoadSeconds segundos..."
    for ($index = 1; $index -le $LoadPods; $index++) {
        kubectl run "hpa-evidence-$index" -n evaluation-service --labels $loadLabel --image busybox:1.36 --restart Never -- /bin/sh -c $loadCommand | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Falha ao criar o pod de carga hpa-evidence-$index." }
    }

    Add-Record ""
    Add-Record "=== DURANTE A CARGA - LINHA DO TEMPO ==="
    for ($attempt = 1; $attempt -le 24; $attempt++) {
        Start-Sleep -Seconds 10
        $evaluation = kubectl get hpa evaluation-service-hpa -n evaluation-service -o json | ConvertFrom-Json
        $analytics = kubectl get hpa analytics-service-hpa -n analytics-service -o json | ConvertFrom-Json
        $evaluationCurrent = [int]$evaluation.status.currentReplicas
        $evaluationDesired = [int]$evaluation.status.desiredReplicas
        $analyticsCurrent = [int]$analytics.status.currentReplicas
        $analyticsDesired = [int]$analytics.status.desiredReplicas
        $evaluationCpu = if ($evaluation.status.currentMetrics) { $evaluation.status.currentMetrics[0].resource.current.averageUtilization } else { "unknown" }
        $analyticsCpu = if ($analytics.status.currentMetrics) { $analytics.status.currentMetrics[0].resource.current.averageUtilization } else { "unknown" }
        $maxEvaluationReplicas = [Math]::Max($maxEvaluationReplicas, [Math]::Max($evaluationCurrent, $evaluationDesired))
        $maxAnalyticsReplicas = [Math]::Max($maxAnalyticsReplicas, [Math]::Max($analyticsCurrent, $analyticsDesired))
        Add-Record ("{0} tentativa={1} evaluation cpu={2}% atual={3} desejada={4} | analytics cpu={5}% atual={6} desejada={7}" -f (Get-Date -Format 'HH:mm:ss'),$attempt,$evaluationCpu,$evaluationCurrent,$evaluationDesired,$analyticsCpu,$analyticsCurrent,$analyticsDesired)
        if ($maxEvaluationReplicas -gt 1) {
            $scaledOut = $true
            break
        }
    }

    if (-not $scaledOut) { throw "O HPA do evaluation nao aumentou as replicas no tempo esperado." }
    Add-Record ""
    Add-Record "HPA solicitou multiplas replicas. Aguardando o Deployment estabilizar..."
    Add-CommandOutput { kubectl rollout status deployment/evaluation-service -n evaluation-service --timeout=180s }
    $evaluationDeployment = kubectl get deployment evaluation-service -n evaluation-service -o json | ConvertFrom-Json
    $availableAtScaleOut = [int]$evaluationDeployment.status.availableReplicas
    if ($availableAtScaleOut -le 1) {
        throw "O HPA solicitou scale-out, mas o Deployment nao estabilizou com mais de uma replica disponivel."
    }
    Add-Record ""
    Add-Record "=== SNAPSHOT DO SCALE-OUT ==="
    Add-CommandOutput { kubectl get hpa -A }
    Add-CommandOutput { kubectl get deployment evaluation-service -n evaluation-service }
    Add-CommandOutput { kubectl get pods -n evaluation-service -l app=evaluation-service }
    Add-CommandOutput { kubectl get pods -n analytics-service -l app=analytics-service }

    kubectl delete pod -n evaluation-service -l $loadLabel --ignore-not-found --wait=false | Out-Null
    Add-Record ""
    Add-Record "Carga encerrada. Aguardando o retorno ao minimo..."
    $scaleDownAttempts = [Math]::Ceiling($ScaleDownTimeoutSeconds / 15)
    for ($attempt = 1; $attempt -le $scaleDownAttempts; $attempt++) {
        Start-Sleep -Seconds 15
        $evaluation = kubectl get hpa evaluation-service-hpa -n evaluation-service -o json | ConvertFrom-Json
        $evaluationDeployment = kubectl get deployment evaluation-service -n evaluation-service -o json | ConvertFrom-Json
        $current = [int]$evaluation.status.currentReplicas
        $desired = [int]$evaluation.status.desiredReplicas
        $deploymentReplicas = [int]$evaluationDeployment.status.replicas
        Add-Record ("{0} scale-down tentativa={1} HPA atual={2} desejada={3} deployment={4}" -f (Get-Date -Format 'HH:mm:ss'),$attempt,$current,$desired,$deploymentReplicas)
        if ($current -le 1 -and $desired -le 1 -and $deploymentReplicas -le 1) {
            $scaledIn = $true
            break
        }
    }

    if (-not $scaledIn) { throw "O HPA nao retornou ao minimo no tempo esperado." }
    Add-Record ""
    Add-Record "=== DEPOIS DA CARGA ==="
    Add-CommandOutput { kubectl get hpa -A }
    Add-CommandOutput { kubectl get deployment -n evaluation-service evaluation-service }
    Add-CommandOutput { kubectl get pods -n evaluation-service -l app=evaluation-service }
    Add-Record ""
    Add-Record "RESULTADO: scale-out=$scaledOut; maxEvaluation=$maxEvaluationReplicas; maxAnalytics=$maxAnalyticsReplicas; retornoAoMinimo=$scaledIn"
    Add-Record "Nenhuma senha, token, MASTER_KEY ou API key foi exibida."

    $content = $records -join "`r`n"
    [IO.File]::WriteAllText($textPath, $content, (New-Object Text.UTF8Encoding($false)))
    $encoded = [Net.WebUtility]::HtmlEncode($content)
    $html = @"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>
html,body{margin:0;background:#0f172a;color:#e5e7eb}body{padding:34px;font-family:Consolas,"Cascadia Mono",monospace}.frame{border:1px solid #334155;border-radius:14px;overflow:hidden;box-shadow:0 14px 36px rgba(0,0,0,.35)}.bar{background:#172033;padding:16px 22px;color:#ffb347;font:700 20px Arial,sans-serif;border-bottom:1px solid #334155}pre{margin:0;padding:24px;white-space:pre-wrap;overflow-wrap:anywhere;font-size:16px;line-height:1.38}
</style></head><body><div class="frame"><div class="bar">AWS - ToggleMaster - HPA antes, durante e depois</div><pre>$encoded</pre></div></body></html>
"@
    [IO.File]::WriteAllText($htmlPath, $html, (New-Object Text.UTF8Encoding($false)))

    $browser = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $browser) { throw "Chrome ou Edge nao encontrado." }
    $height = [Math]::Max(1600, [Math]::Min(8000, ($records.Count * 24) + 260))
    $uri = [uri]$htmlPath
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $browser --headless=new --disable-gpu --hide-scrollbars --window-size=1800,$height --screenshot=$pngPath $uri.AbsoluteUri 2>$null | Out-Null
    $browserExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($browserExitCode -ne 0 -or -not (Test-Path -LiteralPath $pngPath)) { throw "Falha ao gerar o PNG do HPA." }

    $readmePath = Join-Path $outputPath "README.md"
    $link = "- [HPA antes, durante e depois](13_hpa_antes_durante_depois.png)"
    $readme = Get-Content -LiteralPath $readmePath
    if ($readme -notcontains $link) {
        [IO.File]::AppendAllText($readmePath, "`r`n$link`r`n", (New-Object Text.UTF8Encoding($false)))
    }

    [pscustomobject]@{
        ScaledOut = $scaledOut
        MaxEvaluationReplicas = $maxEvaluationReplicas
        MaxAnalyticsReplicas = $maxAnalyticsReplicas
        ScaledIn = $scaledIn
        Png = $pngPath
    }
}
finally {
    if (Test-Path -LiteralPath $kubeconfigPath) {
        $env:KUBECONFIG = $kubeconfigPath
        kubectl delete pod -n evaluation-service -l $loadLabel --ignore-not-found --wait=false 2>$null | Out-Null
        Remove-Item -LiteralPath $kubeconfigPath -Force -ErrorAction SilentlyContinue
    }
}
