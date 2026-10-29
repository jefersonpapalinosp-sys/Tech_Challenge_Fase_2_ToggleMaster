# ToggleMaster no EKS — manifestos AWS

Esta árvore contém os manifestos do ambiente AWS da conta `058264096738`, região `us-east-1`. O conjunto foi aplicado ao cluster `eks-togglemaster` em 29/10/2026. Editar os arquivos ou executar `kubectl kustomize` apenas localmente não altera a AWS; uma mudança só entra no cluster após `kubectl apply` ou uma atualização Helm.

## O que está configurado

| Componente | Configuração AWS |
|---|---|
| Imagens | ECR privado `058264096738.dkr.ecr.us-east-1.amazonaws.com/ecr/*` |
| SQS | `evaluation-analytics-queue` |
| DynamoDB | `ToggleMasterAnalytics` |
| Redis | ElastiCache em cluster mode, por meio de `REDIS_URL` no Secrets Manager |
| Bancos | Três RDS PostgreSQL privados, por meio de `DATABASE_URL` no Secrets Manager |
| Segredos | Secrets Manager → External Secrets Operator → Secret Kubernetes |
| Escala | HPA de evaluation e analytics com alvo de CPU de 30% |
| Entrada | Nginx Ingress publicado por NLB, com rotas `/auth`, `/flags`, `/rules` e `/evaluate` |

O analytics é um worker e não tem Ingress público. Sua liveness probe é TCP na porta `8005`.

## Estado implantado em 29/10/2026

| Item | Estado |
|---|---|
| Cluster | `eks-togglemaster` ativo, com dois nós Ready |
| Ingress | NLB internet-facing, estado `active` |
| Endpoint atual | `http://ae6a5981f8069438481a714114fef81d-9676d8a498457cbb.elb.us-east-1.amazonaws.com` |
| Imagem evaluation | `058264096738.dkr.ecr.us-east-1.amazonaws.com/ecr/evaluation-service:v3` |
| Segredos | Quatro `ExternalSecret` com `SecretSynced=True` |
| Bancos | Três Jobs de inicialização concluídos |
| Teste funcional | Auth → Flag → Targeting → Evaluation → SQS → Analytics → DynamoDB aprovado |

O endpoint do Load Balancer é gerado pela AWS e pode mudar se o Service `ingress-nginx-controller` for recriado.

## Pré-requisitos

Antes de aplicar estes arquivos, confirme:

1. EKS com nós capazes de puxar imagens do ECR.
2. External Secrets Operator com suporte a `external-secrets.io/v1`.
3. Metrics Server e Nginx Ingress Controller instalados.
4. LabRole acessível pelos pods via IMDS; no AWS Academy, o hop limit dos nós precisa ser `2`.
5. Security groups permitindo EKS → RDS em `5432` e EKS → ElastiCache em `6379`.
6. Os quatro segredos abaixo criados no Secrets Manager.

## Formato dos segredos

Não grave credenciais nos YAMLs. Os `ExternalSecret` esperam estes documentos JSON:

`togglemaster/auth`:

```json
{
  "DATABASE_URL": "postgres://<USUARIO>:<SENHA_URL_ENCODED>@db-auth-service.c7yswag6apmj.us-east-1.rds.amazonaws.com:5432/postgres?sslmode=require",
  "MASTER_KEY": "<CHAVE_FORTE>"
}
```

`togglemaster/flag`:

```json
{
  "DATABASE_URL": "postgres://<USUARIO>:<SENHA_URL_ENCODED>@db-flag-service.c7yswag6apmj.us-east-1.rds.amazonaws.com:5432/postgres?sslmode=require"
}
```

`togglemaster/targeting`:

```json
{
  "DATABASE_URL": "postgres://<USUARIO>:<SENHA_URL_ENCODED>@db-targeting-service.c7yswag6apmj.us-east-1.rds.amazonaws.com:5432/postgres?sslmode=require"
}
```

`togglemaster/evaluation`:

```json
{
  "REDIS_URL": "rediss://:<TOKEN_URL_ENCODED>@clustercfg.redis-evaluation-service.ifqrsm.use1.cache.amazonaws.com:6379",
  "SERVICE_API_KEY": "<CHAVE_GERADA_PELO_AUTH_SERVICE>"
}
```

As instâncias RDS atuais não têm banco inicial customizado; por isso as URLs usam o banco padrão `postgres`. Os três Jobs executam os `init.sql` nesse banco.

## Ordem segura de aplicação

Primeiro, crie a estrutura do cluster e confirme que o acesso ao Secrets Manager está válido:

```bash
kubectl apply -f cluster/namespaces.yaml
kubectl apply -f cluster/cluster-secret-store.yaml
kubectl get clustersecretstore aws-secrets-manager
```

Depois, sincronize os quatro segredos:

```bash
kubectl apply -f auth/external-secret.yaml \
  -f flag/external-secret.yaml \
  -f targeting/external-secret.yaml \
  -f evaluation/external-secret.yaml
kubectl get externalsecret -A
```

Espere `SecretSynced` e então aplique o conjunto completo:

```bash
kubectl apply -k .
kubectl wait --for=condition=complete job/auth-db-init -n auth --timeout=180s
kubectl wait --for=condition=complete job/flag-db-init -n flag --timeout=180s
kubectl wait --for=condition=complete job/targeting-db-init -n targeting --timeout=180s
kubectl get pods,svc,ingress,hpa -A
```

Se um script SQL mudar depois que o Job já existir, apague somente o Job correspondente e reaplique o diretório. Jobs têm campos imutáveis.

## Validação sem aplicar

O Kustomize apenas renderiza os manifestos e não acessa a AWS:

```bash
kubectl kustomize .
```

Em um cluster com as CRDs do ESO instaladas, faça também a validação do cliente:

```bash
kubectl apply --dry-run=client -k .
```

## Decisões de segurança

- Nenhum `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` ou `AWS_SESSION_TOKEN` está nos manifestos.
- Não existem endpoints locais de LocalStack, DynamoDB Local, Redis ou PostgreSQL.
- O `ClusterSecretStore` não possui credencial estática; usa a cadeia padrão do SDK e a LabRole do nó.
- Os containers das aplicações executam sem root, com filesystem somente leitura e capabilities removidas.
- O evaluation usa `evaluation-service:v3`, com TLS, cluster mode e cliente `go-redis/v9` compatível com a topologia Redis 7 do ElastiCache. Os demais usam `v1`.
