# 03 · Solicitações de acesso e permissões — Vale

> Pacote de solicitações para habilitar o ambiente **Core Data Integration** na Vale (`rg-integia-dev-brs`). Cada item foi exercitado no ambiente HAT (lab) com o mesmo IaC — o que pedimos é exatamente o que o código precisa. Versão formal para envio: `Solicitacoes_Acessos_Vale_CDI.docx`.

**Como usar:** (1) enviar o pacote na semana 1 junto com o plano do assessment (slide 34, passo 04 — *Vale disponibiliza documentos, código, ambientes e acessos*); (2) abrir um chamado por linha (ou por grupo de responsável) usando o ID `SOL-*` como referência; (3) acompanhar o status no cronograma (`cronograma/Cronograma_HAT_Vale_CDI.xlsx`, aba *Solicitações Vale*).

**Lead time** = estimativa em dias úteis a partir da abertura, com base em padrões de grandes empresas; ajustar com o calendário de mudanças da Vale (SOL-OPS-01).

## Resumo

| ID | Solicitação | Responsável Vale | Lead time (d.u.) | Prioridade | Bloqueia |
|---|---|---|---|---|---|
| SOL-GOV-01 | Assinatura e resource group dedicados | Cloud CoE / FinOps Vale | 10 | Crítica | Deploy Vale |
| SOL-GOV-02 | Modelo de acesso da equipe HAT ao RG | Cloud CoE / IAM Vale | 10 | Crítica | Deploy Vale |
| SOL-GOV-03 | Registro de resource providers | Cloud CoE Vale | 3 | Alta | Deploy Vale |
| SOL-GOV-04 | Revisão de Azure Policies e exceções | Cloud CoE / Segurança Vale | 15 | Alta | Deploy Vale |
| SOL-GOV-05 | Cota de modelos no Microsoft Foundry (Brazil South, Standard regional) | Cloud CoE Vale + conta Microsoft | 15 | Crítica | Agentes (Mês 2) |
| SOL-GOV-06 | Budget, tags e centro de custo | FinOps Vale | 5 | Média | — |
| SOL-NET-01 | Alocação da VNet spoke /22 e subnets | Rede / Cloud Vale | 10 | Crítica | Deploy Vale |
| SOL-NET-02 | Peering spoke ↔ hub corporativo | Rede Vale | 10 | Crítica | Deploy Vale |
| SOL-NET-03 | Rota de saída e regras no Firewall/NVA | Segurança de Rede Vale | 15 | Crítica | Ingestão (Mês 2) |
| SOL-NET-04 | DNS privado pelo hub | DNS / Rede Vale | 15 | Crítica | Deploy Vale |
| SOL-NET-05 | Permissões de rede para automação | Rede / IAM Vale | 10 | Alta | Deploy Vale |
| SOL-NET-06 | Entrada pública do Bot (Teams) via WAF | Segurança / Rede Vale | 20 | Alta | A1 no Teams (Mês 3) |
| SOL-NET-07 | Conectividade com SAP BTP IS e SAP LeanIX | Rede Vale + time BTP | 10 | Alta | Ingestão (Mês 2) |
| SOL-IAM-01 | App registration `integia-api-dev` | IAM Vale | 10 | Crítica | MCP (Mês 2) |
| SOL-IAM-02 | Grupos de segurança | IAM Vale | 10 | Alta | Deploy Vale |
| SOL-IAM-03 | Acesso ao SharePoint via Microsoft Graph (Sites.Selected) | IAM + M365 Vale | 15 | Crítica | Ingestão docs (Mês 2) |
| SOL-IAM-04 | Contas para a equipe HAT | IAM Vale | 10 | Crítica | Mês 1 |
| SOL-IAM-05 | Conditional Access para a API dos agentes | IAM Vale | 5 | Média | — |
| SOL-IAM-06 | Publicação do app do Bot no Microsoft Teams | Admin Teams / M365 Vale | 10 | Alta | A1 no Teams (Mês 3) |
| SOL-DAT-01 | Inventário do SharePoint (ICC010 / ICC015 / HLD) | Integração Vale (CCI) | 5 | Crítica | Ingestão docs |
| SOL-DAT-02 | Azure DevOps: repositórios, Boards e service hook | Integração Vale + admin DevOps | 10 | Crítica | Ingestão código |
| SOL-DAT-03 | SAP BTP Integration Suite — API de leitura | Time BTP Vale | 10 | Crítica | Ingestão código / A3 |
| SOL-DAT-04 | SAP LeanIX — usuário técnico e MCP | Arquitetura corporativa Vale | 10 | Alta | A1/A4 |
| SOL-DAT-05 | Ferramenta de chamados — API somente leitura | ITSM Vale | 10 | Média | A3 |
| SOL-DAT-06 | Classificação da informação e autorização de uso em IA | Segurança da Informação / DPO Vale | 15 | Crítica | Ingestão (Mês 2) |
| SOL-DEV-01 | Projeto e repositórios no Azure DevOps da Vale | Admin DevOps Vale | 5 | Alta | Mês 2 |
| SOL-DEV-02 | Service connection com Workload Identity Federation | Cloud CoE + DevOps Vale | 10 | Crítica | Deploy Vale |
| SOL-DEV-03 | Managed DevOps Pool | Admin DevOps Vale | 10 | Alta | A2/A3 |
| SOL-SEG-01 | Revisão de arquitetura (ARB / Segurança) | Arquitetura + Segurança Vale | 15 | Crítica | Deploy Vale |
| SOL-SEG-02 | Avaliação de risco de IA | Governança de IA Vale | 20 | Alta | Piloto (Mês 3) |
| SOL-SEG-03 | Defender for Cloud e integração com SIEM | SOC Vale | 10 | Média | — |
| SOL-SEG-04 | Pentest/scan do endpoint público | Segurança Vale | 15 | Média | Piloto (Mês 3) |
| SOL-OPS-01 | Calendário de mudanças e CAB | Gestão de Mudanças Vale | 3 | Alta | Mês 1 |
| SOL-OPS-02 | Acesso de observabilidade | Cloud CoE Vale | 5 | Média | Mês 4 |

