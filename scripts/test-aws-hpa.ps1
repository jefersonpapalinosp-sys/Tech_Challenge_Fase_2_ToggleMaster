param(
    [Parameter(Mandatory = $true)]
    [string]$FlagName,
    [string]$ClusterName = "ekstogglemaster",
    [string]$Region = "us-east-1",
    [string]$CredentialsFile = "docs\LAB 2.txt",
    [int]$LoadPods = 4,
    [int]$LoadSeconds = 120
)

$ErrorActionPreference = "Stop"

$awsPath = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2\aws.exe"
$awsDir = Split-Path -Parent $awsPath
$env:PATH = "$awsDir;$env:PATH"

$labCredentials = Get-Content -LiteralPath $CredentialsFile
$env:AWS_ACCESS_KEY_ID = (($labCredentials | Where-Object { $_ -match '^aws_access_key_id=' }) -split '=', 2)[1]
$env:AWS_SECRET_ACCESS_KEY = (($labCredentials | Where-Object { $_ -match '^aws_secret_access_key=' }) -split '=', 2)[1]
$env:AWS_SESSION_TOKEN = (($labCredentials | Where-Object { $_ -match '^aws_session_token=' }) -split '=', 2)[1]

$kubeconfigPath = Join-Path $env:TEMP "togglemaster-hpa-kubeconfig"
$loadLabel = "togglemaster-test=hpa"
$maxObservedReplicas = 1
$scaledOut = $false

try {
    & $awsPath eks update-kubeconfig `
        --name $ClusterName `
        --region $Region `
        --kubeconfig $kubeconfigPath | Out-Null
    $env:KUBECONFIG = $kubeconfigPath

    Write-Output "=== HPA BEFORE ==="
    kubectl get hpa evaluation-service-hpa -n evaluation-service

    $url = "http://evaluation-service.evaluation-service.svc.cluster.local:8004/evaluate?user_id=hpa-load&flag_name=$FlagName"
    $loadCommand = "timeout $LoadSeconds /bin/sh -c 'while true; do wget -qO- `"$url`" >/dev/null; done'"

    for ($index = 1; $index -le $LoadPods; $index++) {
        kubectl run "hpa-load-$index" `
            -n evaluation-service `
            --labels $loadLabel `
            --image busybox:1.36 `
            --restart Never `
            -- /bin/sh -c $loadCommand | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao criar o pod de carga hpa-load-$index."
        }
    }

    Write-Output "=== HPA DURING LOAD ==="
    for ($attempt = 1; $attempt -le 18; $attempt++) {
        Start-Sleep -Seconds 10
        $hpaJson = kubectl get hpa evaluation-service-hpa `
            -n evaluation-service `
            -o json | ConvertFrom-Json
        $current = [int]$hpaJson.status.currentReplicas
        $desired = [int]$hpaJson.status.desiredReplicas
        $metric = if ($hpaJson.status.currentMetrics) {
            $hpaJson.status.currentMetrics[0].resource.current.averageUtilization
        }
        else {
            "unknown"
        }
        $maxObservedReplicas = [Math]::Max($maxObservedReplicas, [Math]::Max($current, $desired))
        Write-Output "attempt=$attempt cpu=$metric current=$current desired=$desired maxObserved=$maxObservedReplicas"
        if ($maxObservedReplicas -gt 1) {
            $scaledOut = $true
            break
        }
    }

    if (-not $scaledOut) {
        throw "O HPA não aumentou as réplicas dentro do tempo esperado."
    }

    kubectl get hpa evaluation-service-hpa -n evaluation-service
    kubectl get pods -n evaluation-service -l app=evaluation-service
}
finally {
    if (Test-Path -LiteralPath $kubeconfigPath) {
        $env:KUBECONFIG = $kubeconfigPath
        kubectl delete pod `
            -n evaluation-service `
            -l $loadLabel `
            --ignore-not-found `
            --wait=false | Out-Null
        Remove-Item -LiteralPath $kubeconfigPath -Force
    }
}

[pscustomobject]@{
    ScaledOut = $scaledOut
    MaxObservedReplicas = $maxObservedReplicas
}
