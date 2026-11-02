"""Build the recording kit from reviewed text and dated project evidence."""
from pathlib import Path
import html
import json
import shutil
import sys
from docx import Document
from docx.shared import Inches, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'apresentacao'
OUT.mkdir(exist_ok=True)
STEM = 'ToggleMaster_Fase2_Roteiro_Final_Gravacao_VALIDADO'
ROTEIRO_ONLY = '--roteiro-only' in sys.argv
PRESENTERS = 'Dois apresentadores: A conduz as deixas 1–18 (0:00–9:00), seguindo os itens 1, 2 e 3 do enunciado: Docker, infraestrutura AWS e configuração do cluster. B conduz as deixas 19–37 (9:00–19:00), seguindo os itens 4 e 5: manifestos, escalabilidade, demonstrações e encerramento.'
SCREEN_DUTIES = 'Cada apresentador também executa os comandos e troca as telas da sua própria parte. Primeiro prepara a tela e espera o resultado; depois faz a fala. Na deixa 18, A passa a palavra a B, que assume a tela na deixa 19. As duas partes podem ser gravadas separadamente e unidas na edição.'
LB = 'http://a5bc56a01f92c4e85887af601f04b84e-1447597342.us-east-1.elb.amazonaws.com'

# Number, target timestamp, screen/operator instruction, spoken text.
CUES = [
(1,'0:00','Slide 1: abertura e integrantes.','Olá! Somos Afonso Victoriano Franco, Cesar Augusto Ferreira Alves, Jeferson Lima Papalino, Jonatas Ariel Nunes e Willian Felix Corrêa. Vamos apresentar o ToggleMaster na Fase 2: a evolução de um monolito para cinco microsserviços no Amazon EKS.'),
(2,'0:25','Slide 2: arquitetura.','Na Fase 1, o sistema era um monolito em EC2 conectado ao PostgreSQL no RDS. Nesta fase, separamos as responsabilidades para permitir implantação e escala independentes.'),
(3,'0:50','Slide 2: apontar cada serviço.','Auth, em Go, cria e valida chaves de API. Flag, em Python, mantém as definições das feature flags. Targeting, também em Python, mantém as regras de segmentação. Evaluation, em Go, calcula a decisão e usa cache Redis. Analytics, em Python, consome eventos do SQS e os persiste no DynamoDB.'),
(4,'1:25','Slide 2: evaluation → SQS → analytics → DynamoDB.','O evaluation dispara a publicação do evento em uma goroutine. A resposta HTTP não aguarda a persistência analítica. O worker consome a fila e grava no DynamoDB. Por isso, além da resposta da API, verificamos o evento persistido para comprovar o fluxo completo.'),
(5,'1:55','apoio_codigo/auth-service.Dockerfile e flag-service.Dockerfile.','Usamos builds multi-stage. O serviço Go é compilado em um estágio e leva apenas o binário e as dependências de execução para Alpine. Em Python, preparamos as dependências no builder e as copiamos para a imagem final. Os containers das aplicações executam como usuário não root.'),
(6,'2:25','Comando 02: docker images.','Estas são as imagens construídas. A separação dos estágios evita incluir o compilador e arquivos de build na imagem de execução. Os tamanhos devem ser comparados a partir desta saída, sem confundir tamanho comprimido no ECR com tamanho local.'),
(7,'2:45','Comando 01: docker compose up; depois docker compose ps.','O ambiente local usa nove containers: cinco aplicações, dois PostgreSQL, Redis e LocalStack. O enunciado cita DynamoDB Local; utilizamos LocalStack para emular tanto DynamoDB quanto SQS. É uma adaptação funcional, que explicitamos na entrega.'),
(8,'3:15','Comando 02: health checks nas portas do host 18001 a 18005.','Os cinco health checks confirmam a disponibilidade dos serviços locais. As portas internas são 8001 a 8005; no computador, o Compose publica por padrão 18001 a 18005.'),
(9,'3:35','Slide 6: desafios; trecho opcional.','Durante a implementação, tratamos diferenças entre Windows e containers, autenticação entre serviços e compatibilidade do cliente Redis com TLS e cluster mode.'),
(10,'3:55','EKS no Console ou evidência 02, identificada como coleta datada.','Na AWS Academy, usamos a conta 533267349027 e a região us-east-1. O cluster se chama ekstogglemaster. As capturas de apoio foram coletadas em 30 de outubro de 2026; o estado ao vivo deve ser conferido antes da gravação.'),
(11,'4:20','Evidência 02: Managed Node Group.','O Managed Node Group tgmnodegroup usa instâncias t3.medium: mínimo de um nó, dois desejados e máximo de quatro. A capacidade configurada do grupo de nós é diferente da escala automática dos pods feita pelo HPA.'),
(12,'4:50','Evidência 03: cinco ECR.','Cada serviço tem um repositório ECR privado. O repositório do flag-service foi criado com o nome namespace/lag-service, e esse é o nome utilizado no deployment. O evaluation está na tag v3; os demais, na v1.'),
(13,'5:20','Evidência 04: RDS.','Os três PostgreSQL são db-authservice, dbflags e dbtargeting. Na coleta, todos estavam disponíveis, com armazenamento criptografado e acesso público desabilitado. Cada serviço usa o seu banco e esquema, mantendo a separação dos domínios.'),
(14,'6:00','Evidência 05: Redis.','O cluster redisevaluation usa TLS, autenticação por token e cluster mode. O evaluation armazena por 30 segundos os dados combinados de flag e regra. Em um cache hit, evita novas chamadas aos serviços de flags e targeting.'),
(15,'6:40','Evidência 07 e slide 3: armazenamentos.','A tabela ToggleMasterAnalytics guarda os eventos, com event_id como chave de partição. RDS atende os dados relacionais; Redis atende o cache temporário; DynamoDB atende a persistência analítica. No scan registrado, encontramos eventos da flag load-postman-fiap.'),
(16,'7:15','Evidência 06: SQS tgmqueue.','A fila Standard tgmqueue desacopla a avaliação do processamento analítico. O worker remove a mensagem depois de gravar o evento. Idempotência, fila de mensagens mortas e uma estratégia de retry são evoluções importantes para produção.'),
(17,'7:45','Evidência 08: Security Groups.','Os bancos e o Redis usam endpoints privados. Há regras para o grupo de segurança do EKS nas portas 5432 e 6379. Nos grupos RDS também aparece uma regra administrativa para um IP /32. Portanto, as regras não são exclusivamente do EKS; a existência da regra isoladamente não torna o banco público.'),
(18,'8:25','A mostra o slide 2 e passa a palavra a B às 9:00.','Com as imagens e os serviços gerenciados preparados, encerro a primeira parte. Agora passo a palavra ao apresentador B, que vai demonstrar a execução no Kubernetes, o fluxo funcional e a escalabilidade.'),
(19,'9:00','B assume a tela e abre apoio_codigo/flag-kustomization.yaml e flag-deployment.yaml.','Obrigado, A. Vou apresentar a execução no Kubernetes e os testes. Os manifestos ficam em k8s-aws, organizados por serviço. O Kustomize reúne os recursos e aplica o namespace final. Por isso, o namespace do arquivo-base pode ser diferente do namespace resultante no cluster.'),
(20,'9:20','Comando 04: contexto e namespaces.','Os namespaces implantados são auth-service, flag-service, targeting-service, evaluation-service e analytics-service. Um endereço interno é flag-service.flag-service.svc.cluster.local. Conferimos o contexto do kubectl antes de executar comandos.'),
(21,'9:45','apoio_codigo/flag-deployment.yaml: probes, resources e securityContext.','Os Deployments definem probes, requests e limits. O exemplo de flag executa sem root, sem elevação de privilégios, com capabilities removidas e raiz somente leitura. Readiness decide quando o pod recebe tráfego; liveness permite reiniciar um container que deixou de responder.'),
(22,'10:20','Comando 04 ou evidências 10 e 12: somente nomes e status.','O Secrets Manager guarda credenciais, e o External Secrets Operator sincroniza os quatro segredos. No Academy usamos a LabRole dos nós, com IMDSv2 obrigatório e hop limit 2. Isso amplia o acesso dos pods às credenciais do nó; em produção preferimos identidade e permissões específicas por serviço.'),
(23,'10:55','Comando 04: kubectl get jobs -A. Confirmar status antes da fala.','Os Jobs de inicialização aplicam os scripts SQL de auth, flag e targeting. A definição fica versionada. Exibimos os estados observados; se os Jobs já tiverem sido removidos, mostramos os manifestos sem afirmar que há três Jobs concluídos na tela.'),
(24,'11:15','Comando 04 ou evidência 09: deployments, pods e services.','Os cinco serviços são expostos internamente por Services ClusterIP. Esta tela permite conferir réplicas disponíveis e pods prontos, em vez de considerar apenas a existência dos Deployments.'),
(25,'11:40','Evidência 11 e comando 04: Ingress.','O ambiente coletado utiliza um Classic Load Balancer com ingress-nginx. As rotas externas são /auth, /flags, /rules e /evaluate. O analytics é um worker interno. O tipo observado difere do ALB ou NLB mencionado no enunciado; essa adequação continua como ponto de revisão da entrega.'),
(26,'12:05','Slide 7: evolução; trecho opcional.','Como evolução da entrada externa, planejamos HTTPS e revisão do controller e do tipo de balanceador. A migração precisa preservar as rotas usadas pelos clientes.'),
(27,'12:20','Comando 05 ou Postman: preparação de autenticação fora da gravação.','O fluxo usa uma API key criada pelo auth-service. A chave fica em uma variável secreta. Durante a apresentação, mostramos a validação e as respostas funcionais sem exibir credenciais.'),
(28,'12:40','Comando 05 ou Postman: flag e regra de 100%.','Cadastramos uma flag com nome exclusivo e uma regra de targeting de 100%. Para repetir a demonstração, usamos um novo nome e evitamos confundir um conflito de cadastro com sucesso.'),
(29,'13:00','Resposta evaluation + correlação no DynamoDB do teste.','A avaliação retorna result true. Esse retorno confirma a decisão funcional, mas sozinho não comprova a entrega do evento ao SQS: a publicação é assíncrona. O teste também procura o mesmo nome de flag no DynamoDB para verificar o processamento pelo analytics.'),
(30,'13:30','Comando 06: métricas e HPA; evidência 13.','Os dois HPAs usam CPU média, com alvo de 30% do request e faixa de uma a cinco réplicas. O Metrics Server fornece as métricas. A profundidade da fila não é a métrica configurada para o analytics.'),
(31,'14:00','Comando 06: dois geradores; ou abrir evidência 13 como registro do ensaio.','No ensaio documentado, dois geradores fizeram chamadas ao evaluation. Começamos com uma réplica disponível e CPU abaixo do alvo. Mantemos o teste limitado no tempo e acompanhamos os pods.'),
(32,'14:30','Evidência 13: snapshot 42%/30%, deployment 2/2.','A CPU chegou a 42% do request, acima do alvo de 30%. O HPA aumentou as réplicas e capturamos o Deployment com duas de duas disponíveis e os dois pods Running. A linha do tempo ainda registra três réplicas após o encerramento da carga.'),
(33,'15:00','Evidência 13: retorno 1/1; analytics permaneceu em 1.','Após interromper a carga, o evaluation voltou a uma réplica. O HPA reduz pods, não desliga instâncias EC2. O resumo maxEvaluation igual a 2 desse arquivo não acompanha o pico posterior de 3: usamos a linha do tempo completa. Neste ensaio o analytics permaneceu em uma réplica.'),
(34,'15:35','Comando 07: enviar mensagens sintéticas, observar analytics e correlacionar DynamoDB. PENDENTE DE ENSAIO.','O enunciado exige também carga enviada manualmente ao SQS e escala do analytics. O HPA está configurado por CPU; uma fila cheia não garante CPU acima do alvo. Só apresentaremos a escala como demonstrada se forem observadas múltiplas réplicas disponíveis. Os eventos enviados diretamente têm um marcador próprio e não devem ser descritos como avaliações HTTP.'),
(35,'17:25','Slide 6: desafios e lições.','Aprendemos a validar dependências antes da carga, conferir o contexto e coletar evidências datadas. Quando o Lab recriou os nós, o hop limit voltou a 1 e o analytics perdeu acesso às credenciais. A restauração autorizada para 2 recuperou o serviço. Essa solução é específica do laboratório.'),
(36,'18:10','Slide 7: próximos passos; trecho opcional.','Os próximos passos incluem identidade por serviço, HTTPS, observabilidade, idempotência e DLQ, revisão do balanceador e autoscaling dos nós. Precisamos ainda concluir a demonstração de escala do analytics exigida no vídeo.'),
(37,'18:40','Slide 8: encerramento.','Obrigado! Apresentamos o ToggleMaster conteinerizado e executado no EKS, integrado ao RDS, Redis, SQS e DynamoDB. As evidências e os arquivos de reprodução acompanham o projeto.'),
]

