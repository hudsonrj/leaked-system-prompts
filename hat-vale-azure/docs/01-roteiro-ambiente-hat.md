# 01 · Roteiro — Ambiente interno Azure HAT (espelho do Core Data Integration Vale)

> **Objetivo:** construir no tenant/assinatura da HAT um ambiente **idêntico em arquitetura** ao desenho aprovado para a Vale (deck *Core Foundation Integração Vale*, slides 11–29), usando **o mesmo código de IaC**. Com ele nós (1) provamos que a infraestrutura sobe, (2) desenvolvemos e testamos agentes, MCP e ingestão sem depender de acessos da Vale, e (3) geramos, a partir do que funcionou, as solicitações de permissão e os scripts que a Vale vai executar ou aprovar.

---

## 1. Princípios

| # | Princípio | Consequência prática |
|---|---|---|
| P1 | **Um template, dois ambientes** | `iac/bicep/main.bicep` + `params/lab.bicepparam` (HAT) e `params/vale-dev.bicepparam` (Vale). Nada é criado "na mão" no portal. |
| P2 | **Espelho fiel onde importa** | Rede privada, Private Endpoints, APIM interno, identidades por serviço, Entra-only, Brazil South: iguais. |
| P3 | **Economia só onde não muda o desenho** | SKUs menores no lab (APIM Developer, Search Basic, PG Burstable), desligamento noturno. |
| P4 | **Tudo que precisarmos no lab vira item de solicitação** | Cada permissão usada na HAT é registrada em `docs/03` com justificativa. |
| P5 | **Dados da Vale não entram no lab** | Lab usa dados sintéticos/anonimizados (ICC010/ICC015 de exemplo, repositório de iFlows fictício, LeanIX sandbox). |
| P6 | **Sem segredos em código** | Managed Identity + Workload Identity Federation; segredos inevitáveis (LeanIX, BTP) no Key Vault. |

## 2. Arquitetura-alvo (resumo do deck)

```mermaid
flowchart LR
  subgraph Canais
    T[Teams] --> BOT[Azure Bot]
  end
  BOT -->|/api/messages| WAF[App Gateway WAF_v2]
  WAF --> APIM[APIM interno<br/>snet-apim]
  subgraph VNet spoke 10.x.0.0/22 — Brazil South
    APIM --> MCP[app-integia-mcp]
    APIM --> GW[app-integia-gateway<br/>gateway LLM]
    APIM --> RT[app-integia-runtime<br/>orquestrador]
    RT --> DTS[(Durable Task<br/>Scheduler)]
    RT --> ART[app-integia-artef]
    RT --> VAL[app-integia-valid]
    JOBS[job-ingest-codigo / docs / avaliação] --> SB[(Service Bus Premium)]
    MDP[Managed DevOps Pool<br/>snet-agents]
  end
  subgraph PaaS via Private Endpoint
    ADLS[(ADLS Gen2<br/>raw/gold/entregáveis)]
    SRCH[(AI Search<br/>idx-codigo/docs/leanix)]
    PG[(PostgreSQL Flexible<br/>registro + AGE)]
    COS[(Cosmos DB<br/>threads Agent Service)]
    AIF[Microsoft Foundry<br/>modelos + Agent Service]
    DI[Document Intelligence]
    KV[(Key Vault)]
    ACR[(ACR Premium)]
  end
  MCP --> SRCH & PG & ADLS
  GW --> AIF
  JOBS --> ADLS & SRCH & PG & DI
  RT --> AIF
  AIF --> COS & SRCH
  Fontes[SharePoint · Azure Repos · BTP IS · LeanIX · Chamados] -.ingestão.-> JOBS
```

## 3. Decisões de base do ambiente HAT

| Decisão | Recomendação | Alternativa |
|---|---|---|
| Tenant | Tenant corporativo HAT (Entra ID P1/P2 para Conditional Access/PIM) | Tenant dedicado de laboratório (isola testes de app registration/consent) |
| Estrutura | Management Group `mg-hat-labs` → assinatura **`sub-hat-cdi-lab`** | RG em assinatura existente (não recomendado: policies/custos misturados) |
| Região | **Brazil South** (único) | — (residência de dados é requisito) |
| Resource group | `rg-integia-lab-brs` | — |
| Acesso ao data plane privado | Bastion Standard + VM jump com login Entra | VPN P2S (custo fixo maior, melhor UX) |
| Azure DevOps | Org HAT, projeto `cdi-lab`, repositório deste pacote | GitHub + Actions (OIDC) |
| Orçamento | Budget R$ 15 mil/mês com alertas 50/80/100 % | — |
| Dados | Corpus sintético: 10 ICC010, 10 ICC015, 5 iFlows + Groovy, export LeanIX sandbox | Dados reais anonimizados com aval da Vale |

## 4. Fases do roteiro

