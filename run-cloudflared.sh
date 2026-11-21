#!/usr/bin/env bash
set -euo pipefail

if [ -z "${TUNNEL_TOKEN:-}" ]; then
    echo "[cloudflared] TUNNEL_TOKEN is not set; idling without tunnel."
    exec tail -f /dev/null
fi

echo "[cloudflared] Starting Cloudflare Tunnel..."
exec cloudflared tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}"
