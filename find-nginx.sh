#!/bin/bash
echo "==> Searching nginx configs..."
grep -rl 'push.lucinesmets' /etc/nginx/ 2>/dev/null
echo "---"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null
echo "---"
ls -la /etc/nginx/conf.d/ 2>/dev/null
echo "---"
cat /etc/nginx/nginx.conf | grep -i server_name
