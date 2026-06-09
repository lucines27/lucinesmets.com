#!/bin/bash
set -e

CONF="/etc/nginx/sites-available/push-ssl"

echo "==> Current push-ssl config (last 20 lines):"
tail -20 "$CONF"
echo "---"

# Use Python to add /obsidian/ location before last closing brace
python3 << 'PYEOF'
conf_path = "/etc/nginx/sites-available/push-ssl"
with open(conf_path, "r") as f:
    content = f.read()

location_block = """
    # obsidian-api proxy
    location /obsidian/ {
        proxy_pass http://127.0.0.1:3002/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Authorization, Content-Type";
    }
"""

if "obsidian-api proxy" in content:
    print("Already has obsidian proxy, skipping")
else:
    # Insert before the last closing brace of the last server block
    last_brace = content.rfind("}")
    new_content = content[:last_brace] + location_block + content[last_brace:]
    with open(conf_path, "w") as f:
        f.write(new_content)
    print("Added /obsidian/ location block")
PYEOF

nginx -t && systemctl reload nginx
echo "==> Done! Testing https://push.lucinesmets.com/obsidian/"
curl -s -k https://push.lucinesmets.com/obsidian/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d" || echo "(DNS/SSL test failed - local test:)"
curl -s http://127.0.0.1:3002/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
