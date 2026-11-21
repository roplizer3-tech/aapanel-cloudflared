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
echo "[diag] webserver conf files:"
ls -la /www/server/panel/webserver/conf/ || true
head -n 120 /www/server/panel/webserver/conf/* 2>/dev/null || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
