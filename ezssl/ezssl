#!/usr/bin/env bash
set -euo pipefail

# EHSNDVR EZSSL: one-command SSL setup for Nginx reverse proxy.

TAG="EHSNDVR"
DOMAIN=""
PORT=""
EMAIL=""
APP_HOST="127.0.0.1"
NON_INTERACTIVE="false"
USE_MENU="false"
TTY_FD=0

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log() {
  echo -e "[${TAG}] $*"
}

ok() {
  echo -e "${GREEN}[${TAG}] $*${NC}"
}

warn() {
  echo -e "${YELLOW}[${TAG}] $*${NC}"
}

err() {
  echo -e "${RED}[${TAG}] $*${NC}" >&2
}

usage() {
  cat <<USAGE
EHSNDVR EZSSL - Nginx + Let's Encrypt assistant

Usage:
  $0 [options]

Options:
  --domain <domain>       Domain name (example.com)
  --port <port>           Backend app port (1-65535)
  --email <email>         Email for Let's Encrypt registration
  --app-host <host>       Backend app host (default: 127.0.0.1)
  --menu                  Open interactive menu
  --non-interactive       Run without prompts (auto-installs dependencies)
  -h, --help              Show this help

Examples:
  $0
  $0 --domain app.example.com --port 3000 --email you@example.com
USAGE
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Please run as root (sudo)."
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

setup_tty() {
  if [[ -t 0 ]]; then
    TTY_FD=0
    return
  fi

  if [[ -r /dev/tty ]]; then
    exec 3</dev/tty
    TTY_FD=3
    return
  fi

  err "Interactive mode needs a TTY. Use --non-interactive with flags."
  exit 1
}

prompt_line() {
  local label="$1"
  local default="${2:-}"
  local value=""

  if [[ -n "${default}" ]]; then
    read -r -u "${TTY_FD}" -p "${label} [${default}]: " value || true
    if [[ -z "${value}" ]]; then
      value="${default}"
    fi
  else
    read -r -u "${TTY_FD}" -p "${label}: " value || true
  fi

  echo "${value}"
}

show_banner() {
  clear || true
  cat <<BANNER
${CYAN}${BOLD}
=====================================================
                EHSNDVR EZSSL ASSISTANT
      Nginx Reverse Proxy + Let's Encrypt SSL
=====================================================
${NC}
BANNER
}

show_menu() {
  show_banner
  cat <<MENU
${BLUE}${BOLD}Choose an option:${NC}
  1) Setup SSL (domain + port)
  2) Show help
  3) Exit
MENU
}

run_interactive_menu() {
  local choice=""
  while true; do
    show_menu
    choice="$(prompt_line "Enter choice (1-3)")"
    case "${choice}" in
      1)
        DOMAIN="$(prompt_line "Domain (e.g. app.example.com)")"
        PORT="$(prompt_line "Backend app port (e.g. 3000)")"
        EMAIL="$(prompt_line "Email for Let's Encrypt")"
        APP_HOST="$(prompt_line "Backend app host" "127.0.0.1")"
        break
        ;;
      2)
        usage
        echo
        read -r -u "${TTY_FD}" -p "Press Enter to return to menu..." _ || true
        ;;
      3)
        log "Exit."
        exit 0
        ;;
      *)
        warn "Invalid choice. Please select 1, 2, or 3."
        sleep 1
        ;;
    esac
  done
}

prompt_if_missing() {
  if [[ -z "${DOMAIN}" ]]; then
    DOMAIN="$(prompt_line "Domain (e.g. app.example.com)")"
  fi

  if [[ -z "${PORT}" ]]; then
    PORT="$(prompt_line "Backend app port (e.g. 3000)")"
  fi

  if [[ -z "${EMAIL}" ]]; then
    EMAIL="$(prompt_line "Email for Let's Encrypt")"
  fi

  if [[ -z "${APP_HOST}" ]]; then
    APP_HOST="$(prompt_line "Backend app host" "127.0.0.1")"
  fi
}

