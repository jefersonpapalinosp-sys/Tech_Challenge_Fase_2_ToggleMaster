# Kubernetes local

Os manifests reproduzem localmente os nove workloads principais: cinco aplicações e quatro componentes de dados. O cluster `kind` fica isolado no Docker e usa as imagens construídas localmente.

## Execução completa

Com Docker Desktop em execução:

```powershell
Copy-Item .\k8s\secret-local.example.yaml .\k8s\secret-local.yaml
# Edite secret-local.yaml e substitua todos os valores CHANGE_ME.
.\scripts\setup-kind.ps1
.\scripts\test-k8s.ps1
```

O primeiro comando:

1. baixa `kind.exe` para `tools/`;
2. cria o cluster `togglemaster`;
3. instala Metrics Server e Nginx Ingress;
4. constrói e carrega as cinco imagens locais;
5. aplica os manifests e aguarda todos os workloads.

O segundo comando valida pelo Ingress o fluxo auth → flag → targeting → evaluation → SQS → analytics → DynamoDB. O acesso usa `127.0.0.1:18080` e o cabeçalho `Host: togglemaster.local`, portanto não exige alteração no arquivo `hosts`.

## Reaplicação e inspeção

```powershell
.\scripts\deploy-k8s.ps1
kubectl get pods,svc,ingress,hpa -n togglemaster
kubectl logs -n togglemaster deployment/evaluation-service
kubectl logs -n togglemaster deployment/analytics-service
```

Para remover apenas o cluster deste projeto:

```powershell
.\tools\kind.exe delete cluster --name togglemaster
```

O arquivo `secret-local.yaml` é local e ignorado pelo Git. Use `secret-local.example.yaml` como modelo, preencha os valores somente na máquina de execução e nunca publique esse arquivo. O campo `stringData` aceita texto simples e o Kubernetes faz a codificação necessária. Em produção, use um gerenciador de segredos.
