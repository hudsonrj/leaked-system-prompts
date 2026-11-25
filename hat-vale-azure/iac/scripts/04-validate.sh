#!/usr/bin/env bash
# =============================================================================
# 04-validate.sh — testes de aceite da infraestrutura (executar DENTRO da VNet)
# Gera relatório usado como evidência no ACEITE 02 (Base pronta para construir)
# =============================================================================
set -uo pipefail
TARGET="${1:?lab|vale-dev}"
case "$TARGET" in lab) RG="rg-integia-lab-brs";; vale-dev) RG="rg-integia-dev-brs";; esac
REPORT="validacao-$TARGET-$(date +%Y%m%d-%H%M).md"
pass=0; fail=0
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "| ✅ | $desc |" >>"$REPORT"; ((pass++)); else echo "| ❌ | $desc |" >>"$REPORT"; ((fail++)); fi; }
priv_ip() { local ip; ip=$(getent hosts "$1" | awk '{print $1}' | head -1); [[ "$ip" =~ ^10\.|^172\.(1[6-9]|2[0-9]|3[01])\.|^192\.168\. ]]; }

echo "# Validação de infraestrutura — $TARGET — $(date)" >"$REPORT"
echo "| Status | Verificação |" >>"$REPORT"; echo "|---|---|" >>"$REPORT"

# 1) Nenhum PaaS com acesso público
for t in Microsoft.Storage/storageAccounts Microsoft.KeyVault/vaults Microsoft.Search/searchServices \
         Microsoft.ServiceBus/namespaces Microsoft.ContainerRegistry/registries Microsoft.DocumentDB/databaseAccounts \
         Microsoft.CognitiveServices/accounts; do
  for id in $(az resource list -g "$RG" --resource-type "$t" --query "[].id" -o tsv); do
    pna=$(az resource show --ids "$id" --query "properties.publicNetworkAccess" -o tsv 2>/dev/null)
    check "Acesso público desabilitado: $(basename "$id") ($pna)" test "${pna,,}" = "disabled"
  done
done

# 2) Resolução DNS privada dos endpoints
for host in $(az network private-endpoint list -g "$RG" --query "[].customDnsConfigs[].fqdn" -o tsv); do
  check "DNS privado: $host" priv_ip "$host"
done
PG=$(az postgres flexible-server list -g "$RG" --query "[0].fullyQualifiedDomainName" -o tsv)
check "DNS privado: $PG" priv_ip "$PG"

# 3) Conectividade de dados
check "PostgreSQL aceita token Entra" bash -c "PGPASSWORD=\$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv) psql \"host=$PG dbname=cdi user=\${PGUSER:-\$(az ad signed-in-user show --query userPrincipalName -o tsv)} sslmode=require\" -c 'select 1' "
check "Extensão AGE instalada" bash -c "PGPASSWORD=\$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv) psql \"host=$PG dbname=cdi user=\${PGUSER:-\$(az ad signed-in-user show --query userPrincipalName -o tsv)} sslmode=require\" -tAc \"select 1 from pg_extension where extname='age'\" | grep -q 1"

SEARCH=$(az search service list -g "$RG" --query "[0].name" -o tsv)
TOKEN=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)
for idx in idx-codigo idx-docs idx-leanix; do
  check "AI Search índice $idx" curl -sf "https://$SEARCH.search.windows.net/indexes/$idx?api-version=2024-07-01" -H "Authorization: Bearer $TOKEN"
done

# 4) APIM interno e apps
APIM=$(az apim list -g "$RG" --query "[0].name" -o tsv)
check "APIM resolve para IP privado" priv_ip "$APIM.azure-api.net"
check "APIM status endpoint" curl -sfk "https://$APIM.azure-api.net/status-0123456789abcdef"
check "MCP exige token (401 sem Authorization)" bash -c "[[ \$(curl -sk -o /dev/null -w '%{http_code}' https://$APIM.azure-api.net/mcp/) == 401 ]]"

# 5) Modelos
AIF=$(az cognitiveservices account list -g "$RG" --query "[?kind=='AIServices'].name | [0]" -o tsv)
for d in $(az cognitiveservices account deployment list -g "$RG" -n "$AIF" --query "[].name" -o tsv); do
  st=$(az cognitiveservices account deployment show -g "$RG" -n "$AIF" --deployment-name "$d" --query properties.provisioningState -o tsv)
  check "Deployment de modelo $d ($st)" test "$st" = "Succeeded"
done

echo "" >>"$REPORT"; echo "**Resultado:** $pass OK / $fail falhas" >>"$REPORT"
cat "$REPORT"
[[ $fail -eq 0 ]]
