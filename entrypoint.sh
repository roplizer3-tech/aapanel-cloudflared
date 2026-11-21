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
    echo "/aapanel" > /www/server/panel/data/admin_path.pl
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
echo "[diag] BTPanel 355-385:"
sed -n '355,385p' /www/server/panel/BTPanel/__init__.py 2>/dev/null || true
echo "[diag] curl /aapanel via 7800:"
curl -i -sS "http://127.0.0.1:${BT_PORT}/aapanel" | head -n 20 || true
echo "[diag] curl /aapanel via unix socket:"
curl -i -sS --unix-socket /tmp/panel.sock "http://127.0.0.1/aapanel" | head -n 20 || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
