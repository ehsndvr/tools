# EHSNDVR EZSSL

A small shell assistant to set up Nginx reverse proxy + Let's Encrypt SSL for any domain and backend port.

## What it does
- Provides a professional interactive menu (default in interactive mode)
- Prompts for `domain`, `port`, and `email` (or accepts flags)
- Creates Nginx reverse proxy config
- Runs `certbot --nginx` to issue SSL cert and force HTTPS redirect
- Reloads Nginx

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
--app-host 127.0.0.1
--menu
--non-interactive
```

## Requirements
- Public DNS for your domain points to this server
- Ports `80` and `443` are open
- Run as `root`/`sudo`

## Notes
- Config files include `EHSNDVR` marker
- Supports common Nginx layouts:
  - `/etc/nginx/sites-available` + `/etc/nginx/sites-enabled`
  - `/etc/nginx/conf.d`
