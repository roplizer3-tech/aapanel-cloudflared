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

echo "[diag] grep 404 and admin_path in BTPanel/__init__.py:"
grep -n -C 4 -E "404|admin_path" /www/server/panel/BTPanel/__init__.py 2>/dev/null | head -n 90 || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