## Governança

### SOL-GOV-01 — Assinatura e resource group dedicados

- **O que solicitamos:** Resource group `rg-integia-dev-brs` em Brazil South, numa assinatura de não-produção da Vale vinculada ao centro de custo do projeto (e reservar nomes para `qa`/`prd`).
- **Por quê (referência na arquitetura):** Isolamento do workload (slide 26: rg-integia-dev-brs). Permite RBAC, budget e policies próprios.
- **Responsável Vale:** Cloud CoE / FinOps Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** RG criado; ID da assinatura e centro de custo informados

### SOL-GOV-02 — Modelo de acesso da equipe HAT ao RG

- **O que solicitamos:** Opção recomendada: deploy exclusivamente por pipeline (service connection da Vale) e HAT com **Reader** no RG + **Contributor** elegível via PIM (janela de 8h) para troubleshooting. Alternativa: Contributor + *Role Based Access Control Administrator* com condição restrita às roles da matriz (docs/04).
- **Por quê (referência na arquitetura):** Implantar e operar os recursos com menor privilégio; atribuições RBAC das managed identities exigem permissão de escrita em roleAssignments.
- **Responsável Vale:** Cloud CoE / IAM Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Contas HAT com roles efetivas (az role assignment list)

### SOL-GOV-03 — Registro de resource providers

- **O que solicitamos:** Registrar na assinatura: Microsoft.App, Microsoft.ApiManagement, Microsoft.CognitiveServices, Microsoft.Search, Microsoft.DBforPostgreSQL, Microsoft.DocumentDB, Microsoft.ServiceBus, Microsoft.ContainerRegistry, Microsoft.KeyVault, Microsoft.Storage, Microsoft.Network, Microsoft.ManagedIdentity, Microsoft.OperationalInsights, Microsoft.Insights, Microsoft.BotService, Microsoft.DurableTask, Microsoft.DevCenter, Microsoft.DevOpsInfrastructure.
- **Por quê (referência na arquitetura):** Sem o registro, o deploy falha. Lista extraída do IaC (00-preflight.sh).
- **Responsável Vale:** Cloud CoE Vale · **Lead time:** 3 d.u. · **Prioridade:** Alta · **Bloqueia:** Deploy Vale
- **Critério de pronto:** `00-preflight.sh` sem pendências

