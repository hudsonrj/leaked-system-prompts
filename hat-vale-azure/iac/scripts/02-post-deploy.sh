#!/usr/bin/env bash
# =============================================================================
# 02-post-deploy.sh — passos de data plane (executar DENTRO da VNet)
#   1. Roles por nome (Durable Task) e Cosmos data plane para o projeto Foundry
#   2. Banco: extensões AGE/vector, schema de registro e principals Entra
#   3. Índices do AI Search (idx-codigo, idx-docs, idx-leanix)
# Uso: ./02-post-deploy.sh lab|vale-dev
# Requer: az, jq, psql, curl. Login com conta do grupo de engenharia/pg-admins.
# =============================================================================
set -euo pipefail
TARGET="${1:?lab|vale-dev}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/outputs-$TARGET.json"
case "$TARGET" in lab) RG="rg-integia-lab-brs";; vale-dev) RG="rg-integia-dev-brs";; esac
j() { jq -r "$1" "$OUT"; }

# ---------- 1. RBAC complementar ----------
DTS_ID=$(j '.dtsId.value')
ORCH_PID=$(j '.identities.value.orch.principalId')
echo ">> Durable Task Data Contributor → id-cdi-orch"
az role assignment create --assignee-object-id "$ORCH_PID" --assignee-principal-type ServicePrincipal \
  --role "Durable Task Data Contributor" --scope "$DTS_ID" -o none || echo "   ! verificar nome da role no tenant"

COSMOS=$(j '.cosmosName.value')
PROJ_PID=$(j '.foundryProjectPrincipalId.value')
echo ">> Cosmos DB Built-in Data Contributor → projeto Foundry (threads do Agent Service)"
az cosmosdb sql role assignment create -g "$RG" -a "$COSMOS" \
  --role-definition-id 00000000-0000-0000-0000-000000000002 \
  --principal-id "$PROJ_PID" --scope "/" -o none || true

# ---------- 2. PostgreSQL ----------
PGHOST=$(j '.postgresFqdn.value')
export PGPASSWORD
PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
PGUSER=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "${PGUSER:?defina PGUSER = nome do grupo admin}")
echo ">> Aplicando schema em $PGHOST"
psql "host=$PGHOST dbname=cdi user=$PGUSER sslmode=require" -v ON_ERROR_STOP=1 -f "$HERE/../sql/001-schema-registro.sql"

for k in artef ingest mcp valid orch; do
  NAME=$(j ".identities.value.$k.name")
  echo "   - principal $NAME"
  psql "host=$PGHOST dbname=postgres user=$PGUSER sslmode=require" -v ON_ERROR_STOP=0 \
    -c "select * from pgaadauth_create_principal('$NAME', false, false);" || true
done
psql "host=$PGHOST dbname=cdi user=$PGUSER sslmode=require" -v ON_ERROR_STOP=1 \
  -v envsfx="$( [[ $TARGET == lab ]] && echo lab || echo dev )" -f "$HERE/../sql/002-grants.sql"

# ---------- 3. AI Search ----------
SEARCH=$(j '.searchEndpoint.value')
TOKEN=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)
for idx in idx-codigo idx-docs idx-leanix; do
  echo ">> Índice $idx"
  curl -sS -X PUT "$SEARCH/indexes/$idx?api-version=2024-07-01" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    --data @"$HERE/../search/$idx.json" -o /dev/null -w "   HTTP %{http_code}\n"
done

echo ">> Pós-deploy concluído. Rode ./04-validate.sh $TARGET"