| Fase | Nome | Duração | Entregas | Critério de saída |
|---|---|---|---|---|
| **F0** | Fundação de governança | 3 dias | Assinatura, MG, budget, grupos Entra, org/projeto DevOps, service connection (WIF) | `00-preflight.sh` sem pendências |
| **F1** | Rede e DNS | 3 dias | VNet /22, subnets, NSGs, zonas privadas, Bastion + jump | Jump resolve `privatelink.*` → IP privado |
| **F2** | Dados e segurança | 4 dias | KV, ADLS, Service Bus, ACR, AI Search, PostgreSQL + AGE, Cosmos, PEs, identidades, RBAC | `04-validate.sh` blocos 1–3 verdes |
| **F3** | IA (Foundry) | 4 dias | Conta AIServices, projeto, deployments (chat + embeddings), Document Intelligence, Agent Service standard setup (caphost) | Agente "hello" responde via Agent Service dentro da VNet |
| **F4** | Gateway e compute | 4 dias | Container Apps Env interno, apps (mcp, gateway, runtime, artef, valid), jobs, APIM interno + políticas, DTS, WAF + Bot/Teams | `curl` MCP sem token = 401; com token = 200; mensagem do Teams chega ao runtime |
| **F5** | CI/CD e observabilidade | 3 dias | Pipeline infra (what-if + aprovação), pipeline de apps, Managed DevOps Pool, dashboards de tokens, alertas | Deploy ponta a ponta por pipeline sem acesso manual |
| **F6** | Prova de valor técnica | 5 dias | Ingestão de código (DevOps → SB → job → Gold → índice → linhagem), ingestão de docs (Graph delta), MCP `buscar_codigo`/`buscar_documentos`/`mapear_impacto`, A2 em modo matriz | Matriz ICC015 × código gerada com citações (chunk_id, linhas, versão) |
| **F7** | Empacotamento para a Vale | 3 dias | `vale-dev.bicepparam` preenchível, solicitações (docs/03 + .docx), runbook, evidências do lab | Pacote revisado por arquiteto HAT e enviado |

> F0–F5 ≈ 4 semanas corridas. F6 roda parcialmente em paralelo com F5. Detalhe tarefa a tarefa em `cronograma/Cronograma_HAT_Vale_CDI.xlsx`.

## 5. Diferenças HAT (lab) × Vale (dev)

| Item | HAT `lab` | Vale `dev` | Motivo |
|---|---|---|---|
| DNS privado | Zonas criadas no RG | Zonas do **hub corporativo** (policy DINE ou IDs informados) | slide 26 "DNS privado resolvido pelo hub" |
| Saída internet | Direta (sem NVA) | UDR 0.0.0.0/0 → **Firewall/NVA do hub** + allow-list FQDN | slide 25 |
| Acesso operacional | Bastion + jump | Rede corporativa/VPN + Managed DevOps Pool | Vale não terá VM nossa |
| APIM | Developer | Developer (dev) → Premium (prd) | SLA/zonas |
| AI Search | Basic | Standard S1 | volume de vetores 3072d |
| PostgreSQL | B2s Burstable | D2ds_v5 GP (HA zonal em prd) | carga e SLA |
| Entrada pública do Bot | App Gateway WAF próprio | WAF próprio **ou** WAF/Front Door corporativo | política de borda da Vale |
| Nomes globais | sufixo `-hat` | nomes do desenho (`apim-integia-dev-brs`…) | evitar colisão |
| Fontes de dados | Sintéticas | SharePoint, Repos, BTP IS, LeanIX, chamados reais | P5 |
| Purge protection KV | desligado | ligado | descartabilidade do lab |

## 6. Estimativa de custo do lab (ordem de grandeza)

| Recurso | SKU lab | US$/mês (aprox.) |
|---|---|---|
| Service Bus Premium 1 MU | Premium | ~680 |
| App Gateway WAF_v2 (autoscale 0–2) | WAF_v2 | ~250–330 |
| AI Search | Basic | ~75 |
| APIM | Developer | ~50 |
| ACR | Premium | ~50 |
| PostgreSQL Flexible | B2s + 64 GB | ~35 |
| Bastion | Standard | ~210 |
| VM jump (desligada 12h/dia) | B2s | ~20 |
| Container Apps (consumo, mín. réplicas) | Consumption | ~80–150 |
| Cosmos DB | Serverless | ~5–20 |
| Private Endpoints (~11) + DNS | — | ~85 |
| Log Analytics / App Insights | PerGB | ~30–80 |
| Foundry (tokens) | Standard | variável (~100–400 no desenvolvimento) |
| **Total** | | **≈ US$ 1,7–2,3 mil (≈ R$ 9–13 mil)** |

Coerente com a faixa do slide 30 (R$ 7–16 mil/mês, Azure gerenciado). **Alavancas:** `scripts/start-stop-lab.sh stop` à noite/fim de semana; destruir e recriar via IaC entre sprints (≈ 50 min); trocar Service Bus Premium por Standard **apenas** se aceitarmos perder o teste de Private Endpoint (não recomendado). Validar valores na Azure Pricing Calculator antes de aprovar o budget.

## 7. Riscos do roteiro e mitigação

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Modelo desejado indisponível em **Brazil South Standard regional** ou sem cota | Média | Alto | `00-preflight.sh` no dia 1; abrir pedido de cota; lista de modelos alternativos; decisão formal com a Vale se precisar Global |
| APIs em preview (Durable Task Scheduler, networkInjections do Agent Service) mudarem | Média | Médio | api-version parametrizável; teste mensal do template; fallback DTS → Durable Functions/Service Bus |
| Policies da Vale bloquearem recursos (ex.: deny de IP público para o WAF) | Alta | Alto | Rodar `az policy assignment list` com a Vale na semana 1; pedir exemption formal (SOL-GOV-04) |
| Lead time de firewall/DNS/IAM na Vale | Alta | Alto | Enviar solicitações na **semana 1**, em paralelo com o lab (cronograma) |
| Congelamento de mudanças de fim de ano na Vale (dez/jan) | Alta | Médio | Antecipar CRs de rede para antes do freeze; usar o período para F6 no lab |
| Custo do lab acima do budget | Baixa | Baixo | Budget + alerta + start/stop |
