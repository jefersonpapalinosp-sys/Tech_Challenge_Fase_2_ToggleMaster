# Arquitetura do ToggleMaster

## Fluxo principal

```text
Cliente
  ├─ auth-service ─────────────── PostgreSQL/auth_db
  ├─ flag-service ─────────────── PostgreSQL/flags_db
  ├─ targeting-service ────────── PostgreSQL/targeting_db
  └─ evaluation-service
       ├─ consulta flag + targeting
       ├─ usa Redis como cache do hot path
       └─ publica evento no SQS
                         │
                         ▼
                  analytics-service
                         │
                         ▼
                      DynamoDB
```

## Correspondência local e produção

| Requisito | Ambiente local | Produção prevista no enunciado |
|---|---|---|
| Bancos relacionais | 2 containers PostgreSQL, 3 bancos lógicos | 3 instâncias RDS PostgreSQL |
| Cache | Redis containerizado | ElastiCache for Redis |
| Fila | SQS em LocalStack | AWS SQS Standard |
| NoSQL | DynamoDB em LocalStack | AWS DynamoDB |
| Orquestração | Docker Compose ou cluster Kubernetes `kind` | EKS |
| Registro | Imagens locais `togglemaster/*:local` | 5 repositórios ECR |
| Entrada | Portas locais ou Nginx Ingress | Nginx Ingress + Load Balancer |

O LocalStack reúne SQS e DynamoDB em um único container. Assim, o Compose mantém os 9 containers solicitados pelo enunciado: 5 aplicações e 4 componentes de dados.

As aplicações continuam ouvindo internamente nas portas oficiais `8001–8005`. O Compose publica `18001–18005` no Windows para não interromper outro projeto que já utiliza a porta 8002.

## Decisões de implementação

- Os serviços Go são compilados em multi-stage e executados em Alpine como usuário não-root.
- Os serviços Python instalam dependências em um estágio de build e executam com Gunicorn como usuário não-root.
- Todas as aplicações expõem `/health`; Compose e Kubernetes usam esse endpoint.
- O `evaluation-service` é o hot path. Ele consulta flag e targeting em paralelo, guarda a combinação por 30 segundos no Redis e publica o resultado no SQS.
- O `analytics-service` faz long polling da fila, persiste cada evento no DynamoDB e remove a mensagem somente após a gravação.
- O HPA do evaluation e do analytics usa CPU, a alternativa compatível com AWS Academy/LabRole indicada no enunciado.
- Requests e limits estão definidos para permitir agendamento previsível e cálculo correto do HPA.

## Data stores

- **PostgreSQL/RDS:** dados relacionais, consistentes e transacionais: chaves, flags e regras.
- **Redis/ElastiCache:** cache de baixa latência para o caminho de avaliação.
- **DynamoDB:** armazenamento NoSQL de eventos analíticos, adequado a alto volume e acesso por chave.
- **SQS:** desacopla a resposta de avaliação da persistência analítica e absorve picos.

## Limitações locais

O ambiente local reproduz comportamento e topologia, mas não substitui evidências de EKS, ECR, RDS, ElastiCache ou Load Balancer da AWS. Os manifests usam imagens locais e `imagePullPolicy: Never`; para EKS, substitua as imagens pelos endereços do ECR e use Secrets externos.

O cluster `kind` publica o Nginx Ingress nas portas `18080` e `18443`. Isso mantém o ambiente autocontido e evita depender da ativação do Kubernetes no Docker Desktop.
