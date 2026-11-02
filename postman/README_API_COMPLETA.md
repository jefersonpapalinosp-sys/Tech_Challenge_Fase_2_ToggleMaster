# Pacote Postman completo do ToggleMaster

## Importação

Importe no Postman:

1. `ToggleMaster_API_Completa.postman_collection.json`
2. `ToggleMaster_API_Completa.postman_environment.json`

Selecione o ambiente **ToggleMaster AWS - API Completa**.

## Chaves

### MASTER_KEY

Localização: AWS Secrets Manager → `togglemaster/auth` → recuperar valor → campo `MASTER_KEY`.

Cole somente no valor local da variável secreta `master_key`. A MASTER_KEY serve apenas para criar novas API keys.

### API_KEY

Execute `00 - Auth Service/ Criar API key para Postman`. A resposta contém uma chave iniciada por `tm_key_`. O script pós-resposta salva automaticamente essa chave na variável `api_key` do ambiente.

O auth-service armazena apenas o hash da API key; por isso o valor em texto aparece somente na resposta de criação. Para um teste novo, gere outra chave.

### SERVICE_API_KEY

O segredo `togglemaster/evaluation` possui a chave interna usada pelo Evaluation Service. Não é necessário reutilizá-la no Postman, porque a coleção cria uma chave dedicada.

### Redis, bancos e AWS Academy

- O token do Redis está protegido dentro de `REDIS_URL` em `togglemaster/evaluation`. Ele não é usado no Postman.
- As URLs e senhas dos bancos estão nos segredos `togglemaster/auth`, `togglemaster/flag` e `togglemaster/targeting`. Elas não são usadas no Postman.
- As credenciais temporárias do AWS Academy ficam em **AWS Details → AWS CLI**. Elas são usadas pela AWS CLI, nunca como Bearer Token das APIs.

Não coloque valores reais de segredo nos arquivos exportados ou em capturas de tela.

## Ordem recomendada

1. Preencha `master_key`.
2. Execute as três requisições de `00 - Auth Service` na ordem.
3. Execute `01 - Preparar flag e regra`.
4. Use as pastas dos serviços.
5. Execute `99 - Limpeza` ao terminar.

Para o health check do Analytics, mantenha aberto:

```powershell
kubectl port-forward -n analytics-service service/analytics-service 8005:8005
```
