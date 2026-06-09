#!/bin/bash
python3 << 'PYEOF'
import re

path = '/etc/nginx/sites-available/push-ssl'
c = open(path).read()
print("--- Current file ---")
print(c[:500])
print("...")

# Extract the misplaced obsidian location block (outside server {})
m = re.search(r'\n(# obsidian-api proxy\nlocation /obsidian/ \{.*?\n\})', c, re.DOTALL)
if not m:
    print("ERROR: obsidian block not found outside server")
    exit(1)

loc_raw = m.group(1)
print(f"Found misplaced block ({len(loc_raw)} chars)")

# Remove it from its current position
c2 = c.replace('\n' + loc_raw, '', 1)

# Indent it for inside server block
loc_indented = '\n    ' + loc_raw.replace('\n', '\n    ')

# Find ssl_dhparam line, then find the next \n} after it = server block closing brace
idx = c2.find('ssl_dhparam')
if idx < 0:
    print("ERROR: ssl_dhparam not found")
    exit(1)
nl = c2.find('\n}', idx)
if nl < 0:
    print("ERROR: server closing brace not found after ssl_dhparam")
    exit(1)

print(f"Inserting before position {nl}: '{c2[nl:nl+20]}'")

# Insert before \n}
fixed = c2[:nl] + loc_indented + c2[nl:]
open(path, 'w').write(fixed)
print("WRITTEN OK")
PYEOF

echo "==> nginx test..."
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo "==> nginx reloaded"
    sleep 1
    curl -s https://push.lucinesmets.com/obsidian/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
else
    echo "==> nginx test FAILED, not reloading"
fi