# Reuse verified descriptions while sequencing the recording by the assignment.
PREVIOUS = {n:(screen,speech) for n,_,screen,speech in CUES}
def reuse(n, time, previous, screen=None):
    old_screen,speech=PREVIOUS[previous]
    return (n,time,screen or old_screen,speech)

CUES = [
(1,'0:00','Slide 1: abertura. Mostrar a sequência dos itens 1 a 5 do enunciado.','Olá! Somos o grupo do ToggleMaster, com os integrantes indicados na tela. Esta apresentação segue a ordem do Tech Challenge: conteinerização, infraestrutura, configuração do cluster, manifestos e escalabilidade. Eu apresento os três primeiros itens; B continua com implantação e demonstrações.'),
reuse(2,'0:25',3,'Item 1, página 4. Identificar as pastas dos cinco microsserviços.'),
reuse(3,'0:50',5),
reuse(4,'1:15',6,'Comando 02: imagens construídas.'),
reuse(5,'1:35',7,'Comando 01: docker compose up e os nove containers. Slide 4 como apoio.'),
reuse(6,'2:05',8,'Comando 02: health checks nas portas publicadas.'),
reuse(7,'2:30',10,'Item 2, páginas 4–6. EKS no Console ou evidência 02, com data da coleta.'),
reuse(8,'3:00',11,'Evidência 02: tgmnodegroup, LabRole e escala 1/2/4. Conferir a role no Console.'),
reuse(9,'3:30',12,'Evidência 03: ECR e imagens.'),
reuse(10,'4:00',13,'Evidência 04: os três RDS.'),
reuse(11,'4:40',14,'Evidência 05: ElastiCache.'),
reuse(12,'5:20',15,'Evidência 07: definição da tabela DynamoDB. Slide 3 para comparar os armazenamentos.'),
reuse(13,'5:50',16,'Evidência 06: SQS tgmqueue.'),
reuse(14,'6:15',17,'Evidência 08: Security Groups e endpoints privados.'),
(15,'6:40','06_URLS_E_NOMES_DO_LAB.txt: nomes e endpoints sem senhas.','Concluímos o checklist de infraestrutura anotando endpoints, nome da tabela e identificação da fila. Endereços e configurações não sensíveis vão para ConfigMaps; credenciais são guardadas no Secrets Manager. No Academy usamos a LabRole existente, conforme a opção A do enunciado.'),
(16,'7:00','Item 3, página 6. Comando 03: Metrics Server, kubectl top nodes e top pods.','Agora configuramos o cluster, começando pelo Metrics Server. Ele fornece as métricas de CPU e memória de nós e pods, necessárias ao HPA. Antes de demonstrar escala, conferimos que as métricas estão disponíveis. A decisão de aumentar réplicas será mostrada no item 5.'),
(17,'7:45','Item 3, páginas 6–7. Comando 03: controller ingress-nginx, Helm e Service; evidência 11.','O segundo componente é o Nginx Ingress Controller, instalado via Helm. O Service publica a entrada externa. Na coleta, o recurso criado era um Classic Load Balancer, enquanto o enunciado menciona ALB ou NLB. Essa divergência está registrada como ponto de adequação. As rotas das aplicações serão mostradas com os manifestos, no item 4.'),
(18,'8:30','A encerra o item 3 e passa a palavra a B às 9:00.','Concluímos Docker, infraestrutura AWS e configuração do cluster, nessa ordem. Agora passo a palavra ao apresentador B, que seguirá com os manifestos, o acesso externo e a escalabilidade exigida no desafio.'),
(19,'9:00','Item 4, páginas 7–8. Comando 04: contexto, namespaces e flag-kustomization.yaml.','Obrigado, A. Começo os manifestos pela ordem do documento: Namespace, Deployment, Service, Secret e ConfigMap. Usamos os namespaces auth-service, flag-service, targeting-service, evaluation-service e analytics-service. O Kustomize aplica esses nomes finais aos recursos de cada serviço.'),
(20,'9:20','apoio_codigo/flag-deployment.yaml: imagem ECR e réplicas.','O Deployment define os pods e a imagem publicada no ECR. Para o flag-service, usamos namespace/lag-service:v1, que é o nome real criado na conta. Os cinco Deployments podem ser atualizados e escalados separadamente.'),
(21,'9:45','Comando 04: Services ClusterIP dos cinco namespaces.','Cada aplicação tem um Service ClusterIP para comunicação dentro do cluster. Um exemplo de DNS é flag-service.flag-service.svc.cluster.local. O Service mantém um endereço estável enquanto os pods são substituídos.'),
(22,'10:05','Comando 04 ou evidências 10 e 12: Secrets/ExternalSecrets, apenas nomes e status.','O Secrets Manager armazena os valores sensíveis e o External Secrets Operator sincroniza os quatro segredos. Os Secrets Kubernetes usam Base64 no campo data: isso é codificação, não criptografia. Mostramos apenas nomes e status. No Academy, o acesso pela LabRole dos nós depende do IMDSv2 com hop limit 2.'),
(23,'10:35','apoio_codigo/evaluation-configmap.yaml: nomes das variáveis e URLs internas.','Os ConfigMaps recebem dados não sensíveis, como região, endpoints internos e URL da fila. Senhas e tokens ficam nos Secrets. Assim, configuração e código ficam separados, e cada Deployment referencia os recursos de que precisa.'),
(24,'11:00','Comando 04: Ingress e apoio_codigo/auth-ingress.yaml.','Os manifestos Ingress definem as rotas /auth, /flags, /rules e /evaluate sobre a mesma entrada externa. O controller traduz essas regras em roteamento para os Services. O analytics não tem rota pública porque é um worker interno.'),
reuse(25,'11:25',21,'Item 4: boas práticas. Mostrar probes, resources e securityContext no flag-deployment.yaml.'),
(26,'11:50','Comando 04: Jobs, Deployments e cinco pods.','Os Jobs versionam a inicialização SQL dos bancos. Conferimos os estados disponíveis no momento da gravação e os cinco microsserviços como pods prontos. Se os Jobs já tiverem sido removidos, mostramos seus manifestos sem afirmar que estão concluídos nesta tela.'),
(27,'12:10','Comando 05 ou Postman: validar chave, criar flag/regra e avaliar pelo Load Balancer.','Para comprovar o Ingress, usamos uma API key preparada sem exibi-la, criamos uma flag de nome exclusivo e uma regra de 100%, e chamamos /evaluate pelo Load Balancer. A resposta esperada é result true. Como o envio ao SQS é assíncrono, a confirmação do fluxo completo exige correlacionar essa flag no DynamoDB.'),
(28,'12:50','Item 5, página 8. apoio_codigo/evaluation-hpa.yaml e kubectl get hpa.','O HPA do evaluation usa a CPU média em relação ao request. No nosso ambiente, o alvo é 30%, com mínimo de uma e máximo de cinco réplicas. O valor de 70% citado no enunciado é um exemplo; a configuração e a evidência aqui usam 30%.'),
(29,'13:10','apoio_codigo/analytics-hpa.yaml.','O analytics também tem HPA por CPU, na faixa de uma a cinco réplicas. Ele não monitora diretamente o tamanho da fila: para escalar, o processamento precisa elevar a CPU acima do alvo. Ter mensagens pendentes não garante essa condição.'),
(30,'13:30','Item 5: justificar opção Academy; KEDA é alternativa opcional do enunciado.','Seguimos o HPA por CPU previsto para a opção AWS Academy. O enunciado apresenta KEDA como alternativa de escala pela fila em um ambiente com permissões adequadas. Nossa demonstração deve comprovar os dois HPAs; a do analytics ainda precisa ser concluída.'),
(31,'13:50','Demonstração, página 9. Comando 06; evidência 13.','Na prova do evaluation, dois geradores fizeram chamadas à API. Partimos de uma réplica. Com CPU de 42% para alvo de 30%, capturamos duas de duas réplicas disponíveis e os dois pods Running. Exibimos essa coleta como registro datado do ensaio.'),
(32,'14:25','Evidência 13: encerramento da carga e retorno a 1/1.','A linha do tempo ainda registra três réplicas após o encerramento da carga; depois o evaluation voltou a uma. O resumo maxEvaluation igual a 2 não acompanha esse pico posterior, por isso usamos a sequência completa. O HPA ajusta pods; reduzir instâncias exigiria também autoscaling dos nós.'),
(33,'15:00','Comando 07: enviar mensagens sintéticas manualmente para tgmqueue e anotar RunId.','Em seguida, conforme o enunciado, enviamos mensagens diretamente ao SQS. Cada evento tem user_id, flag_name, result e timestamp. O RunId identifica esse lote sintético, que não deve ser apresentado como tráfego de avaliação HTTP.'),
(34,'15:25','Comando 07: HPA e pods do analytics em watch. PENDENTE: registrar CPU e múltiplas réplicas disponíveis.','Agora verificamos se o processamento elevou a CPU e se o HPA do analytics criou novas réplicas. A evidência existente mostra uma réplica; portanto, este trecho ainda requer ensaio. Só diremos que o analytics escalou após observar múltiplas réplicas disponíveis. Caso contrário, essa exigência permanece pendente.'),
(35,'16:35','Comando 07: filtrar DynamoDB pelo RunId; separar do flag_name do teste HTTP.','Por fim, buscamos no DynamoDB os eventos do mesmo RunId enviado ao SQS. Para a prova HTTP, buscamos o nome exclusivo da flag daquele teste. Essa correlação diferencia os eventos sintéticos das avaliações da API e confirma a persistência pelo analytics.'),
(36,'17:20','Slides 2, 3 e 6: arquitetura, propósito dos armazenamentos e desafios.','A arquitetura separa cinco responsabilidades. RDS armazena dados relacionais, Redis mantém cache temporário e DynamoDB persiste os eventos analíticos. A fila desacopla avaliação e consumo. Um desafio do Academy foi a recriação dos nós com hop limit 1, que interrompeu o acesso do analytics às credenciais; a restauração autorizada para 2 recuperou o serviço. Esse acesso amplo pela LabRole é uma limitação do laboratório.'),
(37,'18:40','Slide 8: encerramento. Conferir checklist de entregáveis fora da gravação.','Obrigado! Apresentamos a solução seguindo os cinco itens do Tech Challenge. O roteiro, as evidências e os arquivos de reprodução acompanham o projeto. Antes da entrega final, concluiremos a prova de escala do analytics e revisaremos a adequação do balanceador ao enunciado.'),
]
SECTIONS = [(1,6,'A • Item 1 — Análise e Conteinerização (p. 4)'),(7,11,'A • Item 2 — Infraestrutura: EKS, ECR, RDS e Redis (pp. 4–5)'),(12,15,'A • Item 2 — DynamoDB, SQS e conexões (p. 6)'),(16,18,'A • Item 3 — Configurando o Cluster (pp. 6–7)'),(19,23,'B • Item 4 — Manifestos básicos (p. 7)'),(24,27,'B • Item 4 — Ingress e boas práticas (pp. 7–8)'),(28,30,'B • Item 5 — Configurando a Escalabilidade (p. 8)'),(31,35,'B • Demonstração de escala e persistência (p. 9)'),(36,37,'B • Arquitetura, desafios e encerramento (p. 9)')]
ORDER_MAP = '''SINCRONIZAÇÃO COM POSTECH - Tech Challenge - Fase 2.pdf
Referência: paginação impressa do enunciado (11 páginas).
Apresentador A: 0:00–9:00 / deixas 1–18. Apresentador B: 9:00–19:00 / 19–37.
Cada um controla as telas e os comandos da sua parte.

Item 1 / p. 4 / deixas 2–6: análise dos serviços -> Dockerfiles -> Compose.
Item 2 / pp. 4–6 / deixas 7–15: EKS -> Node Group -> ECR -> três RDS ->
ElastiCache -> DynamoDB -> SQS -> referências de conexão e rede.
Item 3 / pp. 6–7 / deixas 16–17: Metrics Server -> Nginx Ingress Controller.
Item 4 / pp. 7–8 / deixas 19–27: Namespace -> Deployment -> Service -> Secret ->
ConfigMap -> Ingress -> boas práticas -> pods/Jobs -> chamada pelo Load Balancer.
Item 5 / p. 8 / deixas 28–30: HPA evaluation -> HPA analytics -> opção KEDA.
Demonstração / p. 9 / deixas 31–35: carga evaluation -> scale-out/scale-in ->
envio manual SQS -> scale-out analytics -> dados correlacionados no DynamoDB.
Explicação / p. 9 / deixa 36: arquitetura -> desafios -> propósitos RDS/Redis/DynamoDB.
Encerramento / deixa 37; duração final inferior a 20 minutos.

CHECKLIST DOS ENTREGÁVEIS (páginas 9–10)
[ ] docker compose up e nove containers saudáveis (deixa 5).
[ ] Cluster em nuvem e cinco serviços como pods (7–8 e 26).
[ ] Ingress com chamada curl/Postman para o Load Balancer (27).
[ ] Carga evaluation com HPA e pods: mostrar coleta datada ou ensaio (31–32).
[ ] Envio manual de mensagens SQS (33).
[ ] Analytics escalando com múltiplas réplicas disponíveis (34: PENDENTE).
[ ] Dados correlacionados no DynamoDB (35).
[ ] Arquitetura, limitações da LabRole, justificativa HPA e três armazenamentos.
[ ] Relatório PDF/TXT: nomes, RM, Discord, links dos repositórios e do vídeo.
[ ] Vídeo salvo em local acessível e duração até 20 minutos.
Opcional: badge/perfil público Google Cloud Skills Boost (p. 10).

As caixas são para conferência final do vídeo, não status de provisionamento.
LocalStack substitui DynamoDB Local: adaptação declarada.
Classic LB observado difere do ALB/NLB mencionado: adequação a revisar.
A escala do analytics continua pendente; reorganizar o roteiro não a comprova.
'''

