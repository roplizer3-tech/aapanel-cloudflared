#!/usr/bin/env bash
set -e

echo "=== Starting aaPanel + Cloudflare Tunnel Container ==="

# Ensure www and mysql users always exist
groupadd -f www && (id -u www >/dev/null 2>&1 || useradd -g www -s /sbin/nologin www) || true
groupadd -f mysql && (id -u mysql >/dev/null 2>&1 || useradd -g mysql -s /sbin/nologin mysql) || true

# 1. Seed /www if mounted as an empty persistent volume
if [ ! -f /www/server/panel/BT-Panel ]; then
    echo "[Init] Initializing /www from /opt/www_seed ..."
    cp -a /opt/www_seed/. /www/
fi

# 1.5 Persist system directories & shared libs safely (respecting dedicated CranL mountpoints)
PERSIST_DIR="/www/.sys_persist"
mkdir -p "$PERSIST_DIR/init.d" "$PERSIST_DIR/etc" "$PERSIST_DIR/usr_local_lib"

persist_dir_link() {
    local target="$1"
    local store="$2"
    if mountpoint -q "$target" 2>/dev/null; then
        echo "[Persist] $target is already mounted as a dedicated persistent volume."
        return 0
    fi
    if [ ! -L "$target" ]; then
        mkdir -p "$store"
        if [ -d "$target" ] && [ -z "$(ls -A "$store" 2>/dev/null)" ]; then
            cp -a "$target/." "$store/" 2>/dev/null || true
        fi
        rm -rf "$target"
        ln -s "$store" "$target"
    fi
}

persist_dir_link "/root" "$PERSIST_DIR/root"
persist_dir_link "/home" "$PERSIST_DIR/home"
persist_dir_link "/var/spool/cron" "$PERSIST_DIR/cron"

# Restore saved shared libraries & refresh ldconfig
if [ -d "$PERSIST_DIR/usr_local_lib" ]; then
    cp -an "$PERSIST_DIR/usr_local_lib/." /usr/local/lib/ 2>/dev/null || true
fi
printf "/usr/local/lib\n/www/.sys_persist/usr_local_lib\n" > /etc/ld.so.conf.d/aapanel.conf
ldconfig || true

