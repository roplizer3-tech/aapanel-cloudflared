#!/usr/bin/env bash
set -euo pipefail

echo "[init] Starting aaPanel + Cloudflared container..."

# 1. Seed /www if mounted as an empty persistent volume
if [ ! -d "/www/server/panel" ]; then
    echo "[init] Empty /www detected. Seeding aaPanel files from /opt/www-seed..."
    mkdir -p /www
    cp -a /opt/www-seed/. /www/
fi

mkdir -p /www/server/panel/logs /www/wwwroot /www/backup

# 2. Configure aaPanel port and disable internal panel SSL (Cloudflare/Cranl terminate TLS)
BT_PORT="${BT_PORT:-7800}"
echo "${BT_PORT}" > /www/server/panel/data/port.pl
rm -f /www/server/panel/data/ssl.pl /www/server/panel/data/domain.pl

# 3. Configure security entrance path
if [ "${BT_PATH:-}" = "none" ] || [ -z "${BT_PATH:-}" ]; then
    echo "/panel" > /www/server/panel/data/admin_path.pl
else
    echo "${BT_PATH}" > /www/server/panel/data/admin_path.pl
fi

# 4. Configure password if provided
BTPY="/www/server/panel/pyenv/bin/python"
if [ ! -x "$BTPY" ]; then
    BTPY="$(command -v btpython || command -v python3)"
fi

if [ -n "${BT_PASS:-}" ] && [ -f /www/server/panel/tools.py ]; then
    "$BTPY" /www/server/panel/tools.py panel "${BT_PASS}" || true
fi

# 5. Start cron and aaPanel
service cron start || true
/etc/init.d/bt restart || /etc/init.d/bt start || bt start || true

sleep 2
echo "[diag] ps aux:"
ps aux | grep -E "bt|panel|webserver|nginx|python" || true
echo "[diag] /www/server/panel/data:"
ls -la /www/server/panel/data/ || true
echo "[diag] panel error log tail:"
tail -n 25 /www/server/panel/logs/error.log 2>/dev/null || true
echo "[diag] webserver conf:"
find /www/server/panel -maxdepth 3 -name "*.conf" 2>/dev/null | head -n 20 || true

# 6. Hand over to supervisord in foreground
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
