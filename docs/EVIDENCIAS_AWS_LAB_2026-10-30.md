# Evidências finais — AWS Lab 2 ToggleMaster

**Data:** 30/10/2026  
**Conta:** `533267349027`  
**Região:** `us-east-1`

## Infraestrutura confirmada

- EKS `ekstogglemaster` ativo, Kubernetes 1.37.
- Managed Node Group `tgmnodegroup` ativo, escala mínima/desejada/máxima `1/2/4`.
- Dois nós `t3.medium` Ready, IMDSv2 obrigatório e hop limit 2.
- Três RDS PostgreSQL privados e disponíveis: `db-authservice`, `dbflags` e `dbtargeting`.
- ElastiCache `redisevaluation` disponível, cluster mode, TLS, criptografia em repouso e AUTH token obrigatório.
- SQS `tgmqueue` com criptografia gerenciada pela AWS.
- DynamoDB `ToggleMasterAnalytics` ativa em `PAY_PER_REQUEST`.
- Classic Load Balancer internet-facing com os dois nós EKS `InService`.

## Imagens publicadas no ECR

- `namespace/auth-service:v1`
- `namespace/lag-service:v1` — repositório definido para o `flag-service`.
- `namespace/targeting-service:v1`
- `namespace/evaluation-service:v3`
- `namespace/analytics-service:v1`

O repositório ECR adicional e vazio `namespace/flag-service` foi removido; o `flag-service` permanece publicado no repositório existente `namespace/lag-service`.

## Estado Kubernetes

- Cinco Deployments de aplicação em `1/1`, sem reinicializações.
- Três Jobs SQL com `Complete`: auth, flag e targeting.
- ClusterSecretStore `aws-secrets-manager` com `Valid=True`.
- Quatro ExternalSecrets com `SecretSynced=True`.
- Quatro rotas Ingress publicadas: `/auth`, `/flags`, `/rules` e `/evaluate`.
- HPAs de evaluation e analytics configurados entre 1 e 5 réplicas, alvo de CPU de 30%.

## Teste ponta a ponta

1. API key de teste criada sem impressão do valor.
2. Flag e regra de targeting `PERCENTAGE=100` criadas pelo Load Balancer.
3. `/evaluate` respondeu `result=true`.
4. Evaluation publicou o evento no SQS.
5. Analytics consumiu a mensagem e gravou no DynamoDB.
6. A consulta filtrada confirmou pelo menos um item para a flag do smoke test.
7. Ao final, a fila apresentou 0 mensagens visíveis e 0 em processamento.

## Evidência de HPA

- Estado inicial: 1 réplica, CPU 1% / alvo 30%.
- Durante a carga: CPU 206%, HPA solicitou 5 réplicas.
- Scale-out observado: máximo de 5 réplicas.
- Após remover a carga: CPU retornou a 1% e o HPA reduziu para 1 réplica.
- Os pods temporários de carga foram removidos automaticamente.
- Auditoria final do Analytics: 1 réplica atual/desejada, CPU 1% / alvo 30%, `AbleToScale=True`, `ScalingActive=True` e `ScalingLimited=False`.

## Segurança aplicada

- Security Group do EKS autorizado em TCP 5432 nos três RDS.
- Security Group do EKS autorizado em TCP 6379 no Redis.
- AUTH token do Redis gerado sem exposição, armazenado em `togglemaster/evaluation` e aplicado com transição `ROTATE` → `SET`.
- Nova conexão autenticada do Evaluation Service confirmada; tentativa sem token recusada com `NOAUTH`.
- Nenhuma credencial AWS estática foi gravada nos manifestos.
- Os quatro segredos de aplicação permanecem no AWS Secrets Manager.
- Containers executam sem root, com filesystem somente leitura e capabilities removidas.

Nenhuma senha, token, MASTER_KEY ou API key foi incluída neste documento.
