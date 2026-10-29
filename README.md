# ToggleMaster — Tech Challenge Fase 2

Implementação completa, local e em AWS, da arquitetura de microsserviços descrita no arquivo **POSTECH - Tech Challenge - Fase 2**.

## O que está incluído

- 5 microsserviços: `auth`, `flag`, `targeting`, `evaluation` e `analytics`.
- 5 Dockerfiles multi-stage, com processos executados por usuários sem privilégios.
- Docker Compose com exatamente 9 containers: 5 aplicações, 2 PostgreSQL, 1 Redis e 1 LocalStack.
- SQS e DynamoDB totalmente locais pelo LocalStack.
- Teste ponta a ponta: autenticação → flag → targeting → evaluation → SQS → analytics → DynamoDB.
- Manifestos Kubernetes com Namespace, Deployments/StatefulSets, Services, ConfigMap, Secret, Ingress, probes, requests/limits e HPA.
- Scripts PowerShell para build, execução, validação, carga e Kubernetes local.

## Arquitetura local

| Componente | Porta | Dependência de dados |
|---|---:|---|
| auth-service | 18001 → 8001 | PostgreSQL `auth_db` |
| flag-service | 18002 → 8002 | PostgreSQL `flags_db` |
| targeting-service | 18003 → 8003 | PostgreSQL `targeting_db` |
| evaluation-service | 18004 → 8004 | Redis + SQS local |
| analytics-service | 18005 → 8005 | SQS + DynamoDB local |

O segundo PostgreSQL contém dois bancos lógicos, preservando os três bancos isolados pedidos para produção e as duas instâncias exigidas no Compose local.

## Início rápido

Pré-requisito: Docker Desktop em execução com containers Linux.

```powershell
Copy-Item .env.example .env
.\scripts\start-local.ps1
.\scripts\test-local.ps1
```

O primeiro comando de subida baixa as imagens-base e compila os serviços. Para acompanhar:

```powershell
docker compose ps
docker compose logs -f
```

Para encerrar preservando os dados:

```powershell
.\scripts\stop-local.ps1
```

Para apagar também os volumes locais e recomeçar do zero:

```powershell
.\scripts\stop-local.ps1 -RemoveVolumes
```

## Endpoints

```text
GET  http://localhost:18001/health
POST http://localhost:18001/admin/keys
GET  http://localhost:18001/validate

GET/POST            http://localhost:18002/flags
GET/PUT/DELETE      http://localhost:18002/flags/{name}

POST                http://localhost:18003/rules
GET/PUT/DELETE      http://localhost:18003/rules/{flag_name}

GET  http://localhost:18004/evaluate?user_id=usuario&flag_name=nome-da-flag
GET  http://localhost:18005/health
```

## Kubernetes local

O projeto inclui um cluster isolado com `kind`; não é necessário ativar o Kubernetes do Docker Desktop. A primeira execução baixa o executável local, cria o cluster, instala Metrics Server e Nginx Ingress, carrega as cinco imagens e aplica os manifests:

```powershell
.\scripts\setup-kind.ps1
.\scripts\test-k8s.ps1
kubectl get pods -n togglemaster
kubectl get hpa -n togglemaster
```

O Ingress fica disponível em `http://localhost:18080`, usando o cabeçalho `Host: togglemaster.local`. O script de teste configura esse cabeçalho automaticamente. Para reconstruir e reaplicar depois:

```powershell
.\scripts\deploy-k8s.ps1
```

Consulte [k8s/README.md](k8s/README.md) para os detalhes. A arquitetura, decisões e correspondência com o enunciado estão em [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Docker Compose com recursos AWS

O arquivo `docker-compose.aws.yml` executa somente as cinco aplicações e usa os recursos reais da conta AWS: imagens do ECR, três RDS privados, ElastiCache cluster, SQS e DynamoDB. Ele deve ser executado em um host com rota para a VPC dos bancos e do cache.

```powershell
Copy-Item .env.aws.example .env.aws
# Preencha as senhas, tokens e chaves em .env.aws
docker compose --env-file .env.aws -f docker-compose.aws.yml pull
docker compose --env-file .env.aws -f docker-compose.aws.yml up -d --wait
```

Consulte [docs/COMPOSE-AWS.md](docs/COMPOSE-AWS.md) para endpoints, restrições de rede e preparação dos bancos. O Compose local original permanece inalterado.

## Implantação no EKS

O ambiente AWS Academy foi implantado no cluster `eks-togglemaster`, em `us-east-1`, usando ECR, três RDS PostgreSQL, ElastiCache Redis Cluster com TLS, SQS, DynamoDB, Secrets Manager, External Secrets Operator, HPA e Nginx Ingress publicado por NLB.

Endpoint atual:

```text
http://ae6a5981f8069438481a714114fef81d-9676d8a498457cbb.elb.us-east-1.amazonaws.com
```

Rotas públicas: `/auth`, `/flags`, `/rules` e `/evaluate`. O fluxo Auth → Flag → Targeting → Evaluation → SQS → Analytics → DynamoDB foi validado ponta a ponta. Consulte [k8s-aws/README.md](k8s-aws/README.md) para o estado implantado e [docs/RELATORIO-IMPLANTACAO-AWS.md](docs/RELATORIO-IMPLANTACAO-AWS.md) para o relatório final. A versão visual em Word está em `docs/Relatorio_Implantacao_AWS_ToggleMaster.docx`.

## Segurança local

As credenciais versionadas são exclusivamente de desenvolvimento local. Produção deve usar um gerenciador de segredos, credenciais rotacionadas e recursos gerenciados (RDS, ElastiCache, DynamoDB e SQS).
