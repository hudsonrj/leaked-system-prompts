# Core Data Integration — Ambiente Azure HAT ⇄ Vale

Pacote para (1) construir no **nosso Azure (HAT)** um ambiente espelho da arquitetura *Core Foundation Integração Vale* e (2) a partir dele preparar **documentos, solicitações de permissão e scripts de IaC** para criar os recursos na **Vale**.

## Conteúdo

| Caminho | O que é |
|---|---|
| `docs/01-roteiro-ambiente-hat.md` | Roteiro do ambiente interno HAT: princípios, arquitetura, fases F0–F7, diferenças HAT×Vale, custos, riscos |
| `docs/02-guia-criacao-recursos.md` | Guia passo a passo de criação e verificação de cada recurso (ordem, configurações obrigatórias, conectores) |
| `docs/03-solicitacoes-permissoes-vale.md` | 34 solicitações à Vale (governança, rede, IAM, fontes, DevOps, segurança) + allow-list de firewall + zonas DNS + e-mail modelo |
| `docs/Solicitacoes_Acessos_Vale_CDI.docx` | Versão formal (Word) das solicitações, com tabela de aprovações |
| `docs/04-matriz-identidades-rbac.md` | Identidades gerenciadas, RBAC por recurso, grants no PostgreSQL, acessos às fontes |
| `docs/05-cronograma.md` | Visão executiva do cronograma, marcos, caminho crítico |
| `cronograma/Cronograma_HAT_Vale_CDI.xlsx` | **114 tarefas** categorizadas, dificuldade, esforço, duração, predecessoras, datas, Gantt, rastreio das solicitações, riscos |
| `iac/bicep/main.bicep` + `modules/` | IaC único para os dois ambientes (21 módulos) |
| `iac/bicep/params/lab.bicepparam` | Parâmetros do ambiente HAT |
| `iac/bicep/params/vale-dev.bicepparam` | Parâmetros da Vale (placeholders `<...>` = respostas das solicitações) |
| `iac/bicep/apim-policies/` | Políticas do APIM (token Entra, `x-demanda`, limites por agente, métricas de tokens, JWT do Bot) |
| `iac/scripts/` | preflight, deploy (what-if), Entra, pós-deploy (SQL/índices/RBAC), validação, start/stop, destroy |
| `iac/sql/` | Schema de registro/linhagem/matriz ICC015/changeset LeanIX + grafo Apache AGE + grants |
| `iac/search/` | Definições de `idx-codigo`, `idx-docs`, `idx-leanix` (híbrido + vetores 3072d + semantic) |
| `iac/pipelines/azure-pipelines-infra.yml` | CI/CD de infra (lint → what-if → aprovação → deploy) |
| `cronograma/fonte/` | Geradores do cronograma e das solicitações (replanejar = mudar a data de início e rodar) |

## Começo rápido (ambiente HAT)

```bash
az login && az account set -s <sub-hat-cdi-lab>
./iac/scripts/00-preflight.sh <sub-hat-cdi-lab>
./iac/scripts/03-entra-setup.sh lab          # grupos + app registrations
# preencher iac/bicep/params/lab.bicepparam (objectIds, org DevOps, chave SSH)
./iac/scripts/01-deploy.sh lab               # what-if + deploy (~60 min)
# no jump (Bastion):
./iac/scripts/02-post-deploy.sh lab
./iac/scripts/04-validate.sh lab
```

## Mapa slide → recurso

| Slide do deck | Recurso / módulo |
|---|---|
| 11 (A1), 18–23 (A2–A4) | Bot + Teams (`bot`), WAF (`appgw-waf`), APIM (`apim`), Foundry (`foundry`), runtime/artef/valid (`containerapps`) |
| 12 (Dados) | ADLS raw/gold/entregáveis (`storage`), AI Search (`search`), PostgreSQL + AGE (`postgres`, `sql/`), Cosmos (`cosmos`), identidades (`identities`, `rbac`) |
| 13, 15, 16 (RAG / grafo) | `search/*.json`, `sql/001`, jobs de ingestão, Document Intelligence (`docintel`) |
| 14 (Implementação) | Cota/métricas de tokens (`apim-policies/llm.xml`), Prompt Shields (RAI policy), tracing (App Insights) |
| 18 item 17, 20 | Durable Task Scheduler (`durabletask`) |
| 18 item 20 | Managed DevOps Pool (`devopspool`) |
| 25–26 (Rede) | VNet/subnets/NSG/UDR (`network`), Private Endpoints (`private-endpoint`), DNS (`private-dns`, `cae-dns`) |
| 27 (Ingestão de código) | Service Bus (`servicebus`), `job-ingest-codigo`, gateway LLM |
| 30 (Custos) | `docs/01 §6`, `start-stop-lab.sh` |

## Pontos a confirmar antes do primeiro deploy

- O Bicep **não foi compilado nem implantado neste ambiente de geração**: rode `az bicep build` / what-if (o `01-deploy.sh` e o pipeline fazem isso) e ajuste o que acusar.
- **api-versions mais novas** (Durable Task Scheduler, `networkInjections`/projetos do Foundry, Managed DevOps Pools): confirmar a versão vigente para Brazil South na data do deploy.
- **Modelos e versões** no `.bicepparam`: validar disponibilidade em Brazil South com SKU Standard regional (`00-preflight.sh`).
- Tamanho mínimo da `snet-aiagents` para o Agent Service com VNet própria.
