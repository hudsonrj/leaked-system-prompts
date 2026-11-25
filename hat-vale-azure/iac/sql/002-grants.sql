-- =============================================================================
-- 002-grants.sql — privilégios por identidade (espelha a tabela Grava/Lê, slide 12)
-- Variável psql :envsfx = lab | dev
-- =============================================================================
\set artef  '"id-cdi-artef-' :envsfx '"'
\set ingest '"id-cdi-ingest-' :envsfx '"'
\set mcp    '"id-cdi-mcp-' :envsfx '"'
\set valid  '"id-cdi-valid-' :envsfx '"'
\set orch   '"id-cdi-orch-' :envsfx '"'

GRANT USAGE ON SCHEMA registro TO :ingest, :artef, :mcp, :valid, :orch;
GRANT USAGE ON SCHEMA ag_catalog TO :ingest, :mcp, :valid, :artef;

-- Ingestão: grava fontes, versões, linhagem, eventos e grafo
GRANT SELECT, INSERT, UPDATE ON registro.fonte, registro.permissao_fonte, registro.versao,
      registro.linhagem, registro.evento_ingestao TO :ingest;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA cdi_grafo TO :ingest;

-- Artefatos: grava matriz, changeset LeanIX e artefatos
GRANT SELECT, INSERT, UPDATE ON registro.matriz_icc015, registro.leanix_changeset, registro.artefato TO :artef;
GRANT SELECT ON registro.fonte, registro.versao, registro.linhagem TO :artef;

-- MCP e validadores: somente leitura
GRANT SELECT ON ALL TABLES IN SCHEMA registro TO :mcp, :valid;
GRANT SELECT ON ALL TABLES IN SCHEMA cdi_grafo TO :mcp, :valid;

-- Orquestrador: lê estado de aprovação
GRANT SELECT ON registro.matriz_icc015, registro.leanix_changeset, registro.artefato TO :orch;
