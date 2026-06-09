#!/bin/bash
set -e

python3 << 'PYEOF'
conf_path = "/etc/nginx/sites-available/push-ssl"
with open(conf_path, "r") as f:
    content = f.read()

# First, remove any previously added obsidian block (cleanup)
if "obsidian-api proxy" in content:
    import re
    # Remove the obsidian location block
    content = re.sub(r'\n\s*# obsidian-api proxy.*?\}\n', '', content, flags=re.DOTALL)
    print("Removed old obsidian block")

# Find the HTTPS server block (contains 'listen 443' or 'ssl_certificate')
# Insert our location before the closing brace of the 443 block
lines = content.split('\n')

# Find line index of 'ssl_certificate' or 'listen 443'
ssl_line_idx = -1
for i, line in enumerate(lines):
    if 'ssl_certificate' in line and not line.strip().startswith('#'):
        ssl_line_idx = i
        break

if ssl_line_idx == -1:
    print("Could not find ssl_certificate line, trying listen 443")
    for i, line in enumerate(lines):
        if 'listen 443' in line:
            ssl_line_idx = i
            break

print(f"Found SSL block starting near line {ssl_line_idx}")

# Find the closing brace of this server block
# Count braces from ssl_line_idx going forward
brace_count = 0
server_start = ssl_line_idx
# Go back to find the server { opening
for i in range(ssl_line_idx, -1, -1):
    if '{' in lines[i]:
        server_start = i
        break

# Now find the matching close brace
brace_count = 0
server_end = -1
for i in range(server_start, len(lines)):
    brace_count += lines[i].count('{')
    brace_count -= lines[i].count('}')
    if brace_count == 0 and i > server_start:
        server_end = i
        break

print(f"HTTPS server block: lines {server_start} to {server_end}")
print(f"Closing line: '{lines[server_end]}'")

location_block = [
    "    # obsidian-api proxy",
    "    location /obsidian/ {",
    "        proxy_pass http://127.0.0.1:3002/;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host $host;",
    "        proxy_set_header X-Real-IP $remote_addr;",
    "        add_header Access-Control-Allow-Origin *;",
    "        add_header Access-Control-Allow-Methods \"GET, POST, PUT, DELETE, OPTIONS\";",
    "        add_header Access-Control-Allow-Headers \"Authorization, Content-Type\";",
    "    }",
]

new_lines = lines[:server_end] + location_block + lines[server_end:]
new_content = '\n'.join(new_lines)
with open(conf_path, "w") as f:
    f.write(new_content)
print("Successfully added /obsidian/ to HTTPS server block")
PYEOF

nginx -t && systemctl reload nginx
echo "==> Testing via HTTPS..."
sleep 1
curl -s https://push.lucinesmets.com/obsidian/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
echo ""
echo "==> Done!"
