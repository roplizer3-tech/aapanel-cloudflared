#!/usr/bin/env bash
set -u

echo "[init] Starting aaPanel + Cloudflared container..."

if [ ! -d "/www/server/panel" ]; then
    mkdir -p /www
    cp -a /opt/www-seed/. /www/
fi

mkdir -p /www/server/panel/logs /www/wwwroot /www/backup

BT_PORT="${BT_PORT:-7800}"
echo "${BT_PORT}" > /www/server/panel/data/port.pl
rm -f /www/server/panel/data/ssl.pl /www/server/panel/data/domain.pl

ENTRANCE_PATH="${BT_PATH:-/aapanel}"
if [ "${ENTRANCE_PATH}" = "none" ]; then
    ENTRANCE_PATH="/aapanel"
fi
echo "${ENTRANCE_PATH}" > /www/server/panel/data/admin_path.pl

BTPY="/www/server/panel/pyenv/bin/python"
if [ ! -x "$BTPY" ]; then
    BTPY="$(command -v btpython || command -v python3 || true)"
fi

if [ -n "${BT_PASS:-}" ] && [ -n "$BTPY" ] && [ -f /www/server/panel/tools.py ]; then
    "$BTPY" /www/server/panel/tools.py panel "${BT_PASS}" || true
fi

service cron start || true
/etc/init.d/bt restart || /etc/init.d/bt start || bt start || true

echo "[diag] cdn.conf:"
cat /www/server/panel/config/cdn.conf 2>/dev/null || true
echo "[diag] client_ip.py:"
find /www/server/panel -name "client_ip.py" -exec head -n 90 {} + 2>/dev/null || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