# Restore saved init.d scripts and /etc/my.cnf if present
if [ -d "$PERSIST_DIR/init.d" ]; then
    for s in "$PERSIST_DIR/init.d"/*; do
        [ -f "$s" ] || continue
        base="$(basename "$s")"
        if [ ! -f "/etc/init.d/$base" ]; then
            cp -a "$s" "/etc/init.d/$base"
            chmod +x "/etc/init.d/$base"
        fi
    done
fi
if [ -f "$PERSIST_DIR/etc/my.cnf" ] && [ ! -f /etc/my.cnf ]; then
    cp -a "$PERSIST_DIR/etc/my.cnf" /etc/my.cnf
fi

# Ensure MySQL/MariaDB init script exists if installed in /www/server/mysql
if [ ! -x /etc/init.d/mysqld ] && [ -f /www/server/mysql/support-files/mysql.server ]; then
    cp -a /www/server/mysql/support-files/mysql.server /etc/init.d/mysqld
    chmod +x /etc/init.d/mysqld
fi

# Ensure basic CLI symlinks for installed binaries
[ -x /www/server/nginx/sbin/nginx ] && ln -sf /www/server/nginx/sbin/nginx /usr/bin/nginx || true
[ -x /www/server/mysql/bin/mysql ] && ln -sf /www/server/mysql/bin/mysql /usr/bin/mysql || true
[ -x /www/server/mysql/bin/mysqldump ] && ln -sf /www/server/mysql/bin/mysqldump /usr/bin/mysqldump || true

sync_sys_persist() {
    mkdir -p "$PERSIST_DIR/init.d" "$PERSIST_DIR/etc" "$PERSIST_DIR/usr_local_lib"
    for pat in nginx httpd openlitespeed mysqld mariadb redis memcached php-fpm-*; do
        for s in /etc/init.d/$pat; do
            [ -f "$s" ] && cp -au "$s" "$PERSIST_DIR/init.d/" 2>/dev/null || true
        done
    done
    [ -f /etc/my.cnf ] && cp -au /etc/my.cnf "$PERSIST_DIR/etc/my.cnf" 2>/dev/null || true
    cp -au /usr/local/lib/*.so* "$PERSIST_DIR/usr_local_lib/" 2>/dev/null || true
}

# 2. Configure panel port (default 7800 to match Cloudflare Tunnel)
TARGET_PORT="${PANEL_PORT:-7800}"
echo "$TARGET_PORT" > /www/server/panel/data/port.pl

# 3. Configure panel security entrance
if [ -n "$PANEL_ENTRY" ]; then
    ENTRY_CLEAN="/${PANEL_ENTRY#/}"
    echo "$ENTRY_CLEAN" > /www/server/panel/data/admin_path.pl
fi

# 4. Disable internal panel SSL so Cloudflare Tunnel / CranL proxy terminates HTTPS cleanly
if [ "${PANEL_SSL:-false}" != "true" ]; then
    rm -f /www/server/panel/data/ssl.pl
fi

# 5. Apply custom username/password if provided via environment variables
BT_PY="/www/server/panel/pyenv/bin/python"
[ ! -x "$BT_PY" ] && BT_PY="python3"

if [ -n "$PANEL_USER" ]; then
    echo "[Init] Setting custom panel username..."
    printf "%s\n" "$PANEL_USER" | bt 6 || true
fi

if [ -n "$PANEL_PASS" ]; then
    echo "[Init] Setting custom panel password..."
    cd /www/server/panel && "$BT_PY" tools.py panel "$PANEL_PASS" || true
fi

# 5.5 Disable aaPanel login captcha (username & password only)
echo "[Init] Disabling aaPanel login captcha..."
for f in /www/server/panel/class/userlogin.py /www/server/panel/class_v2/user_login_v2.py; do
    if [ -f "$f" ]; then
        sed -i "s/session\['code'\] = True/session['code'] = False/g" "$f" || true
        sed -i 's/session\["code"\] = True/session["code"] = False/g' "$f" || true
    fi
done
for h in /www/server/panel/BTPanel/templates/default/login.html /www/server/panel/BTPanel/templates/default/login2.html; do
    if [ -f "$h" ]; then
        sed -i "s/checkCodeBox\.classList\.remove('hide');/return;/g" "$h" || true
        sed -i 's/show_check_img();/\/\/ show_check_img disabled/g' "$h" || true
    fi
done

# 6. Start system cron, aaPanel, and all installed web/PHP/DB services
service cron start || true
/etc/init.d/bt start

# Start Nginx (via init.d or direct binary)
if [ -x /etc/init.d/nginx ]; then
    /etc/init.d/nginx start || true
elif [ -x /www/server/nginx/sbin/nginx ]; then
    /www/server/nginx/sbin/nginx -c /www/server/nginx/conf/nginx.conf || true
fi

# Start other installed services
for svc in httpd openlitespeed mysqld mariadb redis memcached; do
    if [ -x "/etc/init.d/$svc" ]; then
        "/etc/init.d/$svc" start || true
    fi
done

# Start all installed PHP-FPM versions
for fpm_init in /etc/init.d/php-fpm-*; do
    [ -x "$fpm_init" ] && "$fpm_init" start || true
done
for php_dir in /www/server/php/*; do
    [ -x "$php_dir/sbin/php-fpm" ] || continue
    ver="$(basename "$php_dir")"
    if ! pgrep -f "php/$ver/sbin/php-fpm" >/dev/null 2>&1; then
        "$php_dir/sbin/php-fpm" --fpm-config "$php_dir/etc/php-fpm.conf" -c "$php_dir/etc/php.ini" || true
    fi
    ln -sf "$php_dir/bin/php" /usr/bin/php || true
done

sync_sys_persist

echo "=== aaPanel Access Info ==="
bt 14 || true
echo "Panel listening on port: $TARGET_PORT"
echo "Panel entry path: $(cat /www/server/panel/data/admin_path.pl 2>/dev/null || echo '/aapanel')"

# 7. Start Cloudflare Tunnel if TUNNEL_TOKEN is configured
if [ -n "$TUNNEL_TOKEN" ]; then
    echo "[Cloudflare] Starting cloudflared tunnel..."
    (
        while true; do
            cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" || true
            echo "[Cloudflare] cloudflared exited, restarting in 5s..."
            sleep 5
        done
    ) &
else
    echo "[Cloudflare] TUNNEL_TOKEN not set yet. Running aaPanel without Cloudflare Tunnel."
fi

# 8. Keep container alive, sync system state, and monitor aaPanel
trap 'sync_sys_persist; /etc/init.d/bt stop; exit 0' SIGTERM SIGINT
tick=0
while true; do
    if ! pgrep -f "BT-Panel" >/dev/null 2>&1; then
        echo "[Monitor] BT-Panel not running, restarting..."
        /etc/init.d/bt start || true
    fi
    tick=$((tick + 1))
    if [ $((tick % 4)) -eq 0 ]; then
        sync_sys_persist
    fi
    sleep 15
done