VALIDATION = '''VALIDAÇÃO DO PDF ORIGINAL — 30/10/2026
Arquivo analisado: ToggleMaster_Fase2_Roteiro_Final_Gravacao.pdf (12 páginas).
Original preservado. Para gravar, usar o arquivo com sufixo _VALIDADO.
Fontes: PDF original, enunciado (página 9), Dockerfiles, docker-compose.yml,
k8s-aws, código do evaluation/analytics e 13 evidências datadas de 30/10/2026.
Esta revisão é documental; não executou nova carga nem consultou a AWS ao vivo.

CORREÇÕES
Página 4, deixa 8/anexo: portas do host são 18001–18005 por padrão;
8001–8005 são as portas internas. Consultar docker compose port se .env as alterar.
Página 6, deixa 16: evaluation-analytics-queue -> tgmqueue.
Página 6, deixa 17: os Security Groups RDS incluem IP administrativo /32;
não afirmar acesso exclusivamente do EKS. RDS tem PubliclyAccessible=False.
Página 7, deixa 20: namespaces terminam em -service; DNS correto:
flag-service.flag-service.svc.cluster.local.
Página 8, deixa 25: evidência usa API elb (Classic), não ALB/NLB.
O enunciado menciona ALB/NLB; registrar a divergência sem ocultá-la.
Página 9, deixa 29: result:true não garante SQS publicado/persistido;
o envio usa goroutine e pode falhar depois da resposta. Correlacionar evento.
Página 9, deixa 33: analytics não escalou no teste registrado. Tem HPA configurado.
Páginas 11–12: Bash/grep/jq substituídos por instruções PowerShell para este PC.
Carga: usar namespace evaluation-service e dois geradores; quatro pressionaram
o ambiente em ensaio anterior. Não aumentar a carga durante a gravação sem ensaio.
Anexo C1: não executar alteração IMDS como comando de rotina em vídeo.
Verificar nós atuais e preparar o ambiente fora da gravação.
O hop limit 2 autoriza acesso dos pods às credenciais do nó; não é isolamento IAM.
Imagem ECR do flag-service: namespace/lag-service:v1 (nome real, não erro do roteiro).

LIMITES DAS EVIDÊNCIAS
Arquivos 01–12: coleta anterior à recriação dos nós, aproximadamente 22:04–22:05.
Arquivo 13: ensaio posterior, 22:32–22:34. Não apresentar como snapshot simultâneo.
13 mostra 1 -> 2/2 Running -> 3 réplicas na linha do tempo -> 1.
O campo maxEvaluation=2 é incompleto: o coletor parou de atualizar esse máximo
depois da primeira fase. Preservamos a saída bruta; a narrativa usa a sequência.
Analytics permaneceu em uma réplica. A configuração do HPA não prova scale-out.
07 mostra quatro itens da flag load-postman-fiap, mas não exibe um evento
correlacionado do teste atual. DescribeTable.ItemCount não substitui um scan/query.
As imagens foram renderizadas de AWS CLI/kubectl, não do Console autenticado.

PENDÊNCIAS PARA FECHAR O VÍDEO (enunciado, página 9)
1. Gravar docker compose up e os nove containers locais saudáveis.
   LocalStack substitui o DynamoDB Local literal do enunciado: adaptação declarada.
2. Executar e registrar fluxo HTTP com o mesmo identificador no DynamoDB.
3. Enviar mensagens sintéticas manualmente para tgmqueue e demonstrar
   analytics-service escalando por CPU. A evidência atual NÃO atende este item.
   O script 03 suporta o ensaio, mas não garante que 100 mensagens elevarão a CPU.
4. Verificar Jobs SQL e estado atual do cluster antes de afirmar sucesso ao vivo.
5. Revisar com o grupo a divergência Classic LB versus ALB/NLB do enunciado.
6. Ensaiar o tempo: alvo 19 minutos, máximo 20; cortar esperas e trechos opcionais.

FALAS CONDICIONAIS
Após comprovar escala do analytics, substituir a deixa 34 pela descrição do
resultado real: CPU observada, réplicas disponíveis e marcador dos eventos.
Não inventar números nem mostrar kubectl scale manual como decisão do HPA.
Antes disso, o roteiro está revisado tecnicamente, mas a demonstração continua
com essa pendência. Corrigir texto não substitui produzir a evidência faltante.
'''