### SOL-GOV-04 — Revisão de Azure Policies e exceções

- **O que solicitamos:** Rodar com a HAT o what-if contra as policies atribuídas e, se necessário, conceder exemption para: IP público do WAF (entrada do Bot), Container Apps Environment, Managed DevOps Pool, Durable Task Scheduler (se em preview), SKUs (APIM Developer, Service Bus Premium, ACR Premium, AI Search S1). Informar tags obrigatórias.
- **Por quê (referência na arquitetura):** Policies *deny* são a principal causa de falha em deploys de PaaS privado.
- **Responsável Vale:** Cloud CoE / Segurança Vale · **Lead time:** 15 d.u. · **Prioridade:** Alta · **Bloqueia:** Deploy Vale
- **Critério de pronto:** What-if sem violações de policy

### SOL-GOV-05 — Cota de modelos no Microsoft Foundry (Brazil South, Standard regional)

- **O que solicitamos:** Cota de TPM: modelo de chat principal (~50K TPM), chat econômico (~50K TPM) e embeddings `text-embedding-3-large` (~100K TPM) em **Brazil South, SKU Standard regional** (não Global/DataZone).
- **Por quê (referência na arquitetura):** Residência de dados em região única (slide 26: 'Modelos em SKU Standard regional'). Sem cota, os agentes não executam.
- **Responsável Vale:** Cloud CoE Vale + conta Microsoft · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Agentes (Mês 2)
- **Critério de pronto:** Deployments com provisioningState=Succeeded

### SOL-GOV-06 — Budget, tags e centro de custo

- **O que solicitamos:** Budget mensal do RG (referência: R$ 7–16 mil/mês, slide 30) com alertas 50/80/100% para Vale e HAT; tags obrigatórias.
- **Por quê (referência na arquitetura):** Transparência de custo (Control Board) e controle do consumo de tokens.
- **Responsável Vale:** FinOps Vale · **Lead time:** 5 d.u. · **Prioridade:** Média · **Bloqueia:** —
- **Critério de pronto:** Budget ativo

## Rede

### SOL-NET-01 — Alocação da VNet spoke /22 e subnets

- **O que solicitamos:** Faixa 10.X.0.0/22 não sobreposta, com subnets: snet-cae /24 (deleg. Microsoft.App/environments), snet-pe /26, snet-apim /27, snet-agents /27 (deleg. Microsoft.DevOpsInfrastructure/pools), snet-psql /28 (deleg. PostgreSQL), snet-appgw /27, **snet-aiagents /24 (deleg. Microsoft.App/environments — Foundry Agent Service)**.
- **Por quê (referência na arquitetura):** Slide 26 (VNet spoke 10.X.0.0/22). snet-aiagents é exigida pelo standard agent setup com rede privada (não consta no slide).
- **Responsável Vale:** Rede / Cloud Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Faixa e nomes confirmados por escrito

### SOL-NET-02 — Peering spoke ↔ hub corporativo

- **O que solicitamos:** Peering bidirecional da VNet spoke com o hub (use remote gateways, se aplicável), conforme padrão da Vale.
- **Por quê (referência na arquitetura):** Resolução DNS pelo hub, saída controlada e acesso dos usuários/rede corporativa ao APIM interno.
- **Responsável Vale:** Rede Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Peering 'Connected' nos dois lados

### SOL-NET-03 — Rota de saída e regras no Firewall/NVA

