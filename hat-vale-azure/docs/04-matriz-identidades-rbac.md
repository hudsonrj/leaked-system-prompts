# 04 · Matriz de identidades e RBAC (menor privilégio)

> Implementada em `iac/bicep/modules/rbac.bicep` (roles com GUID fixo) e `iac/scripts/02-post-deploy.sh` (Durable Task, Cosmos data plane, PostgreSQL). Base: slide 12, "Identidades de leitura e gravação" (id-cdi-artef, id-cdi-ingest, id-cdi-mcp, id-cdi-valid).

## 1. Managed identities (user-assigned)

| Identidade | Usada por | Função no desenho |
|---|---|---|
| `id-cdi-ingest-<env>` | job-ingest-codigo, job-ingest-docs, (federated credential do app Graph) | Captura fontes → Raw, prepara Gold, vetoriza, indexa, grava linhagem e grafo |
| `id-cdi-artef-<env>` | app-integia-artef | Materializa artefatos; publica aprovados (SharePoint/entregáveis); grava matriz e changeset LeanIX |
| `id-cdi-mcp-<env>` | app-integia-mcp | Recuperação com filtro de grupos (somente leitura) |
| `id-cdi-valid-<env>` | app-integia-valid, job-avaliacao | Validadores determinísticos e avaliações (somente leitura) |
| `id-cdi-orch-<env>` | app-integia-runtime | Orquestrador: Agent Service, Durable Task, eventos |
| `id-cdi-gw-<env>` | app-integia-gateway | Único caller dos deployments de modelo (mascaramento antes do LLM) |
| `id-cdi-bot-<env>` | Azure Bot | Identidade do bot (UserAssignedMSI) |
| `id-cdi-appgw-<env>` | Application Gateway | Lê o certificado TLS no Key Vault |
| *(system)* projeto Foundry | Agent Service (standard setup) | Threads no Cosmos, arquivos no Storage, vector store no Search |

## 2. Azure RBAC — control/data plane

| Recurso (escopo) | ingest | artef | mcp | valid | orch | gw | projeto Foundry | grp engenharia |
|---|---|---|---|---|---|---|---|---|
| ADLS `raw` (container) | Blob Data Contributor | — | — | — | — | — | — | Blob Data Reader (conta) |
| ADLS `gold` (container) | Blob Data Contributor | Blob Data Reader | Blob Data Reader | Blob Data Reader | — | — | — | ↑ |
| ADLS `entregaveis` (container) | — | Blob Data Contributor | — | Blob Data Reader | — | — | — | ↑ |
| Storage do Agent Service | — | — | — | — | — | — | Blob Data Contributor | — |
| AI Search | Index Data Contributor | — | Index Data Reader | Index Data Reader | — | — | Index Data Contributor + Service Contributor | Service Contributor + Index Data Contributor |
| Key Vault | Secrets User | Secrets User | Secrets User | — | Secrets User | Secrets User | — | Secrets Officer |
| ACR | AcrPull | AcrPull | AcrPull | AcrPull | AcrPull | AcrPull | — | AcrPush |
| Service Bus | Data Receiver + Sender | — | — | — | Data Sender | — | — | — |
| Foundry (conta) | — | — | — | — | **Azure AI User** | **Cognitive Services OpenAI User** | — | Azure AI User |
| Document Intelligence | Cognitive Services User | — | — | — | — | — | — | — |
| Cosmos DB | — | — | — | — | — | — | Cosmos DB Operator + *Built-in Data Contributor* (data plane) | — |
| Durable Task Scheduler | — | — | — | — | Durable Task Data Contributor | — | — | — |

`id-cdi-bot` e `id-cdi-appgw`: só o necessário ao serviço (appgw → Key Vault Secrets User).

## 3. PostgreSQL (`registro` + grafo `cdi_grafo`) — `iac/sql/002-grants.sql`

| Objeto | ingest | artef | mcp | valid | orch |
|---|---|---|---|---|---|
| fonte, permissao_fonte, versao, linhagem, evento_ingestao | **RW** | R (fonte, versao, linhagem) | R | R | — |
| matriz_icc015, leanix_changeset, artefato | — | **RW** | R | R | R |
| grafo `cdi_grafo` | **RW** | — | R | R | — |

Login apenas por token Entra (`passwordAuth=Disabled`); admin = grupo `grp-<org>-cdi-pg-admins`.

## 4. Acessos fora do Azure (fontes)

| Sistema | Principal | Permissão | Escrita? |
|---|---|---|---|
| SharePoint (Graph) | app `integia-connector-<env>` (federated → id-cdi-ingest) | Sites.Selected: read nas bibliotecas de ICC | write **só** na biblioteca de publicação, usada pelo serviço de artefatos após aprovação |
| Azure Repos | principal DevOps do projeto | Read nos repositórios do escopo | Abrir PR (A2/A3); **merge só por humano** (arquiteto/especialista) |
| Azure Boards | idem | Read/Write work items da área | Sim (estado da demanda e evidências) |
| SAP BTP IS | service key OAuth (KV `btp-is-oauth`) | Leitura de design-time artifacts e MPL | `deploy_dev` opcional; QA/PRD apenas time BTP Vale |
| SAP LeanIX | technical user (KV `leanix-api-token`) | Leitura (MCP/GraphQL) | GraphQL mutations somente após aprovação do CCI (A4) |
| Chamados | usuário de integração | Leitura de incidentes | Não |
| Teams | Azure Bot | Mensagens com usuários do piloto | — |

## 5. Pessoas (Vale e HAT)

| Grupo | Membros | Acesso |
|---|---|---|
| `grp-vale-cdi-engenharia` | HAT + time técnico Vale | Reader no RG; Contributor elegível via PIM; roles de operação da tabela 2 |
| `grp-vale-cdi-pg-admins` | 2–3 pessoas | Admin Entra do PostgreSQL |
| `grp-vale-cdi-cci` | CCI | Aprova ICC010, matriz/ICC015, changeset LeanIX |
| `grp-vale-cdi-arquitetos` | Arquitetos revisores | Revisa ICC015 Gold e PR; merge |
| `grp-vale-cdi-especialistas` | Especialistas de integração | Valida diagnóstico/correção do A3 |
| `grp-vale-cdi-know-*` | Por domínio/pacote | Define o que cada usuário pode recuperar (filtro de grupos do MCP) |

## 6. Regras invariantes

1. Nenhuma identidade tem **Owner** nem **User Access Administrator**.
2. Nenhuma chave de acesso local (Storage, Search, Service Bus, Cosmos, Foundry: `disableLocalAuth`).
3. Escrita em sistemas corporativos (SharePoint, Repos, LeanIX) só ocorre **depois** do aceite humano registrado no PostgreSQL/Boards.
4. O filtro de grupos é aplicado **antes** da busca e da expansão no grafo; sem grupo autorizado → zero resultados.
5. Revisão de acesso trimestral (Access Reviews) para os grupos humanos.
