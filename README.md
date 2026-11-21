# aaPanel (Latest 7.x) + Cloudflare Tunnel (`cloudflared`)

A clean, up-to-date Docker image running **aaPanel 7.x** on **Ubuntu 22.04** with **Cloudflare Tunnel (`cloudflared`)** built in—designed for PaaS platforms without a public IP (such as Cranl) while supporting CNAME-based multi-domain hosting.

## Features
- **Latest aaPanel 7.x** installed from the official script (`install_7.0_en.sh`)
- **Cloudflare Tunnel (`cloudflared`)** managed by `supervisord`
- **Persistent `/www` seeding**: automatically seeds `/www` on first boot when mounted to an empty persistent volume
- **Environment-driven config**: configure panel username, password, port, security path, and tunnel token via env vars

## Environment Variables
| Variable | Default | Description |
|---|---|---|
| `TUNNEL_TOKEN` | *(required for tunnel)* | Cloudflare Tunnel token |
| `BT_PORT` | `7800` | aaPanel web UI port |
| `BT_USER` | *(aaPanel default)* | Panel admin username |
| `BT_PASS` | *(aaPanel default)* | Panel admin password |
| `BT_PATH` | *(aaPanel default)* | Panel security entrance path (set `none` to disable) |

## Cloudflare Tunnel Ingress Setup
- `panel.yourdomain.com` -> `http://127.0.0.1:7800`
- Catch-all (`*`) -> `http://127.0.0.1:80` (aaPanel Nginx)

Point any domain/subdomain in your Cloudflare account via `CNAME` to `<TUNNEL_ID>.cfargotunnel.com` (or `edge.yourdomain.com`) and add the site in aaPanel.
