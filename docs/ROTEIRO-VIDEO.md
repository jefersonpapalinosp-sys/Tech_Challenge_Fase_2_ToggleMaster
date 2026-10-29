# Roteiro de demonstração

1. Apresentar o diagrama em `docs/ARQUITETURA.md`.
2. Executar `docker compose up -d --build`.
3. Mostrar `docker compose ps` com os 9 containers saudáveis.
4. Executar `scripts/test-local.ps1` e mostrar o evento no DynamoDB local.
5. Mostrar os cinco Dockerfiles multi-stage.
6. No Kubernetes, mostrar `kubectl get pods,svc,ingress,hpa -n togglemaster`.
7. Fazer uma chamada pelo Ingress para `/evaluation/evaluate`.
8. Executar carga com `scripts/load-test.ps1` e acompanhar `kubectl get hpa,pods -n togglemaster -w`.
9. Mostrar mensagens SQS e itens do DynamoDB pelo LocalStack.
10. Explicar PostgreSQL/RDS, Redis/ElastiCache e DynamoDB, além da escolha de HPA por CPU para compatibilidade com AWS Academy.

Mantenha dados pessoais, tokens e credenciais fora da gravação.
