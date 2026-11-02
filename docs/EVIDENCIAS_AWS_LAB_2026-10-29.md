# Evidências finais — AWS Lab ToggleMaster

**Data:** 2026-10-29 23:04 BRT  
**Conta:** 058264096738  
**Região:** us-east-1

## Estado confirmado

- EKS `eks-togglemaster` ACTIVE, Kubernetes 1.37.
- Managed Node Group `eks-nodegroup-academy-v2` ACTIVE, escala 1/2/4.
- Launch Template `lt-eks-togglemaster-academy` (`lt-0e7bf115323348621`), versão 2.
- Dois nós `t3.medium` AL2023 Ready, IMDSv2 obrigatório e hop limit 2.
- Cinco Deployments de aplicação 1/1.
- Três Jobs SQL Complete.
- ClusterSecretStore Valid e quatro ExternalSecrets SecretSynced/Ready.
- NLB ACTIVE, targets HTTP/HTTPS healthy e `/auth/health` HTTP 200.
- HPAs de evaluation e analytics com CPU 1%/30% e uma réplica.

## Smoke test sem carga

1. API key existente validada sem impressão do valor.
2. Flag temporária e regra `PERCENTAGE=100` criadas.
3. `/evaluate` retornou `result=true`.
4. Evaluation registrou envio ao SQS.
5. Analytics registrou persistência no DynamoDB.
6. Consulta filtrada no DynamoDB passou de 0 para 1.
7. Fila terminou com 0 mensagens visíveis e 0 em processamento.
8. Flag e regra temporárias removidas.

## Limitações declaradas

- Não houve teste de carga.
- HPAs: **Configurado — demonstração de scale-out pendente**.
- IMDS hop 2 + políticas de recurso é workaround acadêmico; produção deve usar Pod Identity ou IRSA.
- Base64 em Kubernetes Secret não é criptografia.
- ElastiCache está superdimensionado (3 shards × 3 nós `cache.r7g.large`); right-size recomendado.

Nenhum valor sensível foi registrado neste arquivo.
