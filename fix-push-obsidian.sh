#!/bin/bash
set -e

# Find the nginx config for push.lucinesmets.com
CONF=$(grep -rl 'push.lucinesmets.com' /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
echo "==> Found nginx config: $CONF"

# Add /obsidian/ location block if not already there
if ! grep -q 'obsidian-api-proxy' "$CONF" 2>/dev/null; then
  # Insert before the last closing brace of the server block
  sed -i 's|^}$|    # obsidian-api-proxy\n    location /obsidian/ {\n        proxy_pass http://127.0.0.1:3002/;\n        proxy_http_version 1.1;\n        proxy_set_header Host $host;\n        add_header Access-Control-Allow-Origin *;\n        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";\n        add_header Access-Control-Allow-Headers "Authorization, Content-Type";\n        if ($request_method = OPTIONS) { return 204; }\n    }\n}|' "$CONF"
  echo "==> Added /obsidian/ location block"
else
  echo "==> Already has obsidian proxy"
fi

nginx -t && systemctl reload nginx
echo "==> Done! Test: curl https://push.lucinesmets.com/obsidian/ -H 'Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d'"
