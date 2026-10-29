param([switch]$SkipIngress)

$ErrorActionPreference = 'Stop'

kubectl apply -f 'https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar Metrics Server.' }

$metricsArgs = kubectl get deployment metrics-server -n kube-system `
    -o jsonpath='{.spec.template.spec.containers[0].args}'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar o Metrics Server.' }

if ($metricsArgs -notmatch '--kubelet-insecure-tls') {
    $patchFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'infra\metrics-server-kind-patch.yaml'
    kubectl patch deployment metrics-server -n kube-system --type='strategic' --patch-file $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao ajustar o Metrics Server para o ambiente local.' }
}

if (-not $SkipIngress) {
    kubectl apply -f 'https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml'
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar Nginx Ingress Controller.' }
}

kubectl rollout status deployment/metrics-server -n kube-system --timeout=300s
if ($LASTEXITCODE -ne 0) { throw 'Metrics Server não ficou pronto.' }

if (-not $SkipIngress) {
    kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
    if ($LASTEXITCODE -ne 0) { throw 'Nginx Ingress Controller não ficou pronto.' }
}
