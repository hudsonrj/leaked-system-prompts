-- =============================================================================
-- 001-schema-registro.sql — PostgreSQL Flexible "Registro e controle" + grafo AGE
-- Guarda: fontes, permissões, versões vigentes, linhagem, matriz ICC015 × código,
-- conjuntos de alterações LeanIX (slide 12). Texto/vetores ficam no AI Search;
-- Raw/Gold no ADLS.
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS age;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS registro;

-- Fontes capturadas (SharePoint, Azure Repos, BTP IS, LeanIX)
CREATE TABLE IF NOT EXISTS registro.fonte (
  fonte_id      uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo          text NOT NULL CHECK (tipo IN ('sharepoint','azure_repos','btp_is','leanix','chamados')),
  uri           text NOT NULL,
  sistema       text,
  dono          text,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tipo, uri)
);

-- Grupos Entra autorizados por fonte (filtro de grupos do MCP)
CREATE TABLE IF NOT EXISTS registro.permissao_fonte (
  fonte_id      uuid REFERENCES registro.fonte ON DELETE CASCADE,
  grupo_id      text NOT NULL,           -- objectId do grupo Entra
  PRIMARY KEY (fonte_id, grupo_id)
);

-- Versões capturadas e versão vigente
CREATE TABLE IF NOT EXISTS registro.versao (
  versao_id     uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  fonte_id      uuid NOT NULL REFERENCES registro.fonte ON DELETE CASCADE,
  ref_origem    text NOT NULL,           -- commit SHA, eTag/versionId do SharePoint, versão do iFlow
  caminho_raw   text NOT NULL,           -- abfss://raw@.../...
  hash_conteudo text NOT NULL,
  vigente       boolean NOT NULL DEFAULT false,
  capturado_em  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fonte_id, ref_origem)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_versao_vigente ON registro.versao (fonte_id) WHERE vigente;

-- Linhagem: versão → objetos derivados (chunks Gold, docs do índice, nós do grafo)
CREATE TABLE IF NOT EXISTS registro.linhagem (
  chunk_id      text PRIMARY KEY,
  versao_id     uuid NOT NULL REFERENCES registro.versao ON DELETE CASCADE,
  caminho_gold  text NOT NULL,
  indice        text NOT NULL CHECK (indice IN ('idx-codigo','idx-docs','idx-leanix')),
  linha_ini     int,
  linha_fim     int,
  simbolo       text,
  processado_em timestamptz NOT NULL DEFAULT now()
);

-- Eventos de ingestão (evento final do pipeline — slide 27)
CREATE TABLE IF NOT EXISTS registro.evento_ingestao (
  evento_id     uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  fonte_id      uuid REFERENCES registro.fonte,
  versao_id     uuid REFERENCES registro.versao,
  status        text NOT NULL CHECK (status IN ('iniciado','concluido','falhou')),
  detalhes      jsonb,
  ocorrido_em   timestamptz NOT NULL DEFAULT now()
);

-- Matriz de reconciliação ICC015 × código (A2)
CREATE TABLE IF NOT EXISTS registro.matriz_icc015 (
  matriz_id     uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  interface_id  text NOT NULL,           -- ex.: IF-0420
  item_doc      text NOT NULL,
  evidencia     text,                    -- chunk_id
  situacao      text NOT NULL CHECK (situacao IN ('coberto','divergente','ausente_no_documento','ausente_no_codigo')),
  demanda       text NOT NULL,           -- x-demanda / work item do Boards
  status        text NOT NULL DEFAULT 'proposto' CHECK (status IN ('proposto','aprovado','rejeitado')),
  aprovado_por  text,
  aprovado_em   timestamptz,
  criado_em     timestamptz NOT NULL DEFAULT now()
);

-- Conjunto de alterações LeanIX (A4) — aplicado só após aprovação do CCI
CREATE TABLE IF NOT EXISTS registro.leanix_changeset (
  changeset_id  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  demanda       text NOT NULL,
  proposta      jsonb NOT NULL,          -- mutations GraphQL propostas
  divergencias  jsonb,
  status        text NOT NULL DEFAULT 'proposto' CHECK (status IN ('proposto','aprovado','aplicado','rejeitado')),
  aprovado_por  text,
  aplicado_em   timestamptz,
  criado_em     timestamptz NOT NULL DEFAULT now()
);

-- Artefatos publicados (ICC010/ICC015 Gold/deltas)
CREATE TABLE IF NOT EXISTS registro.artefato (
  artefato_id   uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo          text NOT NULL CHECK (tipo IN ('ICC010','ICC015_GOLD','ICC015_DELTA','PLANO','PATCH','DIAGNOSTICO')),
  demanda       text NOT NULL,
  versao        int NOT NULL DEFAULT 1,
  estado        text NOT NULL CHECK (estado IN ('rascunho','em_validacao','aprovado','publicado')),
  caminho       text NOT NULL,           -- abfss://entregaveis@... ou URL SharePoint
  criado_em     timestamptz NOT NULL DEFAULT now()
);

-- ---------- Grafo de interações (Apache AGE) ----------
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ag_catalog.ag_graph WHERE name = 'cdi_grafo') THEN
    PERFORM ag_catalog.create_graph('cdi_grafo');
  END IF;
END $$;
-- Rótulos: Aplicacao, Interface, Documento, IFlow, Artefato, Simbolo
-- Arestas: ORIGEM, DESTINO, DESCREVE, IMPLEMENTA, CHAMA, DEFINE, USA
-- Cada nó carrega {id, chunk_id, grupos:[...], versao_id}
DO $$
DECLARE l text;
BEGIN
  FOREACH l IN ARRAY ARRAY['Aplicacao','Interface','Documento','IFlow','Artefato','Simbolo'] LOOP
    IF NOT EXISTS (SELECT 1 FROM ag_catalog.ag_label WHERE name = l) THEN
      PERFORM ag_catalog.create_vlabel('cdi_grafo', l);
    END IF;
  END LOOP;
  FOREACH l IN ARRAY ARRAY['ORIGEM','DESTINO','DESCREVE','IMPLEMENTA','CHAMA','DEFINE','USA'] LOOP
    IF NOT EXISTS (SELECT 1 FROM ag_catalog.ag_label WHERE name = l) THEN
      PERFORM ag_catalog.create_elabel('cdi_grafo', l);
    END IF;
  END LOOP;
END $$;