validate_inputs() {
  if [[ -z "${DOMAIN}" || -z "${PORT}" || -z "${EMAIL}" ]]; then
    err "Missing required values. Use --help for options."
    exit 1
  fi

  if [[ ! "${DOMAIN}" =~ ^[A-Za-z0-9.-]+$ ]]; then
    err "Invalid domain format: ${DOMAIN}"
    exit 1
  fi

  if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    err "Port must be a number between 1 and 65535."
    exit 1
  fi

  if [[ ! "${EMAIL}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    err "Invalid email format: ${EMAIL}"
    exit 1
  fi

  if [[ ! "${APP_HOST}" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    err "Invalid app host format: ${APP_HOST}"
    exit 1
  fi
}

install_packages_if_needed() {
  local missing=()

  command_exists nginx || missing+=("nginx")
  command_exists certbot || missing+=("certbot")

  # certbot nginx plugin names differ by distro
  if ! dpkg -s python3-certbot-nginx >/dev/null 2>&1 &&
     ! rpm -q python3-certbot-nginx >/dev/null 2>&1 &&
     ! rpm -q certbot-nginx >/dev/null 2>&1; then
    missing+=("certbot-nginx-plugin")
  fi

  if (( ${#missing[@]} == 0 )); then
    return
  fi

  warn "Missing dependencies: ${missing[*]}"

  if [[ "${NON_INTERACTIVE}" != "true" ]]; then
    INSTALL_CONFIRM="$(prompt_line "Try to install missing packages automatically? [Y/n]" "Y")"
    INSTALL_CONFIRM="${INSTALL_CONFIRM:-Y}"
    if [[ ! "${INSTALL_CONFIRM}" =~ ^[Yy]$ ]]; then
      err "Install required packages and re-run."
      exit 1
    fi
  else
    log "Non-interactive mode: auto-installing missing dependencies."
  fi

  if command_exists apt-get; then
    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx
  elif command_exists dnf; then
    dnf install -y nginx certbot python3-certbot-nginx
  elif command_exists yum; then
    yum install -y epel-release || true
    yum install -y nginx certbot python3-certbot-nginx || yum install -y nginx certbot certbot-nginx
  else
    err "Unsupported package manager. Install nginx, certbot, and certbot nginx plugin manually."
    exit 1
  fi
}

resolve_nginx_paths() {
  if [[ -d /etc/nginx/sites-available && -d /etc/nginx/sites-enabled ]]; then
    NGINX_CONF_DIR="/etc/nginx/sites-available"
    NGINX_ENABLE_DIR="/etc/nginx/sites-enabled"
    CONF_FILE="${NGINX_CONF_DIR}/${DOMAIN}.conf"
    ENABLE_FILE="${NGINX_ENABLE_DIR}/${DOMAIN}.conf"
  elif [[ -d /etc/nginx/conf.d ]]; then
    NGINX_CONF_DIR="/etc/nginx/conf.d"
    NGINX_ENABLE_DIR=""
    CONF_FILE="${NGINX_CONF_DIR}/${DOMAIN}.conf"
    ENABLE_FILE=""
  else
    err "Unable to find a standard Nginx config directory."
    exit 1
  fi
}

write_nginx_config() {
  cat > "${CONF_FILE}" <<CONF
# Managed by ${TAG}
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    client_max_body_size 64m;

    location / {
        proxy_pass http://${APP_HOST}:${PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
CONF

  if [[ -n "${ENABLE_FILE}" ]]; then
    ln -sfn "${CONF_FILE}" "${ENABLE_FILE}"
  fi

  if nginx -t; then
    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl reload nginx
    ok "Nginx config created and reloaded for ${DOMAIN}"
  else
    err "Nginx configuration test failed."
    exit 1
  fi
}

request_certificate() {
  log "Requesting SSL certificate from Let's Encrypt..."

  certbot --nginx \
    -d "${DOMAIN}" \
    --non-interactive \
    --agree-tos \
    -m "${EMAIL}" \
    --redirect

  if nginx -t; then
    systemctl reload nginx
    ok "SSL is enabled: https://${DOMAIN}"
  else
    err "Nginx test failed after Certbot changes."
    exit 1
  fi
}

print_checks() {
  cat <<INFO

[${TAG}] Done.
- Domain: ${DOMAIN}
- Backend: http://${APP_HOST}:${PORT}
- Nginx config: ${CONF_FILE}

If SSL failed, verify:
1. DNS A/AAAA records for ${DOMAIN} point to this server.
2. Ports 80 and 443 are open in firewall/security groups.
3. Nginx is reachable from the public internet.
INFO
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain)
        DOMAIN="${2:-}"
        shift 2
        ;;
      --port)
        PORT="${2:-}"
        shift 2
        ;;
      --email)
        EMAIL="${2:-}"
        shift 2
        ;;
      --app-host)
        APP_HOST="${2:-}"
        shift 2
        ;;
      --menu)
        USE_MENU="true"
        shift
        ;;
      --non-interactive)
        NON_INTERACTIVE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_root

  if [[ "${NON_INTERACTIVE}" != "true" ]]; then
    setup_tty

    if [[ "${USE_MENU}" == "true" ]]; then
      run_interactive_menu
    elif [[ $# -eq 0 && -z "${DOMAIN}" && -z "${PORT}" && -z "${EMAIL}" ]]; then
      # Default to menu for no-argument interactive runs.
      run_interactive_menu
    else
      prompt_if_missing
    fi
  fi

  validate_inputs
  install_packages_if_needed
  resolve_nginx_paths
  write_nginx_config
  request_certificate
  print_checks
}

main "$@"