- **O que solicitamos:** UDR 0.0.0.0/0 → IP do Firewall/NVA (informar IP). Liberar a allow-list de FQDN/service tags do Anexo A, de origem snet-cae, snet-aiagents, snet-apim e snet-agents.
- **Por quê (referência na arquitetura):** Slide 25 (Firewall/NVA). Sem as regras, jobs não clonam código, não falam com BTP/LeanIX e o APIM não se mantém saudável.
- **Responsável Vale:** Segurança de Rede Vale · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão (Mês 2)
- **Critério de pronto:** Teste de saída do Anexo A OK a partir do Managed DevOps Pool

### SOL-NET-04 — DNS privado pelo hub

- **O que solicitamos:** Para cada zona do Anexo B: link com a VNet spoke **ou** confirmação de que a policy DINE registra os Private Endpoints. Criar zona `psql-integia-dev-brs.private.postgres.database.azure.com`, zona do Container Apps Environment (`*` → staticIp) e registros `apim-integia-dev-brs*.azure-api.net` → IP privado do APIM. Conditional forwarders para a rede on-premises, se usuários acessarem o APIM.
- **Por quê (referência na arquitetura):** Slide 26: 'DNS privado resolvido pelo hub corporativo'. PaaS com acesso público desabilitado só funciona com DNS privado correto.
- **Responsável Vale:** DNS / Rede Vale · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** `04-validate.sh` bloco DNS 100% verde

### SOL-NET-05 — Permissões de rede para automação

- **O que solicitamos:** Service connection do pipeline: *Network Contributor* na VNet spoke. Service principal **DevOpsInfrastructure** (Managed DevOps Pools): *Reader* + *Network Contributor* na VNet. Se a opção (b) de DNS for adotada: *Private DNS Zone Contributor* nas zonas do hub.
- **Por quê (referência na arquitetura):** Criar Private Endpoints, join de subnets delegadas e o pool de agentes privado.
- **Responsável Vale:** Rede / IAM Vale · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Roles efetivas

### SOL-NET-06 — Entrada pública do Bot (Teams) via WAF

- **O que solicitamos:** Aprovar **um** ponto de entrada público, restrito a `/bot/api/messages`: (a) Application Gateway WAF_v2 no RG (IP público, OWASP DRS 2.1, Prevention) ou (b) WAF/Front Door corporativo da Vale apontando para o APIM interno. Fornecer domínio (ex.: cdi-bot-dev.vale.com), DNS público e certificado TLS (importado no Key Vault).
- **Por quê (referência na arquitetura):** Slide 11 (WAF de entrada + Azure Bot). O Bot Framework precisa alcançar o endpoint de mensagens pela internet.
- **Responsável Vale:** Segurança / Rede Vale · **Lead time:** 20 d.u. · **Prioridade:** Alta · **Bloqueia:** A1 no Teams (Mês 3)
- **Critério de pronto:** Teste do Teams → runtime com JWT do Bot validado

### SOL-NET-07 — Conectividade com SAP BTP IS e SAP LeanIX

- **O que solicitamos:** Confirmar os hosts do tenant BTP IS (API e token OAuth) e do workspace LeanIX; liberar saída no firewall; informar se existe IP de saída fixo a ser cadastrado em allow-lists SAP.
- **Por quê (referência na arquitetura):** Ingestão OData (iFlows/scripts), MPL (A3) e LeanIX (A1/A4).
- **Responsável Vale:** Rede Vale + time BTP · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** Ingestão (Mês 2)
- **Critério de pronto:** Chamada de teste 200 a partir do pool

## Identidade

### SOL-IAM-01 — App registration `integia-api-dev`

- **O que solicitamos:** Criar (ou autorizar a criação) da API com App ID URI `api://integia-api-dev`, escopo `Agentes.Usar`, tokens v2 e `groupMembershipClaims=ApplicationGroup`. Admin consent. Atribuir os grupos de conhecimento ao app.
- **Por quê (referência na arquitetura):** Audiência validada no APIM; contexto OBO do usuário; grupos no token alimentam o filtro de grupos do MCP (slides 13 e 20).
- **Responsável Vale:** IAM Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** MCP (Mês 2)
- **Critério de pronto:** Token de teste com `aud` e `groups` corretos

