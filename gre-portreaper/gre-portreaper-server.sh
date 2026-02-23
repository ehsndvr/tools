#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/run/gre-portreaper"
CMD="${1:-}"
shift || true

GRE_IF=""
GRE_IP=""
RANGE=""
TCP_BACKEND_PORT=19001
UDP_BACKEND_PORT=19002

usage() {
  cat <<EOF
Usage:
  $0 start --gre-if gre1 --gre-ip 10.80.70.2 --range 1-65535 [--state-dir /var/run/gre-portreaper]
  $0 stop  [--state-dir /var/run/gre-portreaper]
  $0 status [--state-dir /var/run/gre-portreaper]
EOF
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || { echo "Run as root"; exit 1; }
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gre-if) GRE_IF="$2"; shift 2 ;;
      --gre-ip) GRE_IP="$2"; shift 2 ;;
      --range) RANGE="$2"; shift 2 ;;
      --state-dir) STATE_DIR="$2"; shift 2 ;;
      --tcp-backend-port) TCP_BACKEND_PORT="$2"; shift 2 ;;
      --udp-backend-port) UDP_BACKEND_PORT="$2"; shift 2 ;;
      *) echo "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done
}

validate_range() {
  [[ "$RANGE" =~ ^([0-9]+)-([0-9]+)$ ]] || { echo "Invalid --range"; exit 1; }
  START="${BASH_REMATCH[1]}"
  END="${BASH_REMATCH[2]}"
  (( START >= 1 && END <= 65535 && START <= END )) || { echo "Invalid range bounds"; exit 1; }
}

rule_exists() {
  local proto="$1"
  iptables -t nat -C PREROUTING -i "$GRE_IF" -p "$proto" -d "$GRE_IP" --dport "$START:$END" -j REDIRECT --to-ports "$2" >/dev/null 2>&1
}

add_rule() {
  local proto="$1" to_port="$2"
  if ! rule_exists "$proto" "$to_port"; then
    iptables -t nat -A PREROUTING -i "$GRE_IF" -p "$proto" -d "$GRE_IP" --dport "$START:$END" -j REDIRECT --to-ports "$to_port"
  fi
}

del_rule() {
  local proto="$1" to_port="$2"
  while iptables -t nat -C PREROUTING -i "$GRE_IF" -p "$proto" -d "$GRE_IP" --dport "$START:$END" -j REDIRECT --to-ports "$to_port" >/dev/null 2>&1; do
    iptables -t nat -D PREROUTING -i "$GRE_IF" -p "$proto" -d "$GRE_IP" --dport "$START:$END" -j REDIRECT --to-ports "$to_port"
  done
}

start_server() {
  require_root
  need_cmd iptables
  need_cmd python3
  parse_args "$@"
  [[ -n "$GRE_IF" && -n "$GRE_IP" && -n "$RANGE" ]] || { usage; exit 1; }
  validate_range

  mkdir -p "$STATE_DIR"
  cat >"$STATE_DIR/config.env" <<EOF
GRE_IF=$GRE_IF
GRE_IP=$GRE_IP
RANGE=$RANGE
START=$START
END=$END
TCP_BACKEND_PORT=$TCP_BACKEND_PORT
UDP_BACKEND_PORT=$UDP_BACKEND_PORT
EOF

  add_rule tcp "$TCP_BACKEND_PORT"
  add_rule udp "$UDP_BACKEND_PORT"

  cat >"$STATE_DIR/responder.py" <<'PY'
import socket, threading

TCP_PORT = 19001
UDP_PORT = 19002

def tcp_worker(c):
    try:
        data = c.recv(256).decode(errors="ignore").strip()
        if data.startswith("PH_PING:"):
            nonce = data.split(":", 1)[1]
            c.sendall(f"PH_OK:{nonce}\n".encode())
    finally:
        c.close()

def tcp_server():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", TCP_PORT))
    s.listen(512)
    while True:
        c, _ = s.accept()
        threading.Thread(target=tcp_worker, args=(c,), daemon=True).start()

def udp_server():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", UDP_PORT))
    while True:
        data, addr = s.recvfrom(512)
        msg = data.decode(errors="ignore").strip()
        if msg.startswith("PH_PING:"):
            nonce = msg.split(":", 1)[1]
            s.sendto(f"PH_OK:{nonce}\n".encode(), addr)

if __name__ == "__main__":
    import os
    TCP_PORT = int(os.environ.get("TCP_BACKEND_PORT", "19001"))
    UDP_PORT = int(os.environ.get("UDP_BACKEND_PORT", "19002"))
    threading.Thread(target=tcp_server, daemon=True).start()
    udp_server()
PY

  if [[ -f "$STATE_DIR/responder.pid" ]] && kill -0 "$(cat "$STATE_DIR/responder.pid")" >/dev/null 2>&1; then
    echo "Responder already running"
  else
    TCP_BACKEND_PORT="$TCP_BACKEND_PORT" UDP_BACKEND_PORT="$UDP_BACKEND_PORT" \
      nohup python3 "$STATE_DIR/responder.py" >/dev/null 2>&1 &
    echo $! >"$STATE_DIR/responder.pid"
  fi

  echo "Server started. Range=$RANGE GRE_IF=$GRE_IF GRE_IP=$GRE_IP"
}

stop_server() {
  require_root
  parse_args "$@"
  if [[ -f "$STATE_DIR/config.env" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_DIR/config.env"
    del_rule tcp "$TCP_BACKEND_PORT" || true
    del_rule udp "$UDP_BACKEND_PORT" || true
  fi
  if [[ -f "$STATE_DIR/responder.pid" ]]; then
    kill "$(cat "$STATE_DIR/responder.pid")" >/dev/null 2>&1 || true
    rm -f "$STATE_DIR/responder.pid"
  fi
  echo "Server stopped."
}

status_server() {
  parse_args "$@"
  if [[ -f "$STATE_DIR/config.env" ]]; then
    cat "$STATE_DIR/config.env"
  else
    echo "No config"
  fi
  if [[ -f "$STATE_DIR/responder.pid" ]] && kill -0 "$(cat "$STATE_DIR/responder.pid")" >/dev/null 2>&1; then
    echo "Responder: running (pid $(cat "$STATE_DIR/responder.pid"))"
  else
    echo "Responder: stopped"
  fi
}

case "$CMD" in
  start) start_server "$@" ;;
  stop) stop_server "$@" ;;
  status) status_server "$@" ;;
  *) usage; exit 1 ;;
esac
