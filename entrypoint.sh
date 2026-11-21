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

# 3. Configure security entrance path (BT_PATH=none disables it)
if [ -n "${BT_PATH:-}" ]; then
    if [ "${BT_PATH}" = "none" ]; then
        rm -f /www/server/panel/data/admin_path.pl
        echo "[init] aaPanel security entrance disabled (BT_PATH=none)."
    else
        echo "${BT_PATH}" > /www/server/panel/data/admin_path.pl
        echo "[init] aaPanel security entrance set to ${BT_PATH}."
    fi
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

# 6. Start any installed aaPanel services (Nginx, MySQL, PHP-FPM, Redis)
for svc in nginx mysqld pure-ftpd redis; do
    if [ -x "/etc/init.d/${svc}" ]; then
        "/etc/init.d/${svc}" start || true
    fi
done

for phpfpm in /etc/init.d/php-fpm-*; do
    if [ -x "$phpfpm" ]; then
        "$phpfpm" start || true
    fi
done

echo "[init] aaPanel listening on port ${BT_PORT}."
sleep 2
echo "[init] Local health probe (http://127.0.0.1:${BT_PORT}/):"
curl -i -sS --max-time 5 "http://127.0.0.1:${BT_PORT}/" | head -n 20 || true

# 7. Hand over to supervisord in foreground
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