COMMANDS = r'''COMANDOS DOS APRESENTADORES A E B — POWERSHELL / WINDOWS
Sequência: itens 1 a 5 do enunciado; ver 07_ORDEM_DO_ENUNCIADO.txt.
A executa os blocos 00–03; B prepara sua sessão com 00 e executa 04–08.
Executar um bloco por vez. Caminhos abaixo partem da raiz do projeto.
A pasta apresentacao é um kit de gravação; o código completo continua na raiz.
Fazer a preparação fora da gravação. Não abrir .env nem arquivos de credenciais.

00 — ABRIR O PROJETO E PREPARAR AWS
Set-Location 'C:\Users\Jeferson\Desktop\Fase 2 Tech FIAP'
. .\apresentacao\scripts\01-preparar-sessao.ps1

O ponto + espaço importa a sessão no terminal atual. Repetir em cada terminal.
O script lê docs\LAB 2.txt sem imprimir valores, valida conta e usa kubeconfig
isolado em TEMP. Pré-requisitos: AWS CLI, kubectl, Docker Desktop (parte local).
As credenciais atualizadas precisam permanecer fora da pasta de apresentação.

01 — ITEM 1 / DEIXA 5: SUBIR OS NOVE CONTAINERS LOCAIS
docker compose up -d --build --wait --wait-timeout 240
docker compose ps

Não usar docker-compose.aws.yml aqui: esse é outro cenário, local apontando AWS.
Se houver containers desse outro cenário nas mesmas portas, resolver o conflito
antes do vídeo. Não apagar volumes para gravar. Cortar a espera do build na edição.

02 — ITEM 1 / DEIXAS 4 E 6: IMAGENS E HEALTH CHECKS
Usar docker images na deixa 4; subir o Compose no bloco 01 para a deixa 5;
executar os health checks abaixo na deixa 6.
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | Select-String 'togglemaster/'
foreach ($service in @('auth-service','flag-service','targeting-service','evaluation-service','analytics-service')) {
    $ports = @{ 'auth-service'=8001; 'flag-service'=8002; 'targeting-service'=8003; 'evaluation-service'=8004; 'analytics-service'=8005 }
    $published = @(docker compose port $service $ports[$service])[0]
    if ($LASTEXITCODE -ne 0 -or -not $published) { throw "Porta ausente: $service" }
    $port = ($published -split ':')[-1]
    $health = Invoke-RestMethod "http://localhost:$port/health" -TimeoutSec 10
    [pscustomobject]@{ Service=$service; HostPort=$port; Status=$health.status }
}

ITEM 2 / DEIXAS 7–15 — ABRIR EVIDÊNCIAS E REFERÊNCIAS
Mostrar 02 EKS -> 03 ECR -> 04 RDS -> 05 Redis -> 07 DynamoDB -> 06 SQS ->
08 Security Groups -> 06_URLS_E_NOMES_DO_LAB.txt.
Abrir 04_SLIDES.html no navegador e apertar F11. Setas direita/esquerda navegam.
Abrir evidencias\13_hpa_antes_durante_depois.html; ajustar zoom/rolar para cada etapa.
O PDF 04_SLIDES.pdf permite apresentar offline sem navegador.

03 — ITEM 3 / DEIXAS 16–17: METRICS SERVER E NGINX
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods -A
helm list -n ingress-nginx
kubectl get deployment,pods,services -n ingress-nginx

Helm precisa estar instalado no computador para listar as releases.
Se as métricas estiverem indisponíveis, resolver antes da demonstração de HPA.
Este bloco inspeciona o que está instalado; não reinstala os componentes.

04 — ITEM 4 / DEIXAS 19–26: MANIFESTOS E ESTADO AWS
kubectl config current-context
kubectl get nodes
kubectl get namespaces
kubectl get deployments -A -l app.kubernetes.io/part-of=togglemaster
foreach ($ns in @('auth-service','flag-service','targeting-service','evaluation-service','analytics-service')) { kubectl get svc -n $ns }
kubectl get externalsecret -A
kubectl get clustersecretstore
kubectl get configmap evaluation-config -n evaluation-service
kubectl get ingress -A
kubectl get service my-release-ingress-nginx-controller -n ingress-nginx
kubectl get jobs -A
kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster

Na apresentação, seguir: Namespace (19), Deployment (20), Service (21),
Secret/ExternalSecret (22), ConfigMap (23), Ingress (24), boas práticas (25),
Jobs e pods (26). Mostrar exemplos em apoio_codigo, sem aplicar esses recortes.
Não mostrar valores de Secrets ou executar kubectl get secret -o yaml.

Esperado: dois nós Ready, cinco Deployments disponíveis, ExternalSecrets Ready.
Se algum Service não aparecer por ausência de label:
foreach ($ns in @('auth-service','flag-service','targeting-service','evaluation-service','analytics-service')) { kubectl get svc -n $ns }

05 — ITEM 4 / DEIXA 27: FLUXO FUNCIONAL PELO INGRESS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-aws-deployment.ps1

Esse script já existe no projeto: cria API key, flag e regra com nome único,
consulta /evaluate e procura o mesmo flag_name no DynamoDB. Mostrar o resumo
EvaluationResult=True e DynamoDBItems maior que zero. Os cadastros ficam no LAB;
o script não os apaga. Não mostrar a chave retornada pela API.
Alternativa Postman: importar os dois JSONs da pasta postman do kit.
Preparar api_key secreta fora da gravação; usar flag_name exclusivo.
Executar validar chave -> criar flag -> criar regra -> avaliar flag, nessa ordem.
401: autenticação inválida; 409: nome já existente; escolher outro nome.

06 — ITEM 5 / DEIXAS 28–32: HPAs E CARGA EVALUATION
Deixa 28: evaluation-hpa.yaml. Deixa 29: analytics-hpa.yaml.
Deixa 30: justificar HPA por CPU no Academy e explicar KEDA como alternativa.
Deixas 31–32: demonstração evaluation antes, durante e depois.
kubectl top nodes
kubectl top pods -A
kubectl get hpa -A

Para narrar o ensaio já feito, abrir evidência 13. Para um novo ensaio ao vivo:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\export-hpa-evidence.ps1 -FlagName load-postman-fiap -LoadPods 2 -LoadSeconds 240

Requer load-postman-fiap habilitada e regra de 100%. O script cria e remove seus
pods de carga e espera scale-in. Pode substituir a captura na pasta docs; os
arquivos copiados para apresentacao são uma fotografia independente da coleta.
Se a flag não existir, preparar no Postman e passar esse nome em -FlagName.

Em OUTROS terminais preparados com o bloco 00:
kubectl get hpa -n evaluation-service -w
kubectl get pods -n evaluation-service -l app=evaluation-service -w

Ctrl+C encerra apenas o watch. O gerador possui tempo limitado e limpeza própria.

07 — DEIXAS 33–35: SQS -> ANALYTICS -> DYNAMODB
Deixa 33: envio manual. Deixa 34: scale-out analytics (PENDENTE).
Deixa 35: correlacionar eventos persistidos no DynamoDB.
Antes: registrar horário, HPA e pods. Abrir dois terminais com:
kubectl get hpa -n analytics-service -w
kubectl get pods -n analytics-service -l app=analytics-service -w

No terminal principal preparado, enviar 100 eventos sintéticos controlados:
.\apresentacao\scripts\03-enviar-eventos-sqs.ps1 -Count 100

O script imprime um RunId, que também é o flag_name dos eventos sintéticos.
As mensagens são reais e o worker as grava no DynamoDB. Não é tráfego HTTP.
O volume inicial não garante escala; a CPU precisa ultrapassar 30% do request.
Se permanecer em 1 réplica, a prova de escala continua pendente. Interromper o
ensaio e analisar métricas antes de aumentar carga. Não alterar réplicas manualmente.

No Console DynamoDB: Explore items -> ToggleMasterAnalytics -> filtrar flag_name
igual ao RunId impresso. Mostrar user_id, flag_name, result, timestamp, event_id.
Alternativa CLI (substituir SOMENTE o marcador pelo RunId real):
$runId = 'SUBSTITUIR_PELO_RUNID'
$scan = aws dynamodb scan --table-name ToggleMasterAnalytics --region us-east-1 --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Falha no scan' }
$scan.Items | Where-Object { $_.flag_name.S -eq $runId } | ForEach-Object { [pscustomobject]@{ event_id=$_.event_id.S; flag_name=$_.flag_name.S; user_id=$_.user_id.S; result=$_.result.BOOL; timestamp=$_.timestamp.S } }

O scan acima lê a tabela inteira: usar somente no laboratório pequeno.
Não gravar a fala de analytics escalando sem múltiplas réplicas Ready observadas.

08 — ENCERRAMENTO
kubectl get hpa -A
kubectl get deployments -A -l app.kubernetes.io/part-of=togglemaster
Confirmar que a carga terminou e registrar retorno ao mínimo.
Não encerrar o Lab antes de salvar a gravação e todas as evidências necessárias.
'''

