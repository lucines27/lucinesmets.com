#!/bin/bash
set -e

API_KEY="2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
PORT=3002
VAULT_DIR="/root/obsidian-vault"
APP_DIR="/root/obsidian-api"
DOMAIN="obsidian.lucinesmets.com"

mkdir -p "$VAULT_DIR"

echo "==> PM2 start..."
cd "$APP_DIR"
pm2 delete obsidian-api 2>/dev/null || true
PORT="$PORT" API_KEY="$API_KEY" VAULT="$VAULT_DIR" pm2 start server.js --name obsidian-api
pm2 save
pm2 startup systemd -u root --hp /root | tail -1 | bash

echo "==> nginx config..."
cat > /etc/nginx/sites-available/obsidian-api << 'NGINX'
server {
    listen 80;
    server_name obsidian.lucinesmets.com;
    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Authorization, Content-Type";
    }
}
NGINX
ln -sf /etc/nginx/sites-available/obsidian-api /etc/nginx/sites-enabled/obsidian-api
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "==> certbot SSL..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email

echo "==> All done!"
curl -s http://127.0.0.1:3002/ -H "Authorization: Bearer $API_KEY"
