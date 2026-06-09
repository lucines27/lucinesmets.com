#!/bin/bash
set -e

DOMAIN="obsidian.lucinesmets.com"

echo "==> nginx config..."
cat > /etc/nginx/sites-available/obsidian-api << 'NGINX'
server {
    listen 80;
    server_name obsidian.lucinesmets.com;

    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Authorization, Content-Type";
        if ($request_method = OPTIONS) { return 204; }
    }
}
NGINX

ln -sf /etc/nginx/sites-available/obsidian-api /etc/nginx/sites-enabled/obsidian-api
nginx -t && systemctl reload nginx

echo "==> Testing local API..."
sleep 1
curl -s http://127.0.0.1:3002/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
echo ""
echo "==> nginx done! Add DNS A record: obsidian.lucinesmets.com -> 178.105.58.171"
echo "==> Then run: certbot --nginx -d obsidian.lucinesmets.com --non-interactive --agree-tos --email smets.lucine@gmail.com"
