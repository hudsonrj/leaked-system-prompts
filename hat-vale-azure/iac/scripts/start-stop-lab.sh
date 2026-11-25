#!/usr/bin/env bash
# =============================================================================
# start-stop-lab.sh — FinOps do laboratório HAT: desliga o que cobra por hora
# Uso: ./start-stop-lab.sh stop|start
# (APIM Developer, Search, Service Bus Premium e ACR Premium não "param":
#  para economia maior, destruir e recriar via IaC.)
# =============================================================================
set -euo pipefail
ACTION="${1:?stop|start}"; RG="rg-integia-lab-brs"
PG=$(az postgres flexible-server list -g "$RG" --query "[0].name" -o tsv)
AGW=$(az network application-gateway list -g "$RG" --query "[0].name" -o tsv)
VM=$(az vm list -g "$RG" --query "[0].name" -o tsv)
if [[ "$ACTION" == "stop" ]]; then
  az postgres flexible-server stop -g "$RG" -n "$PG" || true
  [[ -n "$AGW" ]] && az network application-gateway stop -g "$RG" -n "$AGW" || true
  [[ -n "$VM" ]] && az vm deallocate -g "$RG" -n "$VM" || true
  for app in $(az containerapp list -g "$RG" --query "[].name" -o tsv); do
    az containerapp update -g "$RG" -n "$app" --min-replicas 0 -o none
  done
else
  az postgres flexible-server start -g "$RG" -n "$PG" || true
  [[ -n "$AGW" ]] && az network application-gateway start -g "$RG" -n "$AGW" || true
  [[ -n "$VM" ]] && az vm start -g "$RG" -n "$VM" || true
  for app in $(az containerapp list -g "$RG" --query "[].name" -o tsv); do
    min=1; [[ "$app" == *mcp* || "$app" == *gateway* ]] && min=2
    az containerapp update -g "$RG" -n "$app" --min-replicas $min -o none
  done
fi
