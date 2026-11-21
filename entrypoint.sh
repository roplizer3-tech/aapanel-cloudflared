#!/usr/bin/env bash
set -u

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

# 3. Configure security entrance path (default /aapanel; /panel is reserved in aaPanel 7.x)
ENTRANCE_PATH="${BT_PATH:-/aapanel}"
if [ "${ENTRANCE_PATH}" = "none" ]; then
    ENTRANCE_PATH="/aapanel"
fi
echo "${ENTRANCE_PATH}" > /www/server/panel/data/admin_path.pl
echo "[init] aaPanel entrance path: ${ENTRANCE_PATH}"

# 4. Configure password if provided
BTPY="/www/server/panel/pyenv/bin/python"
if [ ! -x "$BTPY" ]; then
    BTPY="$(command -v btpython || command -v python3 || true)"
fi

if [ -n "${BT_PASS:-}" ] && [ -n "$BTPY" ] && [ -f /www/server/panel/tools.py ]; then
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

echo "[init] aaPanel ready on port ${BT_PORT}${ENTRANCE_PATH}. Launching supervisord..."

# 7. Hand over to supervisord in foreground
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
