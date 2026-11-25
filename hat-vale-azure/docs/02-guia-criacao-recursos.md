# 02 · Guia de criação dos recursos (passo a passo)

> Vale para **HAT (lab)** e **Vale (dev)**. A criação é sempre pelo IaC (`iac/`); este guia explica **a ordem, o que cada recurso faz no desenho, as configurações que não podem mudar e como verificar**. Comandos assumem Azure CLI ≥ 2.67, Bicep ≥ 0.30, `jq`, `psql` 16.

---

## 0. Pré-requisitos (uma vez por ambiente)

| # | Ação | HAT | Vale | Comando / referência |
|---|---|---|---|---|
| 0.1 | Assinatura dedicada e RG | Nós | Time de cloud Vale (SOL-GOV-01) | `az group create -n rg-integia-<env>-brs -l brazilsouth` |
| 0.2 | Resource providers registrados | Nós | Vale (SOL-GOV-03) | `iac/scripts/00-preflight.sh <sub>` |
| 0.3 | Cota de modelos em Brazil South | Nós (portal Foundry → Quotas) | Vale (SOL-GOV-05) | `az cognitiveservices usage list -l brazilsouth` |
| 0.4 | Grupos e app registrations Entra | Nós | IAM Vale (SOL-IAM-*) | `iac/scripts/03-entra-setup.sh lab|dev` |
| 0.5 | Service connection DevOps com **Workload Identity Federation** | Nós | Vale (SOL-DEV-02) | Project settings → Service connections → Azure Resource Manager → WIF |
| 0.6 | Certificado TLS do host público do Bot no Key Vault | Nós (domínio HAT) | Vale (SOL-NET-06) | `az keyvault certificate import --vault-name <kv> -n tls-appgw -f cert.pfx` |
| 0.7 | Preencher `.bicepparam` (sem `<...>`) | Nós | Nós + Vale | `iac/bicep/params/*.bicepparam` |

> **Ordem com o Key Vault:** o certificado só pode ser importado depois que o KV existe e com acesso de rede. No primeiro deploy use `deployAppGw=false`, importe o certificado pelo jump/pool e rode de novo com `true`.

## 1. Ordem de criação (o `main.bicep` já respeita)

```
1 Rede (VNet, subnets, NSG, UDR) ─► 2 DNS privado ─► 3 Monitor + Identidades
   ─► 4 PaaS de dados (KV, ADLS×2, SB, ACR, Search, Cosmos, DocIntel, PostgreSQL)
   ─► 5 Private Endpoints ─► 6 Foundry (conta, deployments, projeto, conexões) + PE
   ─► 7 RBAC ─► 8 Capability Host (Agent Service) ─► 9 Durable Task Scheduler
   ─► 10 Container Apps (env, apps, jobs) ─► 11 APIM interno + políticas
   ─► 12 DNS do CAE/APIM ─► 13 WAF ─► 14 Bot/Teams ─► 15 Managed DevOps Pool
   ─► 16 Pós-deploy de data plane (SQL, índices, Cosmos RBAC) ─► 17 Validação
```

Deploy: `iac/scripts/01-deploy.sh lab` (what-if → confirmação → deploy). Tempo típico: **45–75 min** (APIM em VNet é o mais lento, ~35–45 min).

## 2. Rede — `modules/network.bicep`

| Subnet | Faixa lab | Tamanho | Delegação | Uso |
|---|---|---|---|---|
| `snet-cae` | 10.50.0.0/24 | /24 | Microsoft.App/environments | Container Apps Env interno, zonal |
| `snet-pe` | 10.50.1.0/26 | /26 | — | ~11 Private Endpoints |
| `snet-apim` | 10.50.1.64/27 | /27 | — | APIM VNet interno |
| `snet-agents` | 10.50.1.96/27 | /27 | Microsoft.DevOpsInfrastructure/pools | Managed DevOps Pool |
| `snet-psql` | 10.50.1.128/28 | /28 | Microsoft.DBforPostgreSQL/flexibleServers | PostgreSQL VNet-integrado |
| `snet-appgw` | 10.50.1.192/27 | /27 | — | App Gateway WAF_v2 |
| `snet-aiagents` | 10.50.2.0/24 | /24 | Microsoft.App/environments | Foundry Agent Service (network injection) |
| `AzureBastionSubnet` / `snet-jump` | 10.50.3.0/26 · 10.50.1.144/28 | — | — | **somente lab** |

