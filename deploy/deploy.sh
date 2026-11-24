#!/usr/bin/env bash
# Publica o Raio-X dos System Prompts no servidor (Caddy serve os arquivos estáticos com HTTPS automático).
# Rode na SUA máquina (que alcança o servidor), a partir da raiz do repositório:
#   bash deploy/deploy.sh                      # usa os valores padrão abaixo
#   HOST=1.2.3.4 DOMAIN=meu.dominio bash deploy/deploy.sh
# A senha é pedida pelo ssh; nada fica gravado em arquivo.
set -euo pipefail

HOST="${HOST:-100.119.119.83}"
SSH_USER="${SSH_USER:-root}"
DOMAIN="${DOMAIN:-secretsaiprompts.ch8ai.com.br}"
APP_DIR="${APP_DIR:-/root/apps/secretsaiprompts}"

cd "$(dirname "$0")/.."
[ -f explorer/index.html ] || { echo "Rode a partir do repositório (explorer/ não encontrado)."; exit 1; }

PKG="$(mktemp -t raio-x.XXXXXX).tar.gz"
tar -czf "$PKG" -C explorer index.html styles.css app.js data README.md
echo "Pacote: $(du -h "$PKG" | cut -f1)"

# Uma única conexão SSH reaproveitada (a senha é pedida uma vez)
CTL="$(mktemp -u -t raio-x-ssh.XXXXXX)"
SSH_OPTS=(-o ControlMaster=auto -o ControlPath="$CTL" -o ControlPersist=120 -o StrictHostKeyChecking=accept-new)
trap 'ssh "${SSH_OPTS[@]}" -O exit "$SSH_USER@$HOST" 2>/dev/null || true; rm -f "$PKG"' EXIT

ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" "mkdir -p '$APP_DIR'"
scp "${SSH_OPTS[@]}" "$PKG" "$SSH_USER@$HOST:/tmp/raio-x.tar.gz"
scp "${SSH_OPTS[@]}" deploy/server-setup.sh "$SSH_USER@$HOST:/tmp/raio-x-setup.sh"
ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" "APP_DIR='$APP_DIR' DOMAIN='$DOMAIN' bash /tmp/raio-x-setup.sh"
echo
echo "Pronto: https://$DOMAIN"
