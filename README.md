# EHSNDVR Tools

A curated collection of practical DevOps and server automation tools by **EHSNDVR**.

This repository is built for two goals:
- Make daily infrastructure tasks fast for myself.
- Share production-friendly tools that others can use immediately.

## Featured Tool

### `ezssl` - Easy SSL for any domain + any port (Nginx + Let's Encrypt)

`ezssl` is a terminal assistant that helps you set up HTTPS on a server with minimal steps.

What it does:
- Opens an interactive setup menu for fast onboarding
- Asks for domain, backend port, and email (or accepts flags)
- Creates Nginx reverse-proxy config
- Requests SSL cert with Certbot (`--nginx`)
- Enables HTTPS redirect automatically

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ehsndvr/tools/main/ezssl/ehsndvr-ezssl.sh | sudo bash
```

One-line with explicit flags:
```bash
curl -fsSL https://raw.githubusercontent.com/ehsndvr/tools/main/ezssl/ehsndvr-ezssl.sh | sudo bash -s -- --domain app.example.com --port 3000 --email you@example.com --non-interactive
```

Alternative (clone then run):

```bash
git clone https://github.com/ehsndvr/tools.git
cd tools/ezssl
sudo ./ehsndvr-ezssl.sh
```

Non-interactive usage:

```bash
sudo ./ehsndvr-ezssl.sh \
  --domain app.example.com \
  --port 3000 \
  --email you@example.com
```

## Requirements

- Linux server with public IP
- DNS A/AAAA record pointing your domain to server
- Open ports `80` and `443`
- `sudo` / root access

## Repository Structure

```text
tools/
└── ezssl/
    ├── ehsndvr-ezssl.sh
    └── README.md
```

## Security Notes

- Keep your server updated.
- Use firewall rules to allow only required ports.
- Prefer running application services behind localhost (`127.0.0.1`) and expose only Nginx.

## Contributing

Issues and pull requests are welcome.
If you have ideas for new automation scripts, open an issue with:
- use case
- target OS/distro
- expected input/output

## Roadmap

- More one-command server setup utilities
- Monitoring and log helper scripts
- Backup and restore assistants

## Author

Built by **EHSNDVR**.

If this repo helps you, give it a star on GitHub.