### SOL-IAM-02 — Grupos de segurança

- **O que solicitamos:** Criar: grp-vale-cdi-engenharia, grp-vale-cdi-pg-admins, grp-vale-cdi-cci, grp-vale-cdi-arquitetos, grp-vale-cdi-especialistas e os **grupos de conhecimento** por domínio/pacote (que definem o que cada usuário pode recuperar). Indicar owners.
- **Por quê (referência na arquitetura):** RBAC de operação, admin do PostgreSQL, papéis humanos do fluxo (CCI, arquiteto, especialista) e autorização na recuperação.
- **Responsável Vale:** IAM Vale · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** Deploy Vale
- **Critério de pronto:** ObjectIds informados

### SOL-IAM-03 — Acesso ao SharePoint via Microsoft Graph (Sites.Selected)

- **O que solicitamos:** App `integia-connector-dev` com permissão de aplicação **Sites.Selected** + admin consent; grant **read** nos sites/bibliotecas de ICC010/ICC015 e **write** apenas na biblioteca de publicação; federated credential para a managed identity `id-cdi-ingest-dev` (sem segredo).
- **Por quê (referência na arquitetura):** Captura documental por delta (slide 16) e publicação de versões aprovadas pelo serviço de artefatos.
- **Responsável Vale:** IAM + M365 Vale · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão docs (Mês 2)
- **Critério de pronto:** Delta query retorna itens das bibliotecas do escopo

### SOL-IAM-04 — Contas para a equipe HAT

- **O que solicitamos:** Contas nominais (B2B guest ou contas Vale) para os membros HAT listados, com MFA, inclusão em grp-vale-cdi-engenharia e acesso ao Azure DevOps. Política de expiração alinhada ao contrato.
- **Por quê (referência na arquitetura):** Rastreabilidade individual; nenhuma credencial compartilhada.
- **Responsável Vale:** IAM Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Mês 1
- **Critério de pronto:** Login + MFA OK

### SOL-IAM-05 — Conditional Access para a API dos agentes

- **O que solicitamos:** Aplicar ao app integia-api a política padrão da Vale (MFA, dispositivo gerenciado) e confirmar que as managed identities e Workload Identity Federation não são afetadas.
- **Por quê (referência na arquitetura):** Proteger o acesso humano às ferramentas MCP/agentes sem quebrar chamadas service-to-service.
- **Responsável Vale:** IAM Vale · **Lead time:** 5 d.u. · **Prioridade:** Média · **Bloqueia:** —
- **Critério de pronto:** Sign-in logs sem bloqueios indevidos

### SOL-IAM-06 — Publicação do app do Bot no Microsoft Teams

- **O que solicitamos:** Aprovar e publicar o manifest do app Teams no catálogo da organização, restrito ao público-piloto (demandantes, CCI).
- **Por quê (referência na arquitetura):** Canal do A1 (slide 11: Microsoft Teams → Azure Bot).
- **Responsável Vale:** Admin Teams / M365 Vale · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** A1 no Teams (Mês 3)
- **Critério de pronto:** App visível para o grupo piloto

## Fontes de dados

### SOL-DAT-01 — Inventário do SharePoint (ICC010 / ICC015 / HLD)

- **O que solicitamos:** Lista de sites, bibliotecas e pastas no escopo; donos; regra de versionamento; biblioteca de publicação das versões aprovadas; mapeamento pasta → grupo de conhecimento.
- **Por quê (referência na arquitetura):** Escopo da ingestão e aplicação correta das permissões por grupo.
- **Responsável Vale:** Integração Vale (CCI) · **Lead time:** 5 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão docs
- **Critério de pronto:** Planilha de inventário validada

### SOL-DAT-02 — Azure DevOps: repositórios, Boards e service hook

