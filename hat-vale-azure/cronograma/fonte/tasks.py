# (id, categoria, tarefa, descricao/entregavel, responsavel, dificuldade, esforco_dp, duracao_du, predecessoras)
T = [
("A01","A. Governança e mobilização","Kick-off interno e RACI do time","Definir papéis (GP, Arquiteto Cloud, Eng. Cloud/DevOps, Eng. Dados/IA), RACI e canais. Entregável: RACI aprovado.","GP HAT","Baixa",1,1,[]),
("A02","A. Governança e mobilização","Decisões de arquitetura (ADRs)","ADRs: região única Brazil South, Bicep como IaC, SKUs lab×Vale, modelo de acesso, WAF próprio×corporativo, modelos de LLM. Entregável: ADR-001..006.","Arquiteto Cloud HAT","Média",2,2,["A01"]),
("A03","A. Governança e mobilização","Ritos e plano de comunicação","Daily do time, semanal tática, comitê mensal (slide 31). Entregável: agenda recorrente.","GP HAT","Baixa",1,1,["A01"]),
("A04","A. Governança e mobilização","Alinhamento com Vale: escopo do ambiente e pontos focais","Reunião com Integração, Cloud CoE, Rede, IAM e Segurança. Entregável: ata + lista de pontos focais.","Conjunto","Média",1,1,["A02"]),
("A05","A. Governança e mobilização","Obter calendário de mudanças/freeze (SOL-OPS-01)","Janelas de CR, freeze de fim de ano. Entregável: calendário incorporado ao cronograma.","Vale","Baixa",0.5,3,["A04"]),

("B01","B. HAT F0 — Fundação","Management group e assinatura sub-hat-cdi-lab","Criar MG mg-hat-labs e assinatura dedicada. Entregável: assinatura ativa.","Eng. Cloud HAT","Baixa",0.5,1,["A02"]),
("B02","B. HAT F0 — Fundação","Budget, alertas e tags","Budget R$ 15 mil/mês, alertas 50/80/100%, tags obrigatórias.","Eng. Cloud HAT","Baixa",0.5,1,["B01"]),
("B03","B. HAT F0 — Fundação","Grupos Entra e app registrations (lab)","Executar 03-entra-setup.sh lab: grupos, integia-api-lab (escopo, groups claim), integia-connector-lab.","Eng. Cloud HAT","Média",1,1,["B01"]),
("B04","B. HAT F0 — Fundação","Azure DevOps: projeto cdi-lab e repositório","Repositório deste pacote, branch policies (PR + build).","Eng. DevOps HAT","Baixa",0.5,1,["B01"]),
("B05","B. HAT F0 — Fundação","Service connection WIF + environment com aprovação","Service connection ARM com Workload Identity Federation; environment hat-lab com aprovação.","Eng. DevOps HAT","Média",1,1,["B04"]),
("B06","B. HAT F0 — Fundação","Preflight: providers, cota de modelos, policies","00-preflight.sh: registra providers, lista modelos/cota em Brazil South, policies.","Eng. Cloud HAT","Média",1,1,["B01"]),
("B07","B. HAT F0 — Fundação","Aumento de cota de modelos (se necessário)","Pedido de cota Standard regional Brazil South para chat e embeddings.","Eng. Dados/IA HAT","Média",0.5,5,["B06"]),
("B08","B. HAT F0 — Fundação","Domínio e certificado TLS do host público do Bot","cdi-bot-lab.<domínio HAT>, certificado PFX para o App Gateway.","Eng. Cloud HAT","Baixa",0.5,3,["B01"]),

("C01","C. HAT F1 — Rede e DNS","Plano de endereçamento (lab e proposta Vale)","/22 com 7 subnets + delegações; mesma topologia proposta para a Vale (SOL-NET-01).","Arquiteto Cloud HAT","Média",1,1,["A02"]),
("C02","C. HAT F1 — Rede e DNS","Deploy rede, NSGs e DNS privado","Módulos network + private-dns via pipeline (what-if + aprovação).","Eng. Cloud HAT","Média",1,1,["C01","B05"]),
("C03","C. HAT F1 — Rede e DNS","Bastion + VM jump com login Entra","bastion-jump.bicep; auto-shutdown 20h.","Eng. Cloud HAT","Baixa",0.5,1,["C02"]),
("C04","C. HAT F1 — Rede e DNS","Testes de DNS e NSG","Resolução privatelink.* → 10.x a partir do jump; regras NSG do APIM.","Eng. Cloud HAT","Média",0.5,1,["C03"]),

("D01","D. HAT F2 — Dados e segurança","Managed identities + Log Analytics/App Insights","8 UAMIs id-cdi-*; workspace e App Insights.","Eng. Cloud HAT","Baixa",0.5,1,["C02"]),
("D02","D. HAT F2 — Dados e segurança","Key Vault, ACR Premium, Service Bus Premium + PEs","Sem acesso público, sem chaves locais, filas de ingestão.","Eng. Cloud HAT","Média",1,1,["D01"]),
("D03","D. HAT F2 — Dados e segurança","ADLS Gen2 (raw/gold/entregáveis) + storage do Agent Service + PEs","HNS, shared key off, ZRS, PEs blob+dfs.","Eng. Dados/IA HAT","Média",1,1,["D01"]),
("D04","D. HAT F2 — Dados e segurança","Azure AI Search + PE","Entra-only, semantic ranker, público off.","Eng. Dados/IA HAT","Média",0.5,1,["D01"]),
("D05","D. HAT F2 — Dados e segurança","PostgreSQL Flexible VNet-integrado com AGE","Entra-only, extensões AGE/vector, admin por grupo.","Eng. Dados/IA HAT","Alta",1.5,2,["C02","D01"]),
("D06","D. HAT F2 — Dados e segurança","Cosmos DB serverless + PE","Threads do Agent Service; disableLocalAuth.","Eng. Dados/IA HAT","Baixa",0.5,1,["D01"]),
("D07","D. HAT F2 — Dados e segurança","Matriz RBAC (rbac.bicep) e revisão de menor privilégio","Atribuições por container/índice/fila; revisão 4 olhos.","Arquiteto Cloud HAT","Alta",1.5,2,["D02","D03","D04","D06"]),
("D08","D. HAT F2 — Dados e segurança","Pós-deploy de dados: schema, grafo AGE, principals, grants","001/002 SQL; pgaadauth_create_principal por identidade.","Eng. Dados/IA HAT","Alta",1.5,2,["D05","D07","C03"]),
("D09","D. HAT F2 — Dados e segurança","Criação dos índices idx-codigo/idx-docs/idx-leanix","Vetores 3072d, BM25 com peso em símbolo/assinatura, semantic config.","Eng. Dados/IA HAT","Média",1,1,["D04","C03"]),
("D10","D. HAT F2 — Dados e segurança","Validação blocos 1–3 (04-validate.sh)","Público off, DNS privado, conectividade de dados.","Eng. Cloud HAT","Média",0.5,1,["D08","D09"]),

("E01","E. HAT F3 — IA / Foundry","Conta Foundry (AIServices) com network injection + PE","allowProjectManagement, disableLocalAuth, snet-aiagents.","Eng. Dados/IA HAT","Alta",1,2,["C02","D02"]),
("E02","E. HAT F3 — IA / Foundry","Deployments de modelo (chat, mini, embeddings)","SKU Standard regional; versão fixa, sem auto-upgrade.","Eng. Dados/IA HAT","Média",0.5,1,["E01","B07"]),
("E03","E. HAT F3 — IA / Foundry","Projeto Foundry + conexões (Cosmos, Storage, Search, App Insights)","Conexões AAD; tracing ligado.","Eng. Dados/IA HAT","Alta",1,1,["E01","D03","D04","D06"]),
("E04","E. HAT F3 — IA / Foundry","Standard agent setup: RBAC do projeto + Capability Host + Cosmos data plane","Ordem crítica: RBAC → caphost → sqlRoleAssignment.","Eng. Dados/IA HAT","Muito alta",2,2,["E03","D07"]),
("E05","E. HAT F3 — IA / Foundry","Document Intelligence + teste prebuilt-layout → Markdown","Conversão de ICC de exemplo; avaliação de qualidade de seções.","Eng. Dados/IA HAT","Média",0.5,1,["D01"]),
("E06","E. HAT F3 — IA / Foundry","Guardrails e avaliação baseline","RAI policy / Prompt Shields; conjunto inicial de avaliação por agente.","Eng. Dados/IA HAT","Média",1,1,["E02"]),
("E07","E. HAT F3 — IA / Foundry","Smoke test: agente via Agent Service a partir da VNet","Criar agente, thread e run; trace no App Insights.","Eng. Dados/IA HAT","Média",0.5,1,["E04","E06"]),

("F01","F. HAT F4 — Gateway e compute","Container Apps Environment interno + apps + jobs","5 apps com UAMI própria, 3 jobs (evento SB, agendado, manual).","Eng. Cloud HAT","Alta",1.5,2,["D02","C02"]),
("F03","F. HAT F4 — Gateway e compute","APIM interno (Developer) + logger","Deploy ~45 min; NSG; App Insights logger.","Eng. Cloud HAT","Alta",1,2,["C02","D01"]),
("F02","F. HAT F4 — Gateway e compute","DNS privado do CAE e do APIM","Zona defaultDomain (*), zona azure-api.net.","Eng. Cloud HAT","Média",0.5,1,["F01","F03"]),
("F04","F. HAT F4 — Gateway e compute","Políticas APIM (token, x-demanda, rate/token limit, métricas)","mcp.xml, llm.xml, bot.xml; testes 401/400/200.","Arquiteto Cloud HAT","Alta",1.5,2,["F03","B03"]),
("F05","F. HAT F4 — Gateway e compute","Durable Task Scheduler + task hub + role","Confirmar GA/api-version; role para id-cdi-orch.","Eng. Dados/IA HAT","Média",0.5,1,["D01"]),
("F06","F. HAT F4 — Gateway e compute","App Gateway WAF_v2 + regra custom + certificado","Somente /bot/api/messages; DRS 2.1 Prevention.","Eng. Cloud HAT","Alta",1.5,2,["F03","B08","D02"]),
("F07","F. HAT F4 — Gateway e compute","Azure Bot (UserAssignedMSI) + canal Teams + app manifest","Publicação no tenant HAT para teste.","Eng. Dados/IA HAT","Média",1,2,["F06"]),
("F08","F. HAT F4 — Gateway e compute","Teste ponta a ponta Teams → WAF → APIM → runtime","JWT do Bot validado; resposta ao usuário.","Conjunto HAT","Alta",1,1,["F07","F02","F04"]),

("G01","G. HAT F5 — CI/CD e observabilidade","Pipeline de infraestrutura (lint, what-if, aprovação, deploy)","azure-pipelines-infra.yml parametrizado lab/vale-dev.","Eng. DevOps HAT","Média",1,2,["B05","C02"]),
("G02","G. HAT F5 — CI/CD e observabilidade","Managed DevOps Pool na snet-agents","Permissões do SP DevOpsInfrastructure; job de teste privado.","Eng. DevOps HAT","Alta",1,1,["G01"]),
("G03","G. HAT F5 — CI/CD e observabilidade","Pipeline de aplicação (imagens → ACR privado → revisão CA)","Build no pool, push ACR por PE, update de revisão.","Eng. DevOps HAT","Alta",2,3,["G02","F01"]),
("G04","G. HAT F5 — CI/CD e observabilidade","Workbook Control Board (tokens por agente/demanda, saúde, custo)","Métricas cdi-llm, App Insights, Cost Management.","Eng. Dados/IA HAT","Média",1.5,2,["F04","E02"]),
("G05","G. HAT F5 — CI/CD e observabilidade","Alertas operacionais","Falha de ingestão, 5xx APIM, cota de tokens, budget.","Eng. Cloud HAT","Média",1,1,["G04"]),
("G06","G. HAT F5 — CI/CD e observabilidade","Teste de recriação total via pipeline","destroy + deploy; medir tempo e passos manuais restantes.","Eng. Cloud HAT","Média",1,1,["G01","D10","F08"]),

("H01","H. HAT F6 — Prova técnica","Corpus sintético","10 ICC010, 10 ICC015, 5 iFlows + Groovy, export LeanIX sandbox — sem dados Vale.","Eng. Dados/IA HAT","Média",2,3,["A02"]),
("H02","H. HAT F6 — Prova técnica","Ingestão de código ponta a ponta","Service hook → SB → job: diff, tree-sitter/.iflw, corte por símbolo, resumo, embeddings, MergeOrUpload, linhagem, evento final.","Eng. Dados/IA HAT","Muito alta",5,5,["H01","D10","E02","F01"]),
("H03","H. HAT F6 — Prova técnica","Ingestão de documentos ponta a ponta","Graph delta → Raw → prebuilt-layout → corte por seção → metadados → idx-docs.","Eng. Dados/IA HAT","Alta",3,4,["H01","E05","D10"]),
("H04","H. HAT F6 — Prova técnica","Grafo de interações (AGE)","Nós Aplicação/Interface/Documento/iFlow/Artefato/Símbolo e arestas com chunk_id e grupos.","Eng. Dados/IA HAT","Alta",2,3,["H02","H03"]),
("H05","H. HAT F6 — Prova técnica","MCP de conhecimento com filtro de grupos","buscar_codigo, ler_trecho, buscar_documentos, mapear_impacto; RRF + semantic ranker; expansão de 1 salto.","Arquiteto Cloud HAT","Muito alta",4,5,["H04","F04"]),
("H06","H. HAT F6 — Prova técnica","A2 em modo matriz ICC015 × código (piloto técnico)","Matriz com citações (fonte, caminho, linhas, versão, chunk_id).","Eng. Dados/IA HAT","Alta",3,4,["H05","E07"]),
("H07","H. HAT F6 — Prova técnica","Testes de segurança de recuperação","Usuário sem grupo = zero resultados; prompt injection em documento não vira instrução.","Arquiteto Cloud HAT","Alta",1.5,2,["H05"]),

("I01","I. Documentação e pacote Vale","Roteiro e arquitetura (docs/01)","Versão 1 já elaborada; atualizar com ADRs.","Arquiteto Cloud HAT","Média",1,2,["A02"]),
("I03","I. Documentação e pacote Vale","Catálogo de solicitações + .docx (docs/03)","34 solicitações com justificativa, lead time e critério de pronto.","Arquiteto Cloud HAT","Média",1.5,2,["A04"]),
("I02","I. Documentação e pacote Vale","Guia de criação de recursos (docs/02) — revisão final","Incorporar lições do lab (F1–F4).","Eng. Cloud HAT","Média",1.5,2,["F08"]),
("I04","I. Documentação e pacote Vale","Matriz identidades/RBAC (docs/04) — revisão final","Conferir com o rbac.bicep implantado.","Arquiteto Cloud HAT","Média",1,1,["D07"]),
("I06","I. Documentação e pacote Vale","Runbook de operação","Start/stop, rotação de segredos (BTP/LeanIX), troubleshooting de DNS/PE, DR, reindexação a partir do Gold.","Eng. Cloud HAT","Média",2,3,["G06"]),
("I07","I. Documentação e pacote Vale","Relatório de evidências do lab","04-validate, what-if, testes E2E e de segurança.","Arquiteto Cloud HAT","Baixa",1,1,["G06","H07"]),
]