def write(name, text):
    if ROTEIRO_ONLY and not name.startswith(STEM):
        return
    p=OUT/name
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(text,encoding='utf-8')

def esc(s):
    return html.escape(s)

STYLE='''@page{size:A4;margin:16mm}*{box-sizing:border-box}body{font:11pt Arial,sans-serif;color:#17243a;margin:0}h1{font-size:25pt;color:#14345b}h2{font-size:16pt;color:#14345b}h3{font-size:12pt}p{line-height:1.42}section{break-after:page}section:last-child{break-after:auto}.tag{color:#b05b00;font-weight:bold}table{border-collapse:collapse;width:100%;font-size:10pt}td,th{border:1px solid #bbc7d4;padding:9px;vertical-align:top}th{background:#183957;color:white;text-align:left}tr{break-inside:avoid}.screen{background:#f0f4f8;width:32%}.note{background:#fff4dd;padding:13px;border-left:4px solid #d99425}footer{margin-top:16px;font-size:9pt;color:#536277}a{color:#1a5794}'''

write('00_LEIA_PRIMEIRO.txt','''KIT PARA GRAVAÇÃO — TOGGLEMASTER / FASE 2

1. Ler 01_VALIDACAO_E_PENDENCIAS.txt antes de gravar.
2. Usar ToggleMaster_Fase2_Roteiro_Final_Gravacao_VALIDADO.pdf (ou .docx).
   O PDF original foi preservado com o nome anterior; não usar o anexo antigo.
3. Apresentadores A e B: 02_COMANDOS_EM_ORDEM.txt (PowerShell, um bloco por vez).
4. Apresentar 04_SLIDES.html (F11 e setas) ou 04_SLIDES.pdf.
5. Consultar 05_MAPA_DE_TELAS.txt para localizar cada evidência.
6. evidencias contém 13 PNGs e respectivos HTML/TXT, todos datados.
7. postman contém coleção de demonstração e ambiente sem credenciais.
8. apoio_codigo reúne exemplos para mostrar Dockerfiles e Kustomize/probes.
9. 07_ORDEM_DO_ENUNCIADO.txt relaciona páginas do POSTECH e deixas do roteiro.

IMPORTANTE: falta comprovar o scale-out do analytics por carga no SQS,
exigido na página 9 do enunciado. O HPA do evaluation já tem evidência.
Os comandos de ensaio do analytics estão preparados, mas não foram executados
nesta revisão documental. Não tratar a apresentação como integralmente concluída.

Arquivos 01–12 mostram o LAB antes da recriação dos nós; 13 mostra o ensaio
posterior. São registros históricos de CLI/kubectl, não capturas atuais do Console.
O PDF original, de terceiros/usuário, foi mantido sem alterações.

Este kit depende da raiz do projeto para execução; não é um pacote de instalação.
Não foram copiados .env, LAB 2.txt, kubeconfig ou valores de segredos.
Nomes dos participantes vieram do roteiro existente; revisar grafia com o grupo.
Tempo alvo: 19 min, limite: 20 min. Cortar esperas, não etapas de comprovação.
''')
write('01_VALIDACAO_E_PENDENCIAS.txt',VALIDATION)
write('02_COMANDOS_EM_ORDEM.txt',COMMANDS)
write('07_ORDEM_DO_ENUNCIADO.txt',ORDER_MAP)
write(STEM+'.txt','ROTEIRO VALIDADO — DOIS APRESENTADORES A E B — alvo 19 minutos\n\n'+PRESENTERS+'\n\n'+SCREEN_DUTIES+'\n\n'+'\n\n'.join(f'{n:02d} | {t} | Apresentador {"A" if n<19 else "B"}\nAÇÃO DE {"A" if n<19 else "B"} / TELA: {screen}\nFALA DE {"A" if n<19 else "B"}: {speech}' for n,t,screen,speech in CUES))