- **O que solicitamos:** Org/projetos/repositórios do escopo; principal com acesso de leitura (e *Contribute to pull requests* para A2/A3); service hook 'Code pushed' (main) → Service Bus `ingest-codigo`; area path/work item type no Azure Boards para demandas.
- **Por quê (referência na arquitetura):** Ingestão de código pós-merge (slide 27), PRs propostos e rastreio de demandas.
- **Responsável Vale:** Integração Vale + admin DevOps · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão código
- **Critério de pronto:** Evento de push chega à fila

### SOL-DAT-03 — SAP BTP Integration Suite — API de leitura

- **O que solicitamos:** Service key (plano *api*, client credentials) no tenant **DEV** com roles de leitura de design-time artifacts e Message Processing Logs. `deploy_dev` somente se aprovado; importações QA/PRD permanecem com o time BTP Vale.
- **Por quê (referência na arquitetura):** Captura de iFlows/scripts (OData) e MPL para o A3 (slides 15 e 21).
- **Responsável Vale:** Time BTP Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão código / A3
- **Critério de pronto:** Listagem de iFlows e MPL via API

### SOL-DAT-04 — SAP LeanIX — usuário técnico e MCP

- **O que solicitamos:** Workspace e technical user: leitura (fact sheets e relações) para A1/A4; escrita via GraphQL com escopo limitado para o A4, usada **somente após aprovação do CCI**. Confirmar disponibilidade do LeanIX MCP.
- **Por quê (referência na arquitetura):** Contexto de arquitetura e atualização cadastral (slides 22–23).
- **Responsável Vale:** Arquitetura corporativa Vale · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** A1/A4
- **Critério de pronto:** Consulta GraphQL de teste OK

### SOL-DAT-05 — Ferramenta de chamados — API somente leitura

- **O que solicitamos:** Usuário de integração com leitura dos incidentes do grupo de Integração (campos: sintoma, horário, interface, evidências).
- **Por quê (referência na arquitetura):** Entrada do A3 Troubleshooter (slide 20).
- **Responsável Vale:** ITSM Vale · **Lead time:** 10 d.u. · **Prioridade:** Média · **Bloqueia:** A3
- **Critério de pronto:** Consulta de incidente via API

### SOL-DAT-06 — Classificação da informação e autorização de uso em IA

- **O que solicitamos:** Classificação (LGPD/sigilo) de ICCs, código e logs; autorização formal para processamento por LLM em Brazil South; regras de mascaramento no gateway LLM; amostra autorizada para testes.
- **Por quê (referência na arquitetura):** Base para o mascaramento ('Gateway → AI Foundry: mascara e chama', slide 27) e aceite de segurança.
- **Responsável Vale:** Segurança da Informação / DPO Vale · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Ingestão (Mês 2)
- **Critério de pronto:** Parecer formal emitido

## DevOps

### SOL-DEV-01 — Projeto e repositórios no Azure DevOps da Vale

- **O que solicitamos:** Projeto (ou repositórios) para: IaC, aplicação (MCP, gateway, runtime, jobs) e definições dos agentes (versionadas no Git, slide 14). Branch policies padrão da Vale.
- **Por quê (referência na arquitetura):** Código-fonte da solução sob governança da Vale e capacidade transferida (Aceite 04).
- **Responsável Vale:** Admin DevOps Vale · **Lead time:** 5 d.u. · **Prioridade:** Alta · **Bloqueia:** Mês 2
- **Critério de pronto:** Repositórios criados e acessíveis à HAT

### SOL-DEV-02 — Service connection com Workload Identity Federation

- **O que solicitamos:** Service connection ARM (WIF, sem segredo) com escopo no RG; environments `vale-dev` com aprovação manual do time de cloud.
- **Por quê (referência na arquitetura):** Deploy por pipeline com what-if e aprovação (iac/pipelines).
- **Responsável Vale:** Cloud CoE + DevOps Vale · **Lead time:** 10 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Pipeline what-if executa

### SOL-DEV-03 — Managed DevOps Pool

