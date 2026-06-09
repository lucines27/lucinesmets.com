#!/bin/bash
set -e

API_KEY="2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
PORT=3002
VAULT_DIR="/root/obsidian-vault"
APP_DIR="/root/obsidian-api"
DOMAIN="obsidian.lucinesmets.com"

echo "==> Creating directories..."
mkdir -p "$APP_DIR" "$VAULT_DIR"

echo "==> Writing server.js..."
cat > "$APP_DIR/server.js" << 'SERVERJS'
const express = require('express');
const fs      = require('fs');
const path    = require('path');
const app     = express();
const PORT    = process.env.PORT    || 3002;
const API_KEY = process.env.API_KEY || 'CHANGE_ME';
const VAULT   = process.env.VAULT   || path.join(__dirname, 'vault');

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use((req, res, next) => {
  const auth = req.headers['authorization'] || '';
  if (auth !== `Bearer ${API_KEY}`) return res.status(401).json({ error: 'Unauthorized' });
  next();
});
app.use(express.text({ type: '*/*', limit: '10mb' }));

function safePath(reqPath) {
  const decoded = decodeURIComponent(reqPath);
  const resolved = path.resolve(VAULT, decoded.replace(/^\//, ''));
  if (!resolved.startsWith(VAULT)) return null; // traversal guard
  return resolved;
}

app.get('/', (req, res) => res.json({ status: 'OK', vault: VAULT }));

app.get('/vault/*', (req, res) => {
  const filePath = safePath(req.params[0]);
  if (!filePath) return res.status(400).json({ error: 'Invalid path' });
  if (!fs.existsSync(filePath)) {
    if (filePath.endsWith('/') || !path.extname(filePath)) {
      return res.json({ files: [] });
    }
    return res.status(404).json({ error: 'Not found' });
  }
  const stat = fs.statSync(filePath);
  if (stat.isDirectory()) {
    const files = fs.readdirSync(filePath).map(f => {
      const full = path.join(filePath, f);
      return { path: f, isDir: fs.statSync(full).isDirectory() };
    });
    return res.json({ files });
  }
  const content = fs.readFileSync(filePath, 'utf8');
  res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
  res.send(content);
});

app.put('/vault/*', (req, res) => {
  const filePath = safePath(req.params[0]);
  if (!filePath) return res.status(400).json({ error: 'Invalid path' });
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, req.body || '', 'utf8');
  res.status(200).json({ message: 'OK', path: filePath.replace(VAULT, '') });
});

fs.mkdirSync(VAULT, { recursive: true });
app.listen(PORT, '127.0.0.1', () => {
  console.log(`Obsidian API server running on http://127.0.0.1:${PORT}`);
  console.log(`Vault: ${VAULT}`);
});
SERVERJS

echo "==> Writing package.json..."
cat > "$APP_DIR/package.json" << JSON
{
  "name": "obsidian-api",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": { "express": "^4.18.2" }
}
JSON

echo "==> Writing PM2 ecosystem..."
cat > "$APP_DIR/ecosystem.config.js" << PM2
[module.exports = {
  apps: [{
    name: 'obsidian-api',
    script: 'server.js',
    cwd: '$APP_DIR',
    env: { PORT: $PORT, API_KEY: '$API_KEY', VAULT: '$VAULT_DIR' },
    restart_delay: 3000,
    max_restarts: 10
  }]
};
PM2

echo "==> Installing Node + npm if needed..."
which node || (curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs)

echo "==> npm install..."
cd "$APP_DIR" && npm install --silent

echo "==> Installing PM2..."
npm install -g pm2 --silent 2>/dev/null || true

echo "==> Starting with PM2..."
pm2 delete obsidian-api 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save

echo "==> Writing nginx config..."
cat > "/etc/nginx/sites-available/$DOMAIN" << NGINX
server {
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header Authorization \$http_authorization;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 30s;
    }
    listen 80;
}
NGINX

ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
nginx -t && systemctl reload nginx

echo "==> SSL avec certbot..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m contact@lucinesmets.be 2>&1 | tail -5

echo ""
echo "==> Test final..."
sleep 2
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -H "Authorization: Bearer $API_KEY" \
  "https://$DOMAIN/"

echo "✅ Obsidian API déployée sur https://$DOMAIN"