Pontos de atenção:
- `snet-aiagents` **não aparece no slide 26**; é exigida pelo *standard agent setup* com rede privada. Incluída na solicitação de rede da Vale (SOL-NET-01). Confirmar o tamanho mínimo vigente na documentação do Agent Service.
- NSG do APIM tem as regras obrigatórias (3443 de `ApiManagement`, 6390 de `AzureLoadBalancer`, saída para Storage/SQL/KeyVault/Monitor). Na Vale, o firewall do hub precisa liberar as mesmas dependências de saída.
- Na Vale, `firewallPrivateIp` cria UDR `0.0.0.0/0 → NVA`; `dnsServers` aponta para o resolver do hub.

**Verificar:** `az network vnet subnet list -g <rg> --vnet-name vnet-integia-<env>-brs -o table`

## 3. DNS privado — `modules/private-dns.bicep`, `modules/cae-dns.bicep`

Zonas necessárias (lista que vai para o time de DNS da Vale):

| Zona | Recurso |
|---|---|
| privatelink.blob.core.windows.net | ADLS (blob) e storage do Agent Service |
| privatelink.dfs.core.windows.net | ADLS (dfs) |
| privatelink.vaultcore.azure.net | Key Vault |
| privatelink.search.windows.net | AI Search |
| privatelink.servicebus.windows.net | Service Bus |
| privatelink.azurecr.io | ACR (inclui `<registry>.brazilsouth.data.azurecr.io`) |
| privatelink.documents.azure.com | Cosmos DB |
| privatelink.cognitiveservices.azure.com | Foundry, Document Intelligence |
| privatelink.openai.azure.com | Foundry (endpoint OpenAI) |
| privatelink.services.ai.azure.com | Foundry (projetos/Agent Service) |
| `psql-integia-<env>-brs.private.postgres.database.azure.com` | PostgreSQL VNet-integrado |
| `<defaultDomain>` do Container Apps Env (`*` → staticIp) | Apps internos |
| `azure-api.net` (registros do APIM → IP privado) | APIM interno |

**Verificar (do jump/pool):** `nslookup <kv>.vault.azure.net` deve retornar `10.x.x.x`.

## 4. Observabilidade e identidades

- `monitoring.bicep`: Log Analytics (`log-integia-<env>-brs`) + App Insights (`appi-…`). Na Vale pode-se apontar `existingWorkspaceId` para o workspace central.
- `identities.bicep`: **8 UAMIs** `id-cdi-{artef,ingest,mcp,valid,orch,gw,bot,appgw}-<env>`. As 4 primeiras são as do slide 12; as demais separam orquestração, chamada a modelos, bot e WAF. Matriz completa em `docs/04`.

## 5. PaaS de dados

| Recurso | Módulo | Configurações obrigatórias | Verificação |
|---|---|---|---|
| Key Vault `kv-integia-<env>-brs` | keyvault | RBAC-only, `publicNetworkAccess=Disabled`, soft delete; purge protection na Vale | `az keyvault show -n <kv> --query properties.publicNetworkAccess` |
| ADLS `stintegia<env>brs` | storage | HNS on, `allowSharedKeyAccess=false`, containers `raw`, `gold`, `entregaveis`, ZRS | `az storage account show … --query isHnsEnabled` |
| Storage do Agent Service `stintegiaag<env>brs` | storage | HNS **off**, sem chave | — |
| Service Bus `sb-integia-<env>-brs` | servicebus | **Premium** (PE), `disableLocalAuth`, filas `ingest-*`, `avaliacao` | `az servicebus queue list …` |
| ACR `crintegia<env>brs` | acr | Premium, admin off, público off | `az acr show … --query publicNetworkAccess` |
| AI Search `srch-integia-<env>-brs` | search | `disableLocalAuth=true`, semantic ranker standard, público off | índices pelo pós-deploy |
| Cosmos `cosmos-integia-<env>-brs` | cosmos | NoSQL serverless, `disableLocalAuth` | — |
| Document Intelligence `di-integia-<env>-brs` | docintel | `prebuilt-layout` → Markdown, sem chave | — |
| PostgreSQL `psql-integia-<env>-brs` | postgres | VNet-integrado, **Entra-only**, `azure.extensions=AGE,VECTOR…`, `shared_preload_libraries=age` | `04-validate.sh` (AGE instalado) |

