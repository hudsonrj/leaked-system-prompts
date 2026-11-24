#!/usr/bin/env bash
# Executado NO SERVIDOR por deploy.sh. Segue o padrão do servidor: Caddy + /root/apps/<app>.
# Idempotente: rodar de novo só atualiza os arquivos.
set -euo pipefail
: "${APP_DIR:?}" "${DOMAIN:?}"
APP="${APP_NAME:-secretsaiprompts}"
CADDYFILE=/etc/caddy/Caddyfile
TS="$(date -u +%Y%m%dT%H%M%SZ)"

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

if grep -qE "^${DOMAIN//./\\.}[[:space:]]*\{" "$CADDYFILE" "${CADDYFILE%/*}"/sites-enabled/* 2>/dev/null; then
  echo "==> $DOMAIN já existe no Caddy; só os arquivos foram atualizados."
else
  echo "==> Adicionando $DOMAIN ao Caddyfile (backup: Caddyfile.before-$APP-$TS)"
  cp -a "$CADDYFILE" "${CADDYFILE%/*}/Caddyfile.before-$APP-$TS"
  cat >> "$CADDYFILE" <<CADDY

$DOMAIN {
	log {
		output file /var/log/caddy/${DOMAIN//./-}-access.log
	}
	encode gzip
	root * $APP_DIR
	header {
		X-Content-Type-Options nosniff
		Referrer-Policy strict-origin-when-cross-origin
	}
	@assets path *.js *.css
	header @assets Cache-Control "public, max-age=3600"
	file_server
}
CADDY
  if ! caddy validate --config "$CADDYFILE" --adapter caddyfile >/tmp/caddy-validate.log 2>&1; then
    echo "ERRO na validação; restaurando o Caddyfile anterior."; cat /tmp/caddy-validate.log | tail -20
    cp -a "${CADDYFILE%/*}/Caddyfile.before-$APP-$TS" "$CADDYFILE"; exit 1
  fi
  systemctl reload caddy
fi

echo "==> Testando (o certificado pode levar alguns segundos na primeira vez)"
sleep 3
curl -sS -o /dev/null -w "HTTP %{http_code} em https://$DOMAIN\n" --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/" || \
  echo "Ainda sem resposta HTTPS. Veja: journalctl -u caddy -n 50 --no-pager"
