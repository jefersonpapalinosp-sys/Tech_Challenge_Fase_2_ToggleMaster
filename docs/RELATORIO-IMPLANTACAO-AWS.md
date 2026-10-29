# ToggleMaster — Relatório da Implantação AWS

**Tech Challenge — Fase 2**  
**Ambiente:** AWS Academy  
**Conta:** `058264096738`  
**Região:** `us-east-1`  
**Data da validação:** 29/10/2026

## 1. Resultado executivo

O ToggleMaster foi implantado com sucesso no cluster EKS `eks-togglemaster`. Os cinco microsserviços estão disponíveis, sem reinicializações, e o fluxo completo foi validado desde a API pública até a persistência do evento no DynamoDB.

Endpoint público atual:

```text
http://ae6a5981f8069438481a714114fef81d-9676d8a498457cbb.elb.us-east-1.amazonaws.com
```

O endpoint é fornecido por um Network Load Balancer (NLB) internet-facing. Ele pode mudar se o Service `ingress-nginx-controller` for recriado.

## 2. Estado final

| Item | Estado validado |
|---|---|
| Cluster EKS | `eks-togglemaster`, Kubernetes 1.37 |
| Nós | 2 nós `Ready`, IMDSv2 obrigatório e hop limit 2 |
| Aplicações | 5 Deployments disponíveis, 0 reinicializações |
| Ingress | Nginx Ingress Controller publicado por NLB `active` |
| NLB | 2 targets saudáveis nas portas 80 e 443 |
| Segredos | 4 ExternalSecrets com `SecretSynced=True` |
| Bancos | 3 Jobs de inicialização concluídos |
| Autoscaling | HPA de evaluation e analytics, alvo de CPU 30% |
| Teste ponta a ponta | Aprovado até SQS, Analytics e DynamoDB |

## 3. Arquitetura implantada

Fluxo principal:

```text
Cliente
  ↓
AWS Network Load Balancer
  ↓
Nginx Ingress no EKS
  ├─ /auth     → auth-service      → RDS Auth
  ├─ /flags    → flag-service      → RDS Flag
  ├─ /rules    → targeting-service → RDS Targeting
  └─ /evaluate → evaluation-service
                       ├─ ElastiCache Redis Cluster (TLS)
                       └─ SQS → analytics-service → DynamoDB
```

Os valores sensíveis são mantidos no AWS Secrets Manager. O External Secrets Operator sincroniza somente os campos necessários para Secrets Kubernetes.

## 4. Recursos AWS utilizados

| Camada | Recurso |
|---|---|
| Contêineres | ECR privado `058264096738.dkr.ecr.us-east-1.amazonaws.com/ecr/*` |
| Orquestração | EKS `eks-togglemaster` |
| Entrada | NLB + ingress-nginx |
| Autenticação | `auth-service:v1` + RDS `db-auth-service` |
| Flags | `flag-service:v1` + RDS `db-flag-service` |
| Targeting | `targeting-service:v1` + RDS `db-targeting-service` |
| Avaliação | `evaluation-service:v3` + ElastiCache + SQS |
| Analytics | `analytics-service:v1` + SQS + DynamoDB |
| Fila | `evaluation-analytics-queue` |
| Tabela | `ToggleMasterAnalytics` |
| Segredos | `togglemaster/auth`, `togglemaster/flag`, `togglemaster/targeting`, `togglemaster/evaluation` |

## 5. Correção necessária no evaluation-service

A imagem anterior utilizava `github.com/go-redis/redis/v8 v8.11.5`. O Redis 7 do ElastiCache devolve quatro elementos por nó no comando `CLUSTER SLOTS`, enquanto esse parser aceitava somente dois ou três. O pod encerrava com:

```text
got 4 elements in cluster info address, expected 2 or 3
```

A correção aplicada foi:

