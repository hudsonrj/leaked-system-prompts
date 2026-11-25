#!/usr/bin/env bash
# =============================================================================
# 01-deploy.sh — cria o RG, roda what-if e implanta o main.bicep
# Uso: ./01-deploy.sh lab|vale-dev [--yes]
#   lab      → rg-integia-lab-brs   (assinatura HAT)
#   vale-dev → rg-integia-dev-brs   (assinatura Vale; normalmente via pipeline)
# =============================================================================
set -euo pipefail
TARGET="${1:?lab|vale-dev}"
AUTO="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BICEP_DIR="$HERE/../bicep"
LOC="brazilsouth"

case "$TARGET" in
  lab)      RG="rg-integia-lab-brs"; PARAMS="$BICEP_DIR/params/lab.bicepparam" ;;
  vale-dev) RG="rg-integia-dev-brs"; PARAMS="$BICEP_DIR/params/vale-dev.bicepparam" ;;
  *) echo "alvo inválido"; exit 1 ;;
esac

if grep -qE '<|10\.X' "$PARAMS"; then
  echo "!! Existem placeholders em $PARAMS:"; grep -nE '<|10\.X' "$PARAMS"; exit 2
fi

echo ">> Assinatura atual: $(az account show --query name -o tsv)"
az group create -n "$RG" -l "$LOC" --tags workload=core-data-integration managed-by=bicep >/dev/null

echo ">> Lint/build"
az bicep build --file "$BICEP_DIR/main.bicep" --stdout >/dev/null

DEPLOY_NAME="cdi-$(date +%Y%m%d-%H%M%S)"
echo ">> What-if ($DEPLOY_NAME)"
az deployment group what-if -g "$RG" -n "$DEPLOY_NAME" --parameters "$PARAMS" --result-format FullResourcePayloads

if [[ "$AUTO" != "--yes" ]]; then
  read -r -p "Aplicar? (s/N) " ok; [[ "$ok" == "s" ]] || exit 0
fi

az deployment group create -g "$RG" -n "$DEPLOY_NAME" --parameters "$PARAMS" -o none
az deployment group show -g "$RG" -n "$DEPLOY_NAME" --query properties.outputs > "$HERE/outputs-$TARGET.json"
echo ">> Deploy concluído. Outputs em $HERE/outputs-$TARGET.json"
echo ">> Próximo passo: ./02-post-deploy.sh $TARGET (executar de dentro da VNet: jump/Bastion ou Managed DevOps Pool)"
