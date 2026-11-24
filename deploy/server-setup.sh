#!/usr/bin/env bash
# Executado NO SERVIDOR por deploy.sh. Pode ser rodado de novo para atualizar.
set -euo pipefail
: "${APP_DIR:?}" "${DOMAIN:?}"

echo "==> Extraindo em $APP_DIR"
mkdir -p "$APP_DIR"
tar -xzf /tmp/raio-x.tar.gz -C "$APP_DIR"
rm -f /tmp/raio-x.tar.gz
# nginx roda como outro usuário: liberar só a travessia de /root e a leitura da app
chmod 711 /root /root/apps
find "$APP_DIR" -type d -exec chmod 755 {} + ; find "$APP_DIR" -type f -exec chmod 644 {} +

if ! command -v nginx >/dev/null; then
  echo "==> Instalando nginx"
  if command -v apt-get >/dev/null; then apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx
  elif command -v dnf >/dev/null; then dnf install -y nginx && systemctl enable --now nginx
  else echo "Instale o nginx manualmente."; exit 1; fi
fi

# Se outra coisa (ex.: Docker/Traefik) já ocupa a porta 80 e não é o nginx, avisa e para
if ss -ltnp 2>/dev/null | grep -E ':80\s' | grep -vq nginx; then
  echo "AVISO: a porta 80 está em uso por outro processo (não nginx):"; ss -ltnp | grep -E ':80\s'
  echo "Arquivos já estão em $APP_DIR. Configure o proxy existente para servir essa pasta em $DOMAIN."; exit 2
fi

CONF_DIR=/etc/nginx/sites-available; [ -d "$CONF_DIR" ] || CONF_DIR=/etc/nginx/conf.d
CONF="$CONF_DIR/$DOMAIN.conf"
echo "==> Configurando nginx ($CONF)"
cat > "$CONF" <<NGX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $APP_DIR;
    index index.html;

    gzip on;
    gzip_types text/css application/javascript application/json text/plain;
    gzip_min_length 1024;

    location / { try_files \$uri \$uri/ /index.html; }
    location ~* \.(js|css)\$ { expires 1h; add_header Cache-Control "public"; }

    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy strict-origin-when-cross-origin;
}
NGX
if [ -d /etc/nginx/sites-enabled ]; then ln -sf "$CONF" "/etc/nginx/sites-enabled/$DOMAIN.conf"; fi
nginx -t && systemctl reload nginx

echo "==> HTTPS (Let's Encrypt)"
if ! command -v certbot >/dev/null; then
  if command -v apt-get >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot python3-certbot-nginx
  elif command -v dnf >/dev/null; then dnf install -y certbot python3-certbot-nginx; fi
fi
if command -v ufw >/dev/null && ufw status | grep -q active; then ufw allow 'Nginx Full' || true; fi
if [ -n "${EMAIL:-}" ]; then M=(-m "$EMAIL"); else M=(--register-unsafely-without-email); fi
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect "${M[@]}"; then
  echo "HTTPS ativo."
else
  echo "AVISO: certificado não emitido. Verifique se o registro A de $DOMAIN aponta para este servidor"
  echo "e se as portas 80/443 estão abertas. O site segue disponível em http://$DOMAIN"
fi