front='''<section><p class="tag">TOGGLEMASTER • TECH CHALLENGE FASE 2</p><h1>Roteiro revisado para gravação</h1><p>Revisão documental: 30/10/2026 • alvo 19 minutos • limite 20 minutos.</p><p>Apresentador A: deixas 1–18. Apresentador B: deixas 19–37. O operador prepara a tela antes de cada fala.</p><div class="note"><b>Pendência de entrega:</b> o enunciado exige envio manual de mensagens ao SQS e escala do analytics. A captura atual demonstra escala do evaluation; analytics permaneceu em uma réplica. Ensaiar a deixa 34 e atualizar a fala com o resultado real antes da versão final do vídeo.</div><h2>Materiais</h2><p>02_COMANDOS_EM_ORDEM.txt: comandos PowerShell.<br>04_SLIDES.html/PDF: telas de apresentação.<br>05_MAPA_DE_TELAS.txt: evidências por deixa.<br>01_VALIDACAO_E_PENDENCIAS.txt: correções e limites.</p><h2>Antes de gravar</h2><p>Preparar credenciais fora da gravação, confirmar o contexto EKS, nós Ready, cinco Deployments disponíveis e métricas dos dois HPAs. Mostrar docker compose up e os nove containers locais. Conferir Jobs e sincronização dos segredos. Testar HTTP e correlacionar evento no DynamoDB.</p><p>Usar resultados observados para as falas de sucesso. Exibir as capturas como registros datados. Não mostrar chaves nas respostas, headers ou console do Postman.</p><footer>Original preservado: ToggleMaster_Fase2_Roteiro_Final_Gravacao.pdf</footer></section>'''
front=front.replace('Roteiro revisado para gravação</h1>', 'Roteiro para dois apresentadores</h1>')
front=front.replace('Apresentador A: deixas 1–18. Apresentador B: deixas 19–37. O operador prepara a tela antes de cada fala.',esc(PRESENTERS)+'</p><p>'+esc(SCREEN_DUTIES))
pages=[front]
order_rows=''.join(f'<tr><td>{esc(title)}</td><td>{start:02d}–{end:02d}</td></tr>' for start,end,title in SECTIONS)
pages.append('<section><h2>Sequência do enunciado</h2><p>Referência: POSTECH - Tech Challenge - Fase 2.pdf, páginas 4–9. A abertura é breve; os requisitos seguem a ordem abaixo.</p><table><tr><th>Item / página / apresentador</th><th>Deixas</th></tr>'+order_rows+'</table><p>O bloco final retoma a arquitetura e os desafios solicitados na página 9. Os entregáveis do relatório e o limite de 20 minutos estão no checklist 07_ORDEM_DO_ENUNCIADO.txt.</p></section>')
for start,end,title in SECTIONS:
    presenter = 'A' if start < 19 else 'B'
    rows=''.join(f'<tr><td class="screen"><b>{n:02d} • {t} • {presenter}</b><p>{esc(screen)}</p></td><td>{esc(speech)}</td></tr>' for n,t,screen,speech in CUES if start<=n<=end)
    pages.append(f'<section><h2>{title}</h2><table><thead><tr><th>{presenter} — tela e comandos</th><th>{presenter} — fala</th></tr></thead><tbody>{rows}</tbody></table><footer>O apresentador desta parte também controla a tela. Tempos são metas de edição. Deixa 34 depende de novo ensaio.</footer></section>')
write(STEM+'.html','<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Roteiro validado</title><style>'+STYLE+'</style>'+''.join(pages)+'</html>')

doc=Document()
sec=doc.sections[0]
sec.top_margin=sec.bottom_margin=Inches(.65)
sec.left_margin=sec.right_margin=Inches(.65)
doc.styles['Normal'].font.name='Calibri'
doc.styles['Normal'].font.size=Pt(10)
doc.add_heading('ToggleMaster — roteiro para dois apresentadores',0)
doc.add_paragraph('Revisão documental: 30/10/2026 | alvo: 19 min | limite: 20 min')
doc.add_paragraph(PRESENTERS)
doc.add_paragraph(SCREEN_DUTIES)
doc.add_heading('Pendência antes de fechar o vídeo',1)
doc.add_paragraph('Falta demonstrar envio manual de mensagens SQS e scale-out do analytics, exigidos na página 9 do enunciado. As evidências comprovam a escala do evaluation. A deixa 34 deve ser ensaiada e substituída pela descrição do resultado real.')
doc.add_paragraph('Usar 02_COMANDOS_EM_ORDEM.txt e 05_MAPA_DE_TELAS.txt. Capturas 01–12 e 13 são de momentos diferentes. Não exibir credenciais. O PDF original foi preservado.')
doc.add_page_break()
doc.add_heading('Sequência do enunciado',1)
doc.add_paragraph('Referência: POSTECH - Tech Challenge - Fase 2.pdf, páginas 4–9. Checklist de entregáveis: 07_ORDEM_DO_ENUNCIADO.txt.')
for start,end,title in SECTIONS:
    doc.add_paragraph(f'{title} — deixas {start:02d}–{end:02d}.')
