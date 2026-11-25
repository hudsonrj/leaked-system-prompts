#!/usr/bin/env bash
# =============================================================================
# 00-preflight.sh — verificações antes do primeiro deploy (HAT ou Vale)
#   - login / assinatura corretos
#   - resource providers registrados
#   - disponibilidade de modelos e cota em Brazil South
#   - SKUs e zonas disponíveis
# Uso: ./00-preflight.sh <subscriptionId> [location]
# =============================================================================
set -euo pipefail
SUB="${1:?subscriptionId}"
LOC="${2:-brazilsouth}"

az account set --subscription "$SUB"
echo ">> Assinatura: $(az account show --query '{nome:name, tenant:tenantId}' -o tsv)"

PROVIDERS=(
  Microsoft.Network Microsoft.Storage Microsoft.KeyVault Microsoft.ServiceBus
  Microsoft.ContainerRegistry Microsoft.Search Microsoft.DBforPostgreSQL
  Microsoft.DocumentDB Microsoft.CognitiveServices Microsoft.ApiManagement
  Microsoft.App Microsoft.OperationalInsights Microsoft.Insights
  Microsoft.ManagedIdentity Microsoft.BotService Microsoft.DurableTask
  Microsoft.DevCenter Microsoft.DevOpsInfrastructure Microsoft.Compute
  Microsoft.DevTestLab Microsoft.AlertsManagement
)
echo ">> Registrando resource providers (idempotente)"
for p in "${PROVIDERS[@]}"; do
  state=$(az provider show -n "$p" --query registrationState -o tsv 2>/dev/null || echo "NotFound")
  if [[ "$state" != "Registered" ]]; then
    echo "   - $p ($state) → registrando"
    az provider register -n "$p" >/dev/null || echo "   ! sem permissão para registrar $p (pedir ao time de cloud)"
  else
    echo "   - $p OK"
  fi
done

echo ">> Modelos disponíveis em $LOC (SKU Standard regional)"
az cognitiveservices model list -l "$LOC" \
  --query "[?model.format=='OpenAI' && (contains(model.name,'gpt-4.1') || contains(model.name,'embedding'))].{modelo:model.name, versao:model.version, skus:join(',', model.skus[].name)}" \
  -o table || true

echo ">> Cota de modelos em $LOC"
az cognitiveservices usage list -l "$LOC" \
  --query "[?contains(name.value,'OpenAI.Standard')].{cota:name.value, uso:currentValue, limite:limit}" -o table || true

echo ">> Zonas de disponibilidade para Standard_D2ds_v5 / Standard_D2ads_v5"
az vm list-skus -l "$LOC" --size Standard_D2 --query "[?name=='Standard_D2ds_v5' || name=='Standard_D2ads_v5'].{sku:name, zonas:join(',',locationInfo[0].zones), restricoes:length(restrictions)}" -o table

echo ">> Policies atribuídas que podem bloquear o deploy (deny)"
az policy assignment list --query "[].{nome:displayName, escopo:scope}" -o table | head -40

echo ">> Preflight concluído. Revise itens marcados com '!'"
