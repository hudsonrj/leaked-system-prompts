#!/usr/bin/env bash
# Executado NO SERVIDOR por deploy.sh. Segue o padrão do servidor: Caddy + /root/apps/<app>.
# Idempotente: rodar de novo só atualiza os arquivos.
set -euo pipefail
: "${APP_DIR:?}" "${DOMAIN:?}"
APP="${APP_NAME:-secretsaiprompts}"
CADDYFILE=/etc/caddy/Caddyfile
TS="$(date -u +%Y%m%dT%H%M%SZ)"

# Valida com o MESMO ambiente do Caddy em execução (o Caddyfile usa variáveis como {$KIOSK_TOKEN},
# que vêm do systemd e não existem no shell). Os valores não são impressos.
caddy_validate() {
  ( PID="$(systemctl show -p MainPID --value caddy 2>/dev/null || true)"
    if [ -n "$PID" ] && [ "$PID" != 0 ] && [ -r "/proc/$PID/environ" ]; then
      while IFS= read -r -d '' kv; do export "$kv"; done < "/proc/$PID/environ"
    fi
    caddy validate --config "$CADDYFILE" --adapter caddyfile ) >/tmp/caddy-validate.log 2>&1
}

# APP_DIR = pasta servida pelo Caddy. Com pacote enviado por deploy.sh, extrai nela;
# sem pacote (git clone feito no próprio servidor), usa os arquivos que já estão lá.
if [ -f /tmp/raio-x.tar.gz ]; then
  echo "==> Atualizando arquivos em $APP_DIR"
  mkdir -p "$APP_DIR"
  NEW="$(mktemp -d)"
  tar -xzf /tmp/raio-x.tar.gz -C "$NEW"
  rm -rf "$APP_DIR/data" && cp -a "$NEW"/. "$APP_DIR"/
  rm -rf "$NEW" /tmp/raio-x.tar.gz
fi
[ -f "$APP_DIR/index.html" ] || { echo "index.html não encontrado em $APP_DIR"; exit 1; }
chmod -R a+rX "$APP_DIR"; chmod o+x "$(dirname "$APP_DIR")"
# Caddy precisa atravessar /root (já está 711 neste servidor; garante sem abrir leitura)
chmod o+x /root /root/apps

# O Caddy roda como outro usuário: cria o log com o mesmo dono/modo dos logs existentes
LOG="/var/log/caddy/${DOMAIN//./-}-access.log"
mkdir -p /var/log/caddy
REF="$(ls -t /var/log/caddy/*-access.log 2>/dev/null | grep -v "$LOG" | head -1 || true)"
[ -f "$LOG" ] || touch "$LOG"
if [ -n "$REF" ]; then chown --reference="$REF" "$LOG"; chmod --reference="$REF" "$LOG"
else chown "$(stat -c %U:%G /var/log/caddy)" "$LOG"; chmod 644 "$LOG"; fi

if grep -qE "^${DOMAIN//./\\.}[[:space:]]*\{" "$CADDYFILE" "${CADDYFILE%/*}"/sites-enabled/* 2>/dev/null; then
  echo "==> $DOMAIN já está no Caddyfile; validando e recarregando"
  caddy_validate || { echo "ERRO de validação:"; grep -i error /tmp/caddy-validate.log | tail -3; exit 1; }
  systemctl reload caddy || { journalctl -u caddy -n 6 --no-pager | grep -vi token; exit 1; }
else
  if ! caddy_validate; then
    echo "ERRO: o Caddyfile ATUAL já não valida (antes de qualquer mudança). Nada foi alterado."
    grep -i error /tmp/caddy-validate.log | tail -3
    L=$(grep -oE 'Caddyfile:[0-9]+' /tmp/caddy-validate.log | tail -1 | cut -d: -f2)
    [ -n "$L" ] && { echo "--- trecho ao redor da linha $L:"; sed -n "$((L-8)),$((L+3))p" "$CADDYFILE" | cat -n; }
    exit 1
  fi
  echo "==> Adicionando $DOMAIN ao Caddyfile (backup: Caddyfile.before-$APP-$TS)"
  cp -a "$CADDYFILE" "${CADDYFILE%/*}/Caddyfile.before-$APP-$TS"
  cat >> "$CADDYFILE" <<CADDY

$DOMAIN {
	log {
		output file $LOG
	}
	encode gzip
	root * $APP_DIR
	file_server
}
CADDY
  if ! caddy_validate; then
    echo "ERRO na validação; restaurando o Caddyfile anterior."; cat /tmp/caddy-validate.log | tail -20
    cp -a "${CADDYFILE%/*}/Caddyfile.before-$APP-$TS" "$CADDYFILE"; exit 1
  fi
  if ! systemctl reload caddy; then
    echo "ERRO no reload; restaurando o Caddyfile anterior (o Caddy segue com a configuração antiga)."
    cp -a "${CADDYFILE%/*}/Caddyfile.before-$APP-$TS" "$CADDYFILE"
    journalctl -u caddy -n 15 --no-pager | grep -vi token | tail -15
    exit 1
  fi
fi

echo "==> Testando (o certificado pode levar alguns segundos na primeira vez)"
sleep 3
curl -sS -o /dev/null -w "HTTP %{http_code} em https://$DOMAIN\n" --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/" || \
  echo "Ainda sem resposta HTTPS. Veja: journalctl -u caddy -n 50 --no-pager"
