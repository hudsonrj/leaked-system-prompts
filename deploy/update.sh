#!/usr/bin/env bash
# Atualiza o Raio-X no servidor (rodar NO SERVIDOR, como root):
#   cd /root/apps/secretsaiprompts && git pull && bash deploy/update.sh
#
# - Site estático servido pelo Caddy a partir de explorer/
# - Backend da IA (server/assistant.py) como serviço systemd em 127.0.0.1:8437
# - Caddy: /api/* -> backend; o resto -> arquivos estáticos
# - Chave da IA lida de /root/apps/secretsaiprompts/.env (DEEP_SEEK=...), nunca do git
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${DOMAIN:-secretsaiprompts.ch8ai.com.br}"
PORT="${PORT:-8437}"
SVC=secretsaiprompts-assistant
CADDYFILE=/etc/caddy/Caddyfile
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="/var/log/caddy/${DOMAIN//./-}-access.log"

caddy_validate() {
  ( PID="$(systemctl show -p MainPID --value caddy 2>/dev/null || true)"
    if [ -n "$PID" ] && [ "$PID" != 0 ] && [ -r "/proc/$PID/environ" ]; then
      while IFS= read -r -d '' kv; do export "$kv"; done < "/proc/$PID/environ"
    fi
    caddy validate --config "$CADDYFILE" --adapter caddyfile ) >/tmp/caddy-validate.log 2>&1
}

echo "==> 1/4 Permissões dos arquivos estáticos"
chmod o+x /root /root/apps "$REPO"
chmod -R a+rX "$REPO/explorer"

echo "==> 2/4 Chave da IA"
ENVF="$REPO/.env"
if [ -f "$ENVF" ] && grep -qE '^(DEEP_SEEK|LLM_API_KEY|DEEPSEEK_API_KEY)=.+' "$ENVF"; then
  chmod 600 "$ENVF"; echo "    .env encontrado (permissão 600)."
else
  echo "    ERRO: crie $ENVF com a linha DEEP_SEEK=sua-chave"; exit 1
fi

echo "==> 3/4 Serviço do backend ($SVC na porta $PORT)"
if ss -ltn | grep -q "127.0.0.1:$PORT " && ! systemctl is-active -q "$SVC"; then
  echo "    ERRO: a porta $PORT já está em uso por outro processo. Rode com PORT=outra bash deploy/update.sh"; exit 1
fi
cat > "/etc/systemd/system/$SVC.service" <<UNIT
[Unit]
Description=Raio-X dos System Prompts - backend do Estudio IA
After=network-online.target

[Service]
WorkingDirectory=$REPO
Environment=PORT=$PORT
ExecStart=/usr/bin/python3 $REPO/server/assistant.py
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable -q "$SVC"
systemctl restart "$SVC"
sleep 1
curl -fsS "http://127.0.0.1:$PORT/api/health" && echo

echo "==> 4/4 Caddy (/api -> backend)"
mkdir -p /var/log/caddy
REF="$(ls -t /var/log/caddy/*-access.log 2>/dev/null | grep -v "$LOG" | head -1 || true)"
[ -f "$LOG" ] || touch "$LOG"
if [ -n "$REF" ]; then chown --reference="$REF" "$LOG"; chmod --reference="$REF" "$LOG"; fi

BLOCK="$DOMAIN {
	log {
		output file $LOG
	}
	handle /api/* {
		reverse_proxy 127.0.0.1:$PORT {
			flush_interval -1
		}
	}
	handle {
		encode gzip
		root * $REPO/explorer
		file_server
	}
}"
if grep -q "127.0.0.1:$PORT" "$CADDYFILE" && grep -q "^$DOMAIN {" "$CADDYFILE"; then
  echo "    Caddy já roteia /api para o backend. Nada a mudar."
else
  cp -a "$CADDYFILE" "${CADDYFILE%/*}/Caddyfile.before-secretsaiprompts-$TS"
  # remove o bloco antigo deste domínio (se existir) e acrescenta o novo
  DOMAIN="$DOMAIN" BLOCK="$BLOCK" python3 - "$CADDYFILE" <<'PY'
import os, sys
p = sys.argv[1]; dom = os.environ['DOMAIN']; block = os.environ['BLOCK']
lines = open(p).read().split('\n'); out = []; i = 0
while i < len(lines):
    if lines[i].strip() == dom + ' {':
        depth = 0
        while i < len(lines):
            depth += lines[i].count('{') - lines[i].count('}')
            i += 1
            if depth <= 0: break
        while out and not out[-1].strip(): out.pop()
        continue
    out.append(lines[i]); i += 1
open(p, 'w').write('\n'.join(out).rstrip('\n') + '\n\n' + block + '\n')
PY
  if ! caddy_validate; then
    echo "    ERRO na validação; restaurando."; grep -i error /tmp/caddy-validate.log | tail -3
    cp -a "${CADDYFILE%/*}/Caddyfile.before-secretsaiprompts-$TS" "$CADDYFILE"; exit 1
  fi
  if ! systemctl reload caddy; then
    echo "    ERRO no reload; restaurando."; cp -a "${CADDYFILE%/*}/Caddyfile.before-secretsaiprompts-$TS" "$CADDYFILE"
    journalctl -u caddy -n 8 --no-pager | grep -vi token; exit 1
  fi
fi

sleep 2
echo
curl -sS -o /dev/null -w "Site: HTTP %{http_code}\n" "https://$DOMAIN/"
curl -sS -w "\n" "https://$DOMAIN/api/health"
echo "Pronto: https://$DOMAIN/#estudio"
