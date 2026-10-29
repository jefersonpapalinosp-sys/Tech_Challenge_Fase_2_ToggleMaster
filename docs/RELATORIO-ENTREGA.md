# Relatório de Entrega — Tech Challenge Fase 2

## Participantes

Preencher antes da entrega:

| Nome | RM | Discord |
|---|---|---|
| A preencher | A preencher | A preencher |

## Repositórios

- Repositório principal: `A preencher`
- Vídeo de demonstração: `A preencher`

## Solução

O ToggleMaster foi decomposto em cinco microsserviços independentes. O ambiente local utiliza Docker Compose com nove containers e substitui os serviços gerenciados da AWS por PostgreSQL, Redis e LocalStack. O ambiente Kubernetes usa namespace próprio, serviços ClusterIP, Ingress, Secrets, ConfigMap, probes, recursos e HPA.

## Validação executável

```powershell
.\scripts\start-local.ps1
.\scripts\test-local.ps1
.\scripts\load-test.ps1 -Requests 500 -Concurrency 20
.\scripts\setup-kind.ps1
.\scripts\test-k8s.ps1
```

O teste ponta a ponta cria e valida uma API key, cria uma flag e uma regra de 100%, avalia a flag, aguarda o consumo da fila e confirma a gravação no DynamoDB local.

O ambiente Kubernetes local foi validado com o nó `togglemaster-control-plane` em estado `Ready`, dez pods de aplicação/infraestrutura em execução, Ingress Nginx funcional e métricas de CPU disponíveis para os dois HPAs. O teste via Ingress confirmou a persistência do evento analítico no DynamoDB.

## Escalabilidade

Foram criados HPAs para `evaluation-service` e `analytics-service`, ambos com alvo médio de CPU de 70%. Essa opção é compatível com as limitações da LabRole no AWS Academy. Em uma conta pessoal, o analytics pode ser migrado para KEDA com escala orientada diretamente pela profundidade da fila.

## Desafios e decisões

- O ambiente local precisa representar SQS e DynamoDB sem depender de credenciais AWS; foi usado LocalStack.
- O Compose deve permanecer com nove containers; SQS e DynamoDB compartilham o container LocalStack.
- O evaluation-service precisa responder rapidamente; a persistência analítica é assíncrona via fila.
- Credenciais locais são deliberadamente fictícias. Produção deve usar Secrets gerenciados e rotação.
