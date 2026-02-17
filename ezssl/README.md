# EHSNDVR EZSSL

A small shell assistant to set up Nginx reverse proxy + Let's Encrypt SSL for any domain and backend port.

## What it does
- Provides a professional interactive menu (default in interactive mode)
- Prompts for `domain`, `port`, and `email` (or accepts flags)
- Auto-detects and shows server primary IP
- Creates Nginx reverse proxy config
- Runs `certbot --nginx` to issue SSL cert and force HTTPS redirect
- Reloads Nginx
- Shows SSL file paths after successful issuance
- Caches last used values (except domain) for next runs

## One-line install and run
```bash
curl -fsSL https://raw.githubusercontent.com/ehsndvr/tools/main/ezssl/ezssl | sudo bash
```

One-line with explicit flags:
```bash
curl -fsSL https://raw.githubusercontent.com/ehsndvr/tools/main/ezssl/ezssl | sudo bash -s -- --domain app.example.com --port 3000 --email you@example.com --non-interactive
```

## Alternative (clone then run)
```bash
git clone https://github.com/ehsndvr/tools.git
cd tools/ezssl
sudo ./ezssl
```

## Non-interactive usage
```bash
sudo ./ezssl \
  --domain app.example.com \
  --port 3000 \
  --email you@example.com
```

Optional:
```bash
--app-host <custom-backend-host>
--menu
--non-interactive
--cleanup-first
--cleanup-only
```

## Requirements
- Public DNS for your domain points to this server
- Ports `80` and `443` are open
- Run as `root`/`sudo`

## Notes
- Config files include `EHSNDVR` marker
- Default `app-host` is auto-detected server primary IP
- SSL files are stored in `/etc/letsencrypt/live/<your-domain>/`
- If a domain is already configured, script can cleanup and reinstall
- Cache file: `/etc/ezssl/cache.env` (stores `PORT`, `EMAIL`, `APP_HOST`)
- Registry file: `/etc/ezssl/registry.tsv` (used to prevent domain/port conflicts)
- You can add more domains without cleanup; script blocks reuse of an existing port by another domain
- Supports common Nginx layouts:
  - `/etc/nginx/sites-available` + `/etc/nginx/sites-enabled`
  - `/etc/nginx/conf.d`
