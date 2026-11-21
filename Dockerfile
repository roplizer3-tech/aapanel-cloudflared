FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BT_PORT=7800

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    gnupg \
    sudo \
    net-tools \
    iproute2 \
    procps \
    lsof \
    cron \
    supervisor \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install latest official cloudflared
RUN curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb \
    && dpkg -i /tmp/cloudflared.deb \
    && rm -f /tmp/cloudflared.deb

# Install latest official aaPanel (7.x) non-interactively
RUN curl -ksSO https://www.aapanel.com/script/install_7.0_en.sh \
    && printf "y\nn\n" | bash install_7.0_en.sh aapanel \
    && rm -f install_7.0_en.sh

# Seed /www for persistent volume initialization on first boot
RUN mkdir -p /opt/www-seed \
    && cp -a /www/. /opt/www-seed/

COPY supervisord.conf /etc/supervisor/conf.d/aapanel-cloudflared.conf
COPY run-cloudflared.sh /usr/local/bin/run-cloudflared.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/run-cloudflared.sh /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 80 443 7800

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