for n,t,screen,speech in CUES:
    if n in [s[0] for s in SECTIONS]:
        doc.add_page_break()
        doc.add_heading(next(s[2] for s in SECTIONS if s[0]==n),1)
    doc.add_heading(f'{n:02d} • {t} • Apresentador {"A" if n<19 else "B"}',2)
    p=doc.add_paragraph(f'AÇÃO DE {"A" if n<19 else "B"} / TELA: '+screen)
    p.runs[0].italic=True
    doc.add_paragraph(f'FALA DE {"A" if n<19 else "B"}: '+speech)
doc.sections[0].footer.paragraphs[0].text='ToggleMaster | roteiro validado | consultar pendências antes de gravar'
doc.save(OUT/(STEM+'.docx'))
if ROTEIRO_ONLY:
    print('Roteiro atualizado: A apresenta e opera a parte 1; B apresenta e opera a parte 2.')
    sys.exit(0)

# Native SVG architecture: current resource names and Classic LB, no obsolete image.
SVG='''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 580" role="img" aria-label="Arquitetura ToggleMaster"><defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="#ffbb57"/></marker></defs><style>text{font-family:Arial;fill:#eef5ff;font-size:18px}rect{fill:#203b58;stroke:#5281a5;stroke-width:2}.edge{stroke:#ffbb57;stroke-width:3;fill:none;marker-end:url(#a)}</style><rect x="18" y="24" width="200" height="76" rx="12"/><text x="40" y="55">Cliente / Postman</text><text x="40" y="80">HTTP</text><path class="edge" d="M218 62H295"/><rect x="300" y="24" width="260" height="76" rx="12"/><text x="322" y="55">Classic Load Balancer</text><text x="322" y="80">+ ingress-nginx</text><path class="edge" d="M560 62H630V150"/><text x="650" y="65">EKS: ekstogglemaster</text><text x="650" y="94">tgmnodegroup • 2 nós desejados</text><rect x="20" y="155" width="260" height="92" rx="12"/><text x="40" y="184">auth-service (Go)</text><text x="40" y="216">API keys • RDS db-authservice</text><rect x="320" y="155" width="250" height="92" rx="12"/><text x="340" y="184">flag-service (Python)</text><text x="340" y="216">Flags • RDS dbflags</text><rect x="610" y="155" width="270" height="92" rx="12"/><text x="630" y="184">targeting-service (Python)</text><text x="630" y="216">Regras • RDS dbtargeting</text><rect x="320" y="307" width="300" height="85" rx="12"/><text x="340" y="340">evaluation-service (Go)</text><text x="340" y="369">Decisão • HPA por CPU</text><path class="edge" d="M440 307V250"/><path class="edge" d="M580 307L690 252"/><path class="edge" d="M320 338L150 252"/><text x="25" y="297">Validação de chaves</text><rect x="785" y="307" width="390" height="85" rx="12"/><text x="805" y="340">ElastiCache: redisevaluation</text><text x="805" y="369">TLS + token • cache 30 s</text><path class="edge" d="M620 350H778"/><rect x="60" y="465" width="240" height="85" rx="12"/><text x="80" y="500">SQS: tgmqueue</text><text x="80" y="528">Standard</text><path class="edge" d="M420 392L225 459"/><text x="257" y="430">Publicação assíncrona</text><rect x="415" y="465" width="310" height="85" rx="12"/><text x="435" y="500">analytics-service (Python)</text><text x="435" y="528">Worker • HPA por CPU</text><path class="edge" d="M300 507H409"/><rect x="850" y="465" width="325" height="85" rx="12"/><text x="870" y="500">DynamoDB</text><text x="870" y="528">ToggleMasterAnalytics</text><path class="edge" d="M725 507H844"/></svg>'''
SVG = SVG.replace('<path class="edge" d="M560 62H630V150"/>', '<path class="edge" d="M430 100V126H150V150"/><path class="edge" d="M430 126H445V150"/><path class="edge" d="M445 126H745V150"/><path class="edge" d="M560 62H1190V280H470V300"/>')
SVG = SVG.replace('<path class="edge" d="M320 338L150 252"/><text x="25" y="297">Validação de chaves</text>', '<text x="25" y="297">Auth valida chaves</text><text x="25" y="323">usadas em flag e targeting</text>')
SVG = SVG.replace('x="650" y="65"','x="650" y="22"').replace('x="650" y="94"','x="650" y="48"')
SVG = SVG.replace('<text x="40" y="216">','<text x="40" y="216" style="font-size:16px">')
SVG = SVG.replace('<text x="257" y="430">Publicação assíncrona</text>','<text x="25" y="420">Evento assíncrono</text>')
write('arquitetura_validada.svg',SVG)
slides=[
('ToggleMaster','De monolito a microsserviços no Amazon EKS','<p>Tech Challenge • Fase 2</p><p class="names">Afonso Victoriano Franco · Cesar Augusto Ferreira Alves<br>Jeferson Lima Papalino · Jonatas Ariel Nunes · Willian Felix Corrêa</p>'),
('Arquitetura','Cinco serviços • dados separados • processamento assíncrono',SVG),
('Cada armazenamento tem um papel','RDS • ElastiCache • DynamoDB','<div class="cards"><article><h2>RDS PostgreSQL</h2><p>Auth, flags e regras</p><p>db-authservice<br>dbflags<br>dbtargeting</p></article><article><h2>Redis</h2><p>Cache temporário de flag + regra</p><p>redisevaluation<br>TTL 30 s · TLS · token</p></article><article><h2>DynamoDB</h2><p>Eventos analíticos</p><p>ToggleMasterAnalytics<br>Chave: event_id</p></article></div>'),
('Da máquina local à AWS','Configuração e evidência devem se referir ao mesmo cenário','<div class="cards"><article><h2>Compose local</h2><p>9 containers</p><p>5 aplicações + 2 PostgreSQL<br>Redis + LocalStack</p><p>Host: 18001–18005 por padrão</p></article><article><h2>AWS Academy</h2><p>ekstogglemaster / us-east-1</p><p>ECR + 3 RDS + Redis<br>SQS + DynamoDB</p><p>tgmnodegroup: 1 / 2 / 4 nós</p></article></div><p class="small">LocalStack é uma adaptação ao DynamoDB Local citado no enunciado. O balanceador observado é Classic; revisar a adequação a ALB/NLB.</p>'),
('Escala demonstrada: evaluation','Registro de 30/10/2026 • 22:32–22:34','<p class="metric">1 → 2/2 Running → 1</p><p>CPU observada: 42% • alvo: 30% do request</p><p>A linha do tempo também registra 3 réplicas após encerrar a carga.</p><p>Analytics: HPA configurado, permaneceu em 1 réplica neste ensaio.</p><p class="small">Abrir evidência 13 para a saída bruta. Ensaio de escala do analytics por mensagens SQS ainda pendente.</p>'),
('Desafios e lições','O que o laboratório nos ensinou','<ul><li>Validar dependências e DNS antes de gerar carga.</li><li>Separar a resposta HTTP da confirmação do evento no DynamoDB.</li><li>Guardar segredos fora das telas e dos manifestos.</li><li>Nós recriados voltaram a hop limit 1; restaurar 2 recuperou analytics.</li><li>LabRole via IMDS é uma solução acadêmica com acesso amplo.</li></ul>'),
('Próximos passos','Concluir a prova exigida e evoluir a solução','<ul><li>Demonstrar escala do analytics com mensagens SQS e métricas.</li><li>Revisar Classic LB versus ALB/NLB exigido no enunciado.</li><li>Identidade por serviço, HTTPS e observabilidade.</li><li>Idempotência, DLQ e estratégia de retry.</li><li>Pipeline CI/CD e autoscaling dos nós.</li></ul>'),
('Obrigado!','ToggleMaster • Tech Challenge Fase 2','<p>Código, roteiro e evidências acompanham o projeto.</p><p class="names">Afonso · Cesar · Jeferson · Jonatas · Willian</p>')]
slidecss='''@page{size:338.67mm 190.5mm;margin:0}*{box-sizing:border-box}body{margin:0;background:#0d1c2f;color:#edf4ff;font-family:Arial,sans-serif}.slide{padding:42px 58px;width:1280px;height:720px;break-after:page;position:relative;overflow:hidden}.slide:last-child{break-after:auto}h1{font-size:46px;margin:10px 0 14px;color:#ffbb57}.sub{font-size:24px;color:#9fc4e6;margin-bottom:30px}p,li{font-size:25px;line-height:1.45}li{margin-bottom:16px}.names{font-size:23px;margin-top:75px}.small{font-size:19px;color:#b5c8da}.cards{display:flex;gap:20px}.cards article{flex:1;background:#203b58;padding:20px;border-radius:12px}.cards h2{font-size:26px}.cards p{font-size:22px}.metric{font-size:66px;color:#ffbb57}svg{width:100%;max-height:490px}footer{position:absolute;bottom:22px;left:58px;font-size:15px;color:#9fc4e6}@media screen{.slide{display:none;width:100vw;height:100vh;min-height:690px}.slide.active{display:block}}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}'''
slidehtml=''.join(f'<section class="slide {"active" if i==0 else ""}"><h1>{esc(title)}</h1><div class="sub">{esc(sub)}</div>{body}<footer>ToggleMaster • Fase 2 &nbsp; | &nbsp; {i+1}/{len(slides)}</footer></section>' for i,(title,sub,body) in enumerate(slides))
write('04_SLIDES.html','<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>ToggleMaster • apresentação</title><style>'+slidecss+'</style>'+slidehtml+'''<script>let i=0;const slides=[...document.querySelectorAll('.slide')];addEventListener('keydown',e=>{if(['ArrowRight','PageDown',' '].includes(e.key))i=Math.min(slides.length-1,i+1);else if(['ArrowLeft','PageUp'].includes(e.key))i=Math.max(0,i-1);else if(e.key==='Home')i=0;else return;e.preventDefault();slides.forEach((s,n)=>s.classList.toggle('active',n===i));});</script></html>''')

