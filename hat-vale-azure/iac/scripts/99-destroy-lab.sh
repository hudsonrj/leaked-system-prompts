#!/usr/bin/env bash
# =============================================================================
# 99-destroy-lab.sh — remove o ambiente HAT (NUNCA usar na Vale)
# Key Vault e AI Services ficam em soft-delete; o purge é feito abaixo.
# =============================================================================
set -euo pipefail
RG="rg-integia-lab-brs"
read -r -p "Remover TODO o $RG na assinatura $(az account show --query name -o tsv)? digite o nome do RG: " c
[[ "$c" == "$RG" ]] || { echo "cancelado"; exit 1; }
KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv || true)
AIS=$(az cognitiveservices account list -g "$RG" --query "[].name" -o tsv || true)
az group delete -n "$RG" --yes
[[ -n "$KV" ]] && az keyvault purge -n "$KV" || true
for a in $AIS; do az cognitiveservices account purge -g "$RG" -n "$a" -l brazilsouth || true; done
echo "removido"