- **O que solicitamos:** Autorizar a criação do pool `mdp-integia-dev-brs` na org (permissão de administrador de agent pools) ou criação pelo time Vale com o módulo fornecido.
- **Por quê (referência na arquitetura):** Build obrigatório dos PRs do A2/A3 e jobs que precisam da rede privada (slide 18 item 20).
- **Responsável Vale:** Admin DevOps Vale · **Lead time:** 10 d.u. · **Prioridade:** Alta · **Bloqueia:** A2/A3
- **Critério de pronto:** Pool online e job de teste executado

## Segurança

### SOL-SEG-01 — Revisão de arquitetura (ARB / Segurança)

- **O que solicitamos:** Agendar revisão do desenho (este pacote + evidências do ambiente HAT) com Arquitetura e Segurança da Vale.
- **Por quê (referência na arquitetura):** Aprovação formal antes do deploy em ambiente Vale.
- **Responsável Vale:** Arquitetura + Segurança Vale · **Lead time:** 15 d.u. · **Prioridade:** Crítica · **Bloqueia:** Deploy Vale
- **Critério de pronto:** Ata com parecer favorável/condicionantes

### SOL-SEG-02 — Avaliação de risco de IA

- **O que solicitamos:** Submeter o caso de uso ao fluxo de IA responsável/governança de IA da Vale (modelos, guardrails, human-in-the-loop, avaliações).
- **Por quê (referência na arquitetura):** Uso de LLM e agentes que propõem alterações em documentos, código e cadastro.
- **Responsável Vale:** Governança de IA Vale · **Lead time:** 20 d.u. · **Prioridade:** Alta · **Bloqueia:** Piloto (Mês 3)
- **Critério de pronto:** Parecer emitido

### SOL-SEG-03 — Defender for Cloud e integração com SIEM

- **O que solicitamos:** Confirmar planos do Defender (Storage, Key Vault, AI, Containers, APIs) e o destino dos diagnostic settings (Log Analytics central/Sentinel).
- **Por quê (referência na arquitetura):** Monitoramento de segurança contínuo.
- **Responsável Vale:** SOC Vale · **Lead time:** 10 d.u. · **Prioridade:** Média · **Bloqueia:** —
- **Critério de pronto:** Diagnostic settings apontando para o destino corporativo

### SOL-SEG-04 — Pentest/scan do endpoint público

- **O que solicitamos:** Scan/pentest do host público do Bot antes do piloto com usuários.
- **Por quê (referência na arquitetura):** Único endpoint exposto à internet.
- **Responsável Vale:** Segurança Vale · **Lead time:** 15 d.u. · **Prioridade:** Média · **Bloqueia:** Piloto (Mês 3)
- **Critério de pronto:** Relatório sem achados críticos

## Operação

### SOL-OPS-01 — Calendário de mudanças e CAB

- **O que solicitamos:** Informar janelas de mudança, congelamento de fim de ano e o fluxo de CR para rede/DNS/firewall e deploys.
- **Por quê (referência na arquitetura):** Planejamento realista do cronograma.
- **Responsável Vale:** Gestão de Mudanças Vale · **Lead time:** 3 d.u. · **Prioridade:** Alta · **Bloqueia:** Mês 1
- **Critério de pronto:** Calendário recebido

### SOL-OPS-02 — Acesso de observabilidade

- **O que solicitamos:** Reader no Log Analytics/App Insights do projeto para HAT (e Workbook do Control Board).
- **Por quê (referência na arquitetura):** Hypercare e operação assistida (Mês 4).
- **Responsável Vale:** Cloud CoE Vale · **Lead time:** 5 d.u. · **Prioridade:** Média · **Bloqueia:** Mês 4
- **Critério de pronto:** Consultas KQL executam

## Anexo A — Allow-list de saída (Firewall/NVA do hub)