mapping='MAPA DE TELAS — SEQUÊNCIA DO ENUNCIADO\nAs numerações de slides e evidências são identificadores; abrir na ordem das deixas abaixo.\n\n'
mapping+='\n\n'.join(f'{n:02d} | {t} | {"A" if n<19 else "B"}: {screen}' for n,t,screen,_ in CUES)
mapping+='\n\n01_identidade é apoio de conta/região. Evidências 01–12 são anteriores à recriação dos nós; 13 é posterior. Não apresentar como um snapshot simultâneo.\n'
write('05_MAPA_DE_TELAS.txt',mapping)
write('06_URLS_E_NOMES_DO_LAB.txt',f'''REFERÊNCIAS PARA A GRAVAÇÃO — us-east-1 / conta 533267349027
Console AWS (sessão autenticada necessária):
https://us-east-1.console.aws.amazon.com/console/home?region=us-east-1
Pesquisar cada serviço na barra superior do Console e selecionar o nome abaixo.

EKS: ekstogglemaster
Managed Node Group: tgmnodegroup
VPC: vpc-09d66ad83422a42ee
ECR: namespace/auth-service:v1; namespace/lag-service:v1;
namespace/targeting-service:v1; namespace/evaluation-service:v3;
namespace/analytics-service:v1.
Prefixo ECR: 533267349027.dkr.ecr.us-east-1.amazonaws.com/
RDS: db-authservice, dbflags, dbtargeting
Redis: redisevaluation
SQS: tgmqueue
DynamoDB: ToggleMasterAnalytics
Secrets Manager (mostrar nomes, não valores): togglemaster/auth,
togglemaster/flag, togglemaster/targeting, togglemaster/evaluation.

Base HTTP observada em 30/10/2026:
{LB}
Validação: {LB}/auth/validate (Bearer API key)
Flags: {LB}/flags (Bearer API key)
Regras: {LB}/rules (Bearer API key)
Avaliação: {LB}/evaluate?user_id=video-user&flag_name=load-postman-fiap
Analytics: interno, sem rota pública.

Confirmar DNS atual pelo Service ingress-nginx no bloco 04 dos comandos.
Não publicar chaves no arquivo nem colar Bearer tokens nas URLs.
''')

evidence=OUT/'evidencias'
evidence.mkdir(exist_ok=True)
for p in (ROOT/'docs'/'evidencias_aws_2026-10-30').iterdir():
    if p.suffix.lower() in ('.png','.html','.txt'):
        shutil.copy2(p,evidence/p.name)
for src,dest in [('auth-service/Dockerfile','auth-service.Dockerfile'),('flag-service/Dockerfile','flag-service.Dockerfile'),('k8s-aws/flag/deployment.yaml','flag-deployment.yaml'),('k8s-aws/flag/kustomization.yaml','flag-kustomization.yaml'),('k8s-aws/evaluation/hpa.yaml','evaluation-hpa.yaml'),('k8s-aws/analytics/hpa.yaml','analytics-hpa.yaml'),('k8s-aws/evaluation/configmap.yaml','evaluation-configmap.yaml'),('k8s-aws/auth/ingress.yaml','auth-ingress.yaml')]:
    p=OUT/'apoio_codigo'/dest
    p.parent.mkdir(exist_ok=True)
    shutil.copy2(ROOT/src,p)
write('apoio_codigo/LEIA.txt','Excertos para apresentar, não um pacote de deploy. Namespaces dos arquivos-base são substituídos pelo Kustomize. Não executar kubectl apply nesta pasta. Aplicação completa depende de k8s-aws na raiz.\n')

# Presentation-only Postman collection, deliberately omitting key-creation response.
items=[]
def request(name,method,path,body=None,auth=False,tests=None):
    req={'method':method,'header':[],'url':'{{base_url}}'+path}
    if auth: req['header'].append({'key':'Authorization','value':'Bearer {{api_key}}'})
    if body:
        req['header'].append({'key':'Content-Type','value':'application/json'})
        req['body']={'mode':'raw','raw':json.dumps(body,ensure_ascii=False,indent=2),'options':{'raw':{'language':'json'}}}
    item={'name':name,'request':req}
    if tests: item['event']=[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]
    items.append(item)
request('01 - Validar API key','GET','/auth/validate',auth=True,tests=["pm.test('Chave válida',()=>pm.response.to.have.status(200));"])
request('02 - Criar flag','POST','/flags',{'name':'{{flag_name}}','description':'Demonstração do vídeo','is_enabled':True},True,["pm.test('Flag criada',()=>pm.response.to.have.status(201));"])
request('03 - Criar regra 100%','POST','/rules',{'flag_name':'{{flag_name}}','is_enabled':True,'rules':{'type':'PERCENTAGE','value':100}},True,["pm.test('Regra criada',()=>pm.response.to.have.status(201));"])
request('04 - Avaliar flag','GET','/evaluate?user_id={{user_id}}&flag_name={{flag_name}}',tests=["pm.test('HTTP 200',()=>pm.response.to.have.status(200));","pm.test('Decisão true',()=>pm.expect(pm.response.json().result).to.eql(true));"])
write('postman/ToggleMaster_Video.postman_collection.json',json.dumps({'info':{'name':'ToggleMaster - Demonstração do vídeo','schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'item':items},ensure_ascii=False,indent=2))
write('postman/ToggleMaster_Video.postman_environment.json',json.dumps({'name':'ToggleMaster - Vídeo AWS','values':[{'key':k,'value':v,'type':'secret' if k=='api_key' else 'default','enabled':True} for k,v in [('base_url',LB),('api_key',''),('flag_name','video-trocar-por-nome-unico'),('user_id','video-user')]],'_postman_variable_scope':'environment'},ensure_ascii=False,indent=2))
write('postman/LEIA.txt','Importar coleção e ambiente. Preparar uma API key válida fora da gravação; inserir em api_key, sem Bearer. Trocar flag_name por um nome exclusivo. Rodar 01 a 04. Não gravar Headers/console/valores de variáveis. A criação da chave não foi incluída pois a resposta contém a credencial. Usar o ambiente privado já existente para obter a chave. O script test-aws-deployment.ps1 é alternativa que cria a chave sem imprimi-la. A coleção grava flag/regra e não faz limpeza. O DNS do LB é histórico; confirmar o atual via kubectl.\n')
print(f'Kit gerado: {OUT}')
print(f'Deixas: {len(CUES)} | Slides: {len(slides)} | PNGs: {len(list(evidence.glob("*.png")))}')
