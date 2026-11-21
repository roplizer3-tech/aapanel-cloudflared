FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PANEL_PORT=7800 \
    PANEL_ENTRY=/aapanel

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates gnupg sudo cron net-tools iproute2 \
    lsof procps locales tzdata unzip tar git lsb-release \
    python3 iputils-ping nano \
    libjemalloc2 libluajit-5.1-2 libonig5 libwebp7 libgd3 libxml2 libxslt1.1 \
    libncurses6 libnuma1 libicu-dev libcurl4 libssl3 libfreetype6 \
    libjpeg-turbo8 libsodium23 libargon2-1 libaio1t64 libzip4t64 libpng16-16t64 \
    && rm -rf /var/lib/apt/lists/*

# Install libicu60 runtime for aaPanel prebuilt PHP binaries (e.g. libicuio.so.60)
RUN curl -fsSL http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu60_60.2-3ubuntu3.2_amd64.deb -o /tmp/libicu60.deb \
    && dpkg -i /tmp/libicu60.deb || true \
    && rm -f /tmp/libicu60.deb \
    && ldconfig

# Ensure www and mysql system users always exist across redeploys
RUN groupadd -f www && (id -u www >/dev/null 2>&1 || useradd -g www -s /sbin/nologin www) && \
    groupadd -f mysql && (id -u mysql >/dev/null 2>&1 || useradd -g mysql -s /sbin/nologin mysql)

# Install latest cloudflared binary
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install latest aaPanel (Free edition) non-interactively
RUN curl -ksSO https://www.aapanel.com/script/install_panel_en.sh && \
    printf "y\nn\n" | bash install_panel_en.sh && \
    rm -f install_panel_en.sh && \
    rm -f /www/server/panel/data/ssl.pl && \
    echo "7800" > /www/server/panel/data/port.pl && \
    echo "/aapanel" > /www/server/panel/data/admin_path.pl && \
    /etc/init.d/bt stop || true

# Move /www to /opt/www_seed so mounting an empty persistent volume at /www works cleanly
RUN mv /www /opt/www_seed && mkdir -p /www

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7800 80 443 888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
