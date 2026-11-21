#!/usr/bin/env bash
set -euo pipefail

BT_PORT="${BT_PORT:-7800}"
curl -fsS -o /dev/null --max-time 5 "http://127.0.0.1:${BT_PORT}" || exit 1

if [ -n "${TUNNEL_TOKEN:-}" ]; then
    pgrep -x cloudflared >/dev/null || exit 1
fi
