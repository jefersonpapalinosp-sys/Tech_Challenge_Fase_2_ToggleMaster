# Teste de carga do ToggleMaster no Postman

## Arquivos para importar

- `ToggleMaster_Carga.postman_collection.json`
- `ToggleMaster_AWS_Carga.postman_environment.json`

## Preparação

1. No Postman, use **Import** e importe os dois arquivos.
2. Selecione o ambiente **ToggleMaster AWS - Carga**.
3. Preencha apenas o valor local/segredo de `api_key`. Use uma chave criada pelo `auth-service`, não a `MASTER_KEY`.
4. Se o nome já tiver sido usado, altere `flag_name` para outro valor único.
5. Execute a pasta **01 - Preparação** uma única vez, no modo funcional.

## Executar a carga

1. Selecione somente a pasta **02 - Teste de carga**.
2. Clique em **Run** e selecione o tipo **Performance**.
3. Para uma primeira execução local, use **10 usuários virtuais por 2 minutos**.
4. Para demonstrar o HPA, aumente gradualmente para **20 a 30 usuários virtuais por 5 minutos**.
5. Prefira o método **App/local** para não consumir horas de usuários virtuais do Postman Cloud.

Cada usuário virtual repete a chamada `/evaluate` em paralelo. A coleção valida:

- resposta HTTP 200;
- decisão da flag igual a `true`;
- tempo de resposta inferior a `max_response_ms` (padrão: 2000 ms).

Cada avaliação também gera uma mensagem no SQS e uma gravação pelo Analytics no DynamoDB. Portanto, aumente a carga gradualmente para não consumir desnecessariamente a cota do AWS Academy.

Durante a execução, o HPA pode ser acompanhado com:

```powershell
kubectl get hpa -n evaluation-service -w
```

E os pods com:

```powershell
kubectl get pods -n evaluation-service -w
```

## Limpeza

Ao terminar, execute a pasta **03 - Limpeza** uma única vez. Ela remove a regra e a flag de carga. Os eventos analíticos já gravados no DynamoDB são mantidos como evidência do teste.