# Solicitações Vale como tarefas (lead time = duração); dificuldade do ponto de vista do processo Vale
SOL_DIFF = {"SOL-GOV-01":"Média","SOL-GOV-02":"Alta","SOL-GOV-03":"Baixa","SOL-GOV-04":"Alta","SOL-GOV-05":"Média","SOL-GOV-06":"Baixa",
"SOL-NET-01":"Média","SOL-NET-02":"Média","SOL-NET-03":"Alta","SOL-NET-04":"Alta","SOL-NET-05":"Média","SOL-NET-06":"Muito alta","SOL-NET-07":"Média",
"SOL-IAM-01":"Média","SOL-IAM-02":"Baixa","SOL-IAM-03":"Alta","SOL-IAM-04":"Média","SOL-IAM-05":"Média","SOL-IAM-06":"Média",
"SOL-DAT-01":"Média","SOL-DAT-02":"Média","SOL-DAT-03":"Alta","SOL-DAT-04":"Média","SOL-DAT-05":"Média","SOL-DAT-06":"Alta",
"SOL-DEV-01":"Baixa","SOL-DEV-02":"Média","SOL-DEV-03":"Média","SOL-SEG-01":"Alta","SOL-SEG-02":"Alta","SOL-SEG-03":"Média","SOL-SEG-04":"Média",
"SOL-OPS-01":"Baixa","SOL-OPS-02":"Baixa"}
SOL_PRED = {"SOL-NET-02":["SOL-NET-01"],"SOL-NET-04":["SOL-NET-01"],"SOL-NET-05":["SOL-NET-01"],"SOL-DEV-03":["SOL-DEV-02"],
            "SOL-SEG-01":["G06"],"SOL-SEG-04":["K08"],"SOL-OPS-02":["K12"],"SOL-IAM-06":["SOL-IAM-01"]}