> **Pegadinha AGE:** mudar `shared_preload_libraries` reinicia o servidor. O módulo aplica na criação; em servidor existente agende janela.

## 6. Foundry (modelos + Agent Service)

1. **Conta** `aif-integia-<env>-brs` (kind `AIServices`, `allowProjectManagement`, `disableLocalAuth`, público off, `networkInjections` na `snet-aiagents`).
2. **Deployments** (serial): chat principal, chat econômico, embeddings 3072d — SKU **Standard regional** (dados não saem de Brazil South). Confirmar modelos e versões com `00-preflight.sh`; a lista no `.bicepparam` é ponto de partida.
3. **Projeto** `proj-cdi-<env>` com identidade própria.
4. **Conexões** do projeto (AAD): Cosmos (threads), Storage (arquivos), AI Search (vector store), App Insights (tracing).
5. **RBAC da identidade do projeto** (no `rbac.bicep`): Cosmos DB Operator, Storage Blob Data Contributor, Search Index Data Contributor + Search Service Contributor.
6. **Capability Host** `caphost-agents` (depois do RBAC).
7. **Pós-deploy:** Cosmos *Built-in Data Contributor* para o projeto (`02-post-deploy.sh`).
8. **Guardrails:** RAI policy `Microsoft.DefaultV2` (Prompt Shields para jailbreak e ataques indiretos); o projeto também delimita o conteúdo recuperado como documento de contexto.

**Verificar:** `az cognitiveservices account deployment list -g <rg> -n aif-… -o table`; criar agente de teste pelo SDK a partir do jump (`AZURE_AI_PROJECT_ENDPOINT` = output `foundryProjectEndpoint`).

## 7. Conectores de fonte (configuração lógica)

| Fonte | Mecanismo (deck) | Identidade | O que configurar |
|---|---|---|---|
| **SharePoint Online** (ICC010/ICC015) | Microsoft Graph + delta query (slide 16) | App `integia-connector-<env>` com **Sites.Selected**; credencial = *federated credential* da UAMI `id-cdi-ingest` | Admin consent + `POST /sites/{id}/permissions` (read nas bibliotecas de ICC; write só na biblioteca de publicação, para o serviço de artefatos) |
| **Azure Repos** (código) | Service hook pós-merge → Service Bus `ingest-codigo` (slide 27); clone pelo job | Service principal/UAMI adicionada à org DevOps com **Basic + leitura** nos repositórios do escopo; para PR (A2/A3) **Contribute to pull requests** | Service hook "Code pushed" (branch main) → Azure Service Bus |
| **SAP BTP Integration Suite** | OData API (`/api/v1/IntegrationDesigntimeArtifacts`, MPL `/api/v1/MessageProcessingLogs`) | Service key OAuth *client credentials* (plano `api`) no KV `btp-is-oauth` | Roles **somente leitura** (`WorkspacePackagesRead`, `MonitoringDataRead`); `deploy_dev` só se aprovado; QA/PRD pelo time BTP Vale |
| **SAP LeanIX** | MCP leitura + GraphQL API (escrita após aprovação CCI) | Technical user (API token) no KV `leanix-api-token` | Usuário técnico *Viewer* para leitura; *Member/Admin* com escopo limitado para o A4 |
| **Ferramenta de chamados** (A3) | API da ferramenta (a confirmar: ServiceNow?) | Usuário de integração somente leitura | Tabelas de incidente do grupo de Integração |
| **Azure Boards** | REST | Mesmo principal DevOps | Work item type para demanda; campos de vínculo |
| **Teams** | Azure Bot (UserAssignedMSI) | `id-cdi-bot` | Publicação do app Teams pelo admin de Teams (SOL-IAM-06) |

