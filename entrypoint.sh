#!/usr/bin/env bash
set -euo pipefail

echo "[init] Starting aaPanel + Cloudflared container..."

if [ ! -d "/www/server/panel" ]; then
    mkdir -p /www
    cp -a /opt/www-seed/. /www/
fi

mkdir -p /www/server/panel/logs /www/wwwroot /www/backup

BT_PORT="${BT_PORT:-7800}"
echo "${BT_PORT}" > /www/server/panel/data/port.pl
rm -f /www/server/panel/data/ssl.pl /www/server/panel/data/domain.pl

if [ "${BT_PATH:-}" = "none" ] || [ -z "${BT_PATH:-}" ]; then
    echo "/panel" > /www/server/panel/data/admin_path.pl
else
    echo "${BT_PATH}" > /www/server/panel/data/admin_path.pl
fi

BTPY="/www/server/panel/pyenv/bin/python"
if [ ! -x "$BTPY" ]; then
    BTPY="$(command -v btpython || command -v python3)"
fi

if [ -n "${BT_PASS:-}" ] && [ -f /www/server/panel/tools.py ]; then
    "$BTPY" /www/server/panel/tools.py panel "${BT_PASS}" || true
fi

service cron start || true
/etc/init.d/bt restart || /etc/init.d/bt start || bt start || true

sleep 2
echo "[diag] webserver binary & conf:"
ls -la /www/server/panel/ | grep -E "web|nginx|conf" || true
ls -la /www/server/panel/webserver* 2>/dev/null || true
cat /www/server/panel/webserver/conf/nginx.conf 2>/dev/null | head -n 80 || true
echo "[diag] curl with X-Forwarded-Proto: https:"
curl -i -sS -H "Host: panel.korixa.online" -H "X-Forwarded-Proto: https" "http://127.0.0.1:${BT_PORT}/panel" | head -n 20 || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
