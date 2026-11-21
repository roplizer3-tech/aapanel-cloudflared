#!/usr/bin/env bash
set -u

echo "[init] Starting aaPanel + Cloudflared container..."

if [ ! -d "/www/server/panel" ]; then
    mkdir -p /www
    cp -a /opt/www-seed/. /www/
fi

mkdir -p /www/server/panel/logs /www/wwwroot /www/backup /www/server/panel/config

BT_PORT="${BT_PORT:-7800}"
echo "${BT_PORT}" > /www/server/panel/data/port.pl
rm -f /www/server/panel/data/ssl.pl /www/server/panel/data/domain.pl /www/server/panel/data/admin_path.pl

cat > /www/server/panel/config/cdn.conf <<'EOF'
CDN_PROXY=True
TRUSTED_PROXIES=127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF

BTPY="/www/server/panel/pyenv/bin/python"
if [ ! -x "$BTPY" ]; then
    BTPY="$(command -v btpython || command -v python3 || true)"
fi

if [ -n "${BT_PASS:-}" ] && [ -n "$BTPY" ] && [ -f /www/server/panel/tools.py ]; then
    "$BTPY" /www/server/panel/tools.py panel "${BT_PASS}" || true
fi

service cron start || true
/etc/init.d/bt restart || /etc/init.d/bt start || bt start || true

echo "[diag] GET part of login():"
cd /www/server/panel && "$BTPY" -c "
import sys, inspect; sys.path.insert(0, 'class'); sys.path.insert(0, 'class_v2')
import BTPanel
src = inspect.getsource(BTPanel.login)
idx = src.find('method_get')
for i, l in enumerate(src[idx:].splitlines()[:70]):
    print(f'{i}: {l}')
" || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