- migração para `github.com/redis/go-redis/v9 v9.18.0`;
- preservação de TLS 1.2 e cluster mode;
- testes Go executados com sucesso;
- nova imagem publicada como `evaluation-service:v3`;
- manifesto e Compose AWS atualizados para `v3`.

Após o rollout, o log confirmou:

```text
Conectado ao Redis com sucesso (cluster=true)!
Cliente SQS inicializado com sucesso.
```

## 6. Segurança e segredos

- Nenhuma credencial AWS temporária foi gravada nos YAMLs, no ZIP ou na documentação.
- As três URLs dos RDS, a Master Key, o token Redis e a API key ficam no Secrets Manager.
- A API key do evaluation foi criada pelo próprio `auth-service` e sincronizada pelo ESO.
- RDS e ElastiCache permanecem privados; o acesso ocorre a partir dos nós do EKS.
- Os Security Groups permitem somente os fluxos necessários em `5432` e `6379`.
- Os containers executam sem root, com filesystem somente leitura e capabilities removidas.
- IMDSv2 é obrigatório. O hop limit 2 foi necessário no AWS Academy porque a LabRole do nó é usada pelos pods.

> Atenção: o uso da LabRole pelo IMDS é uma restrição do laboratório. Em um ambiente de produção, prefira EKS Pod Identity ou IRSA com políticas mínimas por serviço.

## 7. Rotas públicas

Use o endpoint NLB como base:

| Operação | Rota |
|---|---|
| Saúde do Auth | `GET /auth/health` |
| Criar API key | `POST /auth/admin/keys` |
| Validar API key | `GET /auth/validate` |
| Flags | `GET/POST /flags` e `GET/PUT/DELETE /flags/{name}` |
| Regras | `POST /rules` e `GET/PUT/DELETE /rules/{flag_name}` |
| Avaliação | `GET /evaluate?user_id={id}&flag_name={flag}` |

O `analytics-service` é um worker interno e não possui rota pública.

## 8. Teste ponta a ponta executado

O smoke test criou temporariamente:

1. uma API key válida no Auth;
2. uma flag habilitada;
3. uma regra `PERCENTAGE` com valor `100`;
4. uma avaliação para um usuário de teste.

Resultado observado:

```json
{"result": true}
```

Em seguida:

- o evaluation publicou o evento no SQS;
- o analytics recebeu a mensagem;
- o evento foi salvo na tabela `ToggleMasterAnalytics`;
- a flag e a regra temporárias foram removidas.

## 9. Operação básica

```powershell
kubectl get deployments -A
kubectl get pods -A
kubectl get externalsecret -A
kubectl get hpa -A
kubectl get ingress -A
kubectl -n evaluation logs deployment/evaluation-service
kubectl -n analytics logs deployment/analytics-service
```

Para renderizar os manifests sem aplicar:

```powershell
kubectl kustomize .\k8s-aws
```

## 10. Evidências finais

- todos os Deployments das aplicações em `1/1`;
- todos os pods das aplicações em `Running`, com zero reinicializações;
- os três Jobs SQL em `Succeeded`;
- ClusterSecretStore `Valid=True`;
- quatro ExternalSecrets `SecretSynced=True`;
- NLB `active`, internet-facing e com todos os targets `healthy`;
- HPA do evaluation e analytics funcionando;
- resposta externa pelo NLB validada;
- persistência no DynamoDB confirmada nos logs do analytics.

## 11. Próximas melhorias recomendadas

1. publicar o endpoint em Route 53 e habilitar HTTPS com ACM;
2. substituir o acesso via LabRole/IMDS por Pod Identity ou IRSA;
3. restringir políticas IAM por microsserviço;
4. configurar observabilidade centralizada com CloudWatch;
5. criar pipeline CI/CD para build, teste, ECR e rollout;
6. revisar pools de conexão dos serviços Python antes de testes de carga.

---

**Arquivos operacionais:** `k8s-aws/`, `k8s-aws.zip`, `docker-compose.aws.yml` e `docs/COMPOSE-AWS.md`.