| Destino | Porta | Origem | Finalidade |
|---|---|---|---|
| login.microsoftonline.com, login.microsoft.com | 443 | Todas | Entra ID (tokens, WIF, OBO) |
| graph.microsoft.com, <tenant>.sharepoint.com | 443 | snet-cae | Ingestão SharePoint (Graph delta) e publicação |
| management.azure.com | 443 | snet-cae, snet-agents, snet-apim | ARM (managed identity, deploy) |
| mcr.microsoft.com, *.data.mcr.microsoft.com | 443 | snet-cae, snet-aiagents, snet-agents | Imagens base / plataforma |
| dev.azure.com, *.dev.azure.com, *.visualstudio.com, *.vsassets.io, vstoken.dev.azure.com, download.agent.dev.azure.com | 443 | snet-cae, snet-agents | Azure Repos/Boards/Pipelines e agente do pool |
| <tenant>.it-cpi0xx.cfapps.<região>.hana.ondemand.com, <subdomínio>.authentication.<região>.hana.ondemand.com | 443 | snet-cae | SAP BTP IS OData/MPL + token OAuth |
| <workspace>.leanix.net | 443 | snet-cae, snet-aiagents | SAP LeanIX GraphQL/MCP |
| login.botframework.com, api.botframework.com, smba.trafficmanager.net, *.botframework.com | 443 | snet-cae | Bot Framework (validação JWT e respostas ao Teams) |
| *.in.applicationinsights.azure.com, dc.services.visualstudio.com, *.monitor.azure.com | 443 | Todas | Telemetria (se não houver AMPLS) |
| Service tags: Storage, Sql, AzureKeyVault, AzureMonitor, AzureActiveDirectory | 443/1433/1886 | snet-apim | Dependências do APIM em VNet |
| archive.ubuntu.com, security.ubuntu.com, azure.archive.ubuntu.com, pypi.org, files.pythonhosted.org, registry.npmjs.org | 80/443 | snet-agents | Build no Managed DevOps Pool (pode usar mirror corporativo) |

Observação: tráfego para os PaaS do projeto (Storage, Search, Cosmos, Foundry, KV, ACR, Service Bus) **não** passa pelo firewall — vai por Private Endpoint dentro da spoke. Valores `<...>` são confirmados com o time BTP/LeanIX (SOL-NET-07).

## Anexo B — Zonas DNS privadas necessárias

- `privatelink.blob.core.windows.net`
- `privatelink.dfs.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.search.windows.net`
- `privatelink.servicebus.windows.net`
- `privatelink.azurecr.io`
- `privatelink.documents.azure.com`
- `privatelink.cognitiveservices.azure.com`
- `privatelink.openai.azure.com`
- `privatelink.services.ai.azure.com`
- `psql-integia-dev-brs.private.postgres.database.azure.com`
- `<defaultDomain do cae-integia-dev-brs> (registro * → staticIp)`
- `azure-api.net (registros apim-integia-dev-brs*)`

## Anexo C — Modelo de e-mail de encaminhamento

```text
Assunto: [Core Data Integration] Solicitações de ambiente e acessos — 1ª onda (ref. SOL-*)

Prezados,

Conforme o plano de mobilização do projeto Core Data Integration (Integração / Strategy Lab),
encaminhamos o pacote de solicitações necessárias para implantar o ambiente rg-integia-dev-brs
em Brazil South, com acesso exclusivamente privado (Private Endpoints) e identidades gerenciadas.

O desenho e o código de infraestrutura (Bicep) já foram validados em ambiente espelho da HAT
Thinking; anexamos o relatório de validação, a matriz de identidades/RBAC e o what-if.

Itens críticos para o Mês 1 (Assessment) e início do Mês 2 (Foundation):
  SOL-GOV-01/02, SOL-NET-01/02/03/04, SOL-IAM-01/03/04, SOL-DAT-01/02/03/06, SOL-DEV-02, SOL-SEG-01.

Pedimos a indicação de um ponto focal por área responsável e a confirmação dos prazos.
Ficamos à disposição para uma sessão técnica de 1h com Rede/DNS, IAM e Cloud CoE.

Atenciosamente,
HAT Thinking — Equipe Core Data Integration
```

## Anexo D — Controle de status

Status possíveis: `A enviar` → `Enviado` → `Em análise` → `Aprovado` → `Implementado` → `Validado (HAT)`. O status vive na aba *Solicitações Vale* do cronograma.