Federated credential (SharePoint sem segredo): App registration → *Certificates & secrets* → *Federated credentials* → cenário "Managed identity" → selecionar `id-cdi-ingest-<env>`.

## 8. Compute — Container Apps

- Ambiente `cae-integia-<env>-brs`: **interno**, zonal, workload profile Consumption, mTLS entre apps, logs no Log Analytics.
- Apps (imagens placeholder até o pipeline de aplicação publicar no ACR): `app-integia-mcp` (mín. 2), `app-integia-gateway` (mín. 2), `app-integia-runtime`, `app-integia-artef`, `app-integia-valid`. Cada app usa **a sua** UAMI e `AZURE_CLIENT_ID`.
- Jobs: `job-ingest-codigo` (evento: fila SB, scaler com identidade), `job-ingest-docs` (agendado a cada 30 min, delta Graph), `job-avaliacao` (manual/CI).
- Ingress `external=true` em ambiente interno = acessível **somente pela VNet**; APIM é o único consumidor.

## 9. Gateway — APIM interno + políticas

- `apim-integia-<env>-brs` em modo **Internal** na `snet-apim`.
- APIs: `/mcp` → MCP; `/llm` → gateway LLM; `/bot/api/messages` → runtime.
- Políticas (`iac/bicep/apim-policies/`): `validate-azure-ad-token` (audiência `api://integia-api-<env>`), `x-demanda` obrigatório, `rate-limit-by-key` por agente+demanda, `llm-token-limit` e `llm-emit-token-metric` (dimensões agente/demanda → Control Board), `validate-jwt` do Bot Framework.
- **Verificar:** sem token → 401; com token sem `x-demanda` → 400.

## 10. Entrada pública (Bot) e WAF

- App Gateway WAF_v2 (OWASP DRS 2.1 + Bot Manager, modo *Prevention*) com regra custom que **bloqueia tudo que não for `/bot/api/messages`**. Backend = APIM interno (FQDN privado).
- Azure Bot `bot-integia-<env>-brs`, tipo **UserAssignedMSI**, canal Teams.
- Na Vale este é o item mais sensível (IP público). Alternativa: WAF/Front Door corporativo apontando para o APIM (SOL-NET-06).

## 11. Durable Task Scheduler e Managed DevOps Pool

- DTS `dts-integia-<env>-brs`, task hub `cdi` — estado dos fluxos A2/A3/A4 com espera por aprovação humana. Role *Durable Task Data Contributor* para `id-cdi-orch` (pós-deploy). **Preview/GA a confirmar** na data do deploy.
- Managed DevOps Pool `mdp-integia-<env>-brs` na `snet-agents`: build obrigatório dos PRs do A2/A3 e jobs que precisam de rede privada (pós-deploy, índices). Requer *Reader* + *Network Contributor* do SP **DevOpsInfrastructure** na VNet.

## 12. Pós-deploy e validação

```bash
# de dentro da VNet (jump no lab, pool na Vale)
./iac/scripts/02-post-deploy.sh lab   # roles DTS/Cosmos, schema SQL + AGE, principals Entra, índices
./iac/scripts/04-validate.sh lab      # relatório validacao-lab-<data>.md = evidência de aceite
```

## 13. Checklist de "pronto" da infraestrutura

- [ ] Nenhum PaaS com `publicNetworkAccess` habilitado (exceto APIM em modo Internal e o IP do WAF)
- [ ] Todos os FQDNs privados resolvem para 10.x
- [ ] Nenhuma chave/connection string em app settings (somente UAMI), exceto App Insights
- [ ] PostgreSQL só aceita token Entra; extensão AGE ativa; grafo `cdi_grafo` criado
- [ ] Índices `idx-codigo`, `idx-docs`, `idx-leanix` criados
- [ ] Deployments de modelo `Succeeded`, cota registrada
- [ ] MCP: 401 sem token, 400 sem `x-demanda`, 200 com ambos
- [ ] Métrica `cdi-llm` aparecendo no App Insights por agente/demanda
- [ ] Pipeline de infra com what-if + aprovação manual
- [ ] Budget e alertas configurados
