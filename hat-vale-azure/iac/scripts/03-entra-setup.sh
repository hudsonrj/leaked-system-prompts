#!/usr/bin/env bash
# =============================================================================
# 03-entra-setup.sh — objetos do Entra ID (executar no tenant alvo)
# HAT: executado pelo nosso admin. Vale: entregue ao time de IAM da Vale como
#      referência (SOL-IAM-01..05) — eles executam ou aprovam.
#   - App registration "integia-api" (audiência dos tokens; escopos p/ OBO)
#   - App registration "integia-connector" (Graph Sites.Selected — SharePoint)
#   - Grupos de segurança (engenharia, pg-admins, grupos de conhecimento)
# Uso: ./03-entra-setup.sh lab|dev
# =============================================================================
set -euo pipefail
ENV="${1:?lab|dev}"
PFX=$([[ "$ENV" == "lab" ]] && echo "hat" || echo "vale")

echo ">> Grupos"
for g in "grp-$PFX-cdi-engenharia" "grp-$PFX-cdi-pg-admins" \
         "grp-$PFX-cdi-know-integracao" "grp-$PFX-cdi-know-restrito" \
         "grp-$PFX-cdi-cci" "grp-$PFX-cdi-arquitetos" "grp-$PFX-cdi-especialistas"; do
  az ad group show -g "$g" >/dev/null 2>&1 || az ad group create --display-name "$g" --mail-nickname "$g" -o none
  echo "   - $g: $(az ad group show -g "$g" --query id -o tsv)"
done

echo ">> App: integia-api-$ENV (API protegida pelo APIM)"
API_APPID=$(az ad app list --display-name "integia-api-$ENV" --query "[0].appId" -o tsv)
if [[ -z "$API_APPID" ]]; then
  API_APPID=$(az ad app create --display-name "integia-api-$ENV" \
     --identifier-uris "api://integia-api-$ENV" --sign-in-audience AzureADMyOrg --query appId -o tsv)
  SCOPE_ID=$(cat /proc/sys/kernel/random/uuid)
  az ad app update --id "$API_APPID" --set api="{\"requestedAccessTokenVersion\":2,\"oauth2PermissionScopes\":[{\"id\":\"$SCOPE_ID\",\"adminConsentDescription\":\"Acesso do usuário às ferramentas MCP e aos agentes\",\"adminConsentDisplayName\":\"Agentes.Usar\",\"isEnabled\":true,\"type\":\"User\",\"userConsentDescription\":\"Usar agentes de integração\",\"userConsentDisplayName\":\"Agentes.Usar\",\"value\":\"Agentes.Usar\"}]}"
  # Emite grupos no token (filtro de grupos do MCP) — apenas grupos atribuídos ao app
  az ad app update --id "$API_APPID" --set groupMembershipClaims=ApplicationGroup
  az ad sp create --id "$API_APPID" -o none
fi
echo "   appId=$API_APPID"

echo ">> App: integia-connector-$ENV (ingestão SharePoint via Graph — Sites.Selected)"
CONN_APPID=$(az ad app list --display-name "integia-connector-$ENV" --query "[0].appId" -o tsv)
if [[ -z "$CONN_APPID" ]]; then
  CONN_APPID=$(az ad app create --display-name "integia-connector-$ENV" --sign-in-audience AzureADMyOrg --query appId -o tsv)
  az ad sp create --id "$CONN_APPID" -o none
  # Microsoft Graph: Sites.Selected (Application) = 883ea226-0bf2-4a8f-9f9d-92c9162a727d
  az ad app permission add --id "$CONN_APPID" --api 00000003-0000-0000-c000-000000000000 \
     --api-permissions 883ea226-0bf2-4a8f-9f9d-92c9162a727d=Role
  echo "   !! Requer ADMIN CONSENT (Global/Privileged Role Admin) e grant por site:"
  echo "      POST https://graph.microsoft.com/v1.0/sites/{site-id}/permissions  (roles: read | write na biblioteca de ICCs)"
  echo "   !! Credencial: federated credential da UAMI id-cdi-ingest (sem segredo) — ver docs/02 §7"
fi
echo "   appId=$CONN_APPID"
echo ">> Concluído. Atualize apiAudience no .bicepparam: api://integia-api-$ENV"
