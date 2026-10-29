# Docker Compose usando recursos AWS

O arquivo `docker-compose.aws.yml` contém somente os cinco microsserviços. PostgreSQL, Redis, SQS e DynamoDB apontam para os recursos reais da conta AWS `058264096738` em `us-east-1`.

## Recursos configurados

| Componente | Recurso AWS |
|---|---|
| auth-service | ECR `ecr/auth-service:v1` + RDS `db-auth-service` |
| flag-service | ECR `ecr/flag-service:v1` + RDS `db-flag-service` |
| targeting-service | ECR `ecr/targeting-service:v1` + RDS `db-targeting-service` |
| evaluation-service | ECR `ecr/evaluation-service:v3` + ElastiCache + SQS |
| analytics-service | ECR `ecr/analytics-service:v1` + SQS + DynamoDB |
| Fila | `evaluation-analytics-queue` |
| Tabela | `ToggleMasterAnalytics` |

## Restrição de rede

Os três RDS têm `PubliclyAccessible=false`, e o ElastiCache também é privado. Portanto, este Compose **não funciona diretamente no notebook**. Execute-o em uma EC2 ou outro host com rota para a VPC `vpc-0ecf1861ef9b39911` e com regras de Security Group liberando 5432 e 6379 a partir desse host.

## Preparação

1. Copie o modelo de variáveis:

```powershell
Copy-Item .env.aws.example .env.aws
```

2. Preencha em `.env.aws`:

- as três senhas dos RDS, com caracteres especiais codificados para URL;
- o AUTH token do ElastiCache, também codificado para URL;
- `MASTER_KEY` e `SERVICE_API_KEY`;
- credenciais temporárias do Academy apenas quando não houver LabRole disponível no host.

3. Inicialize as tabelas com os arquivos `db/init.sql` de auth, flag e targeting. Os RDS foram criados sem `DBName`; por isso as URLs usam o banco padrão `postgres` em três instâncias separadas.

## Execução

```powershell
docker compose --env-file .env.aws -f docker-compose.aws.yml config
docker compose --env-file .env.aws -f docker-compose.aws.yml pull
docker compose --env-file .env.aws -f docker-compose.aws.yml up -d --wait
docker compose --env-file .env.aws -f docker-compose.aws.yml ps
```

Para encerrar somente os contêineres de aplicação:

```powershell
docker compose --env-file .env.aws -f docker-compose.aws.yml down
```

## Diferenças em relação ao ambiente local

- Não existem serviços `postgres-*`, `redis` ou `dynamodb-local` neste Compose.
- `AWS_SQS_ENDPOINT_URL` e `AWS_DYNAMODB_ENDPOINT_URL` não são definidos; os SDKs usam os endpoints oficiais da AWS.
- O SQS real é `https://sqs.us-east-1.amazonaws.com/058264096738/evaluation-analytics-queue`.
- O ElastiCache exige `rediss://`, token de autenticação e cliente cluster. Por isso o evaluation usa a imagem `v3`, com `go-redis/v9`, e `REDIS_CLUSTER_MODE=true`.
- Credenciais não ficam no YAML nem no repositório.
