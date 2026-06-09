#!/bin/bash
wget -O /etc/nginx/sites-available/push-ssl https://raw.githubusercontent.com/lucines27/lucinesmets.com/main/push-ssl.conf
nginx -t
if [ $? -eq 0 ]; then
  systemctl reload nginx
  echo NGINX_OK
  curl -s https://push.lucinesmets.com/obsidian/ -H "Authorization: Bearer 2cca484a2774acf10e0f6edc8f20e5adeb94639ffbf2b515b3a36e16eb69c09d"
else
  echo NGINX_FAIL
fi
