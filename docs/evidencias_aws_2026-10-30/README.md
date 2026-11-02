# Evidencias AWS - ToggleMaster - 2026-10-30

Capturas geradas de consultas somente leitura na conta 533267349027, região us-east-1.
Nenhuma senha, token, MASTER_KEY ou API key foi incluída.

As imagens são evidências técnicas produzidas com AWS CLI e `kubectl`; não são capturas da interface autenticada do Console AWS.

A sequência dinâmica do HPA foi concluída às 22:34: baseline `1/1`, scale-out estabilizado em `2/2 Running` com CPU `42%/30%` e retorno a `1/1` após a carga.

- [Identidade AWS e contexto da coleta](01_identidade.png)
- [EKS e Managed Node Group](02_eks_nodegroup.png)
- [Repositórios e imagens no Amazon ECR](03_ecr.png)
- [Três bancos PostgreSQL no Amazon RDS](04_rds.png)
- [ElastiCache Redis com TLS e autenticação](05_elasticache.png)
- [Fila SQS tgmqueue](06_sqs.png)
- [Tabela DynamoDB ToggleMasterAnalytics](07_dynamodb.png)
- [Security Groups: EKS para RDS e Redis](08_security_groups.png)
- [Workloads, pods, serviços, Ingress e HPA](09_kubernetes.png)
- [External Secrets sincronizados](10_external_secrets.png)
- [Load Balancer do ingress-nginx](11_load_balancer.png)
- [AWS Secrets Manager: nomes e datas, sem valores](12_secrets_names.png)
- [HPA antes, durante e depois](13_hpa_antes_durante_depois.png)