T2 = [
("J00","J. Solicitações Vale","Envio do pacote de solicitações (v1) e abertura dos chamados","E-mail + .docx + chamados por área com IDs SOL-*.","GP HAT","Baixa",0.5,1,["I03","A04"]),
]
T3 = [
("I05","I. Documentação e pacote Vale","Preencher vale-dev.bicepparam com as respostas","Faixas, IP do firewall, DNS, objectIds, domínio do Bot.","Eng. Cloud HAT","Média",1,1,["SOL-NET-01","SOL-IAM-02","SOL-NET-03","SOL-NET-04"]),
("I08","I. Documentação e pacote Vale","Revisão interna (4 olhos) e envio do pacote final","IaC + docs + evidências para ARB.","Arquiteto Cloud HAT","Média",1,1,["I05","I06","I07","I02","I04"]),

("K01","K. Implantação Vale (dev)","Sessão técnica com Rede/DNS, IAM e Cloud CoE","Walkthrough do pacote; esclarecimento das solicitações.","Conjunto","Média",1,1,["J00"]),
("K02","K. Implantação Vale (dev)","Preflight na assinatura Vale","Providers, cota, policies (00-preflight.sh).","Conjunto","Média",0.5,1,["SOL-GOV-01","SOL-GOV-02","SOL-GOV-03"]),
("K03","K. Implantação Vale (dev)","What-if na Vale e tratamento de policies","Rodar pipeline em modo validate; ajustes/exemptions. Requer parecer do ARB (SOL-SEG-01).","Conjunto","Alta",1.5,3,["K02","SOL-GOV-04","SOL-DEV-02","I05","SOL-SEG-01"]),
("K04","K. Implantação Vale (dev)","Deploy 1: rede (subnets/NSG/UDR), identidades, monitor","Somente se a spoke for criada pelo IaC; senão apenas subnets.","Eng. Cloud HAT","Média",0.5,1,["K03","SOL-NET-02"]),
("K05","K. Implantação Vale (dev)","Deploy 2: PaaS de dados + Private Endpoints + DNS do hub","KV, ADLS, SB, ACR, Search, Cosmos, DI, PostgreSQL.","Eng. Cloud HAT","Alta",1,2,["K04","SOL-NET-04","SOL-NET-05"]),
("K06","K. Implantação Vale (dev)","Deploy 3: Foundry + Agent Service + RBAC","Conta, deployments, projeto, conexões, caphost.","Eng. Dados/IA HAT","Muito alta",1.5,2,["K05","SOL-GOV-05"]),
("K07","K. Implantação Vale (dev)","Deploy 4: Container Apps + APIM + DTS + Managed DevOps Pool","Inclui políticas APIM e DNS do CAE/APIM no hub.","Eng. Cloud HAT","Alta",1.5,3,["K06","SOL-DEV-03","SOL-NET-03"]),
("K08","K. Implantação Vale (dev)","Deploy 5: WAF / Bot / Teams","Ou integração com WAF corporativo.","Conjunto","Alta",1,2,["K07","SOL-NET-06","SOL-IAM-06"]),
("K09","K. Implantação Vale (dev)","Pós-deploy de data plane via Managed DevOps Pool","SQL, índices, Cosmos, DTS.","Eng. Dados/IA HAT","Alta",1,1,["K07"]),
("K10","K. Implantação Vale (dev)","Configuração dos conectores reais","Graph Sites.Selected, service hook DevOps, BTP IS, LeanIX, chamados.","Eng. Dados/IA HAT","Alta",3,4,["K09","SOL-IAM-03","SOL-DAT-02","SOL-DAT-03","SOL-DAT-04","SOL-NET-07"]),
("K11","K. Implantação Vale (dev)","Primeira ingestão real controlada (escopo piloto)","Interfaces do piloto; checagem de grupos e linhagem.","Eng. Dados/IA HAT","Alta",2,3,["K10","SOL-DAT-01","SOL-DAT-06"]),
("K12","K. Implantação Vale (dev)","Validação 04-validate + evidências na Vale","Relatório anexado ao aceite.","Eng. Cloud HAT","Média",0.5,1,["K09"]),

("L01","L. Aceites e handover","MARCO · ACEITE 01 — Arquitetura e plano de execução","Blueprint, backlog 1ª onda, ambiente HAT validado e pacote de solicitações enviado (slide 33).","Conjunto","Média",0,0,["I01","I04","K01","G06"]),
("L02","L. Aceites e handover","MARCO · ACEITE 02 — Base pronta para construir","Foundation MVP no ambiente Vale com evidências.","Conjunto","Alta",0,0,["K11","K12","K08"]),
("L03","L. Aceites e handover","Transferência de conhecimento IaC/operação (2 workshops)","Time Vale opera pipeline, runbook e start/stop/reindexação.","Arquiteto Cloud HAT","Média",2,3,["L02"]),
("L04","L. Aceites e handover","Preparar promoção QA/PRD (params, SKUs, HA)","APIM Premium, PG HA zonal, Search S1×2 réplicas; CRs.","Arquiteto Cloud HAT","Alta",2,3,["L02"]),
]
