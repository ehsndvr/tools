#!/usr/bin/env bash
set -euo pipefail

PEER=""
RANGE=""
PROTO="both"      # tcp|udp|both
TIMEOUT=1
WORKERS=200
RETRIES_UDP=2
OUT_DIR="./scan-result"

usage() {
  cat <<EOF
Usage:
  $0 --peer 10.80.70.2 --range 1-65535 [--proto both] [--timeout 1] [--workers 200] [--retries-udp 2] [--out ./scan-result]
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --peer) PEER="$2"; shift 2 ;;
      --range) RANGE="$2"; shift 2 ;;
      --proto) PROTO="$2"; shift 2 ;;
      --timeout) TIMEOUT="$2"; shift 2 ;;
      --workers) WORKERS="$2"; shift 2 ;;
      --retries-udp) RETRIES_UDP="$2"; shift 2 ;;
      --out) OUT_DIR="$2"; shift 2 ;;
      *) echo "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done
}

validate() {
  [[ -n "$PEER" && -n "$RANGE" ]] || { usage; exit 1; }
  [[ "$PROTO" =~ ^(tcp|udp|both)$ ]] || { echo "Invalid --proto"; exit 1; }
  [[ "$RANGE" =~ ^([0-9]+)-([0-9]+)$ ]] || { echo "Invalid --range"; exit 1; }
  START="${BASH_REMATCH[1]}"
  END="${BASH_REMATCH[2]}"
  (( START >= 1 && END <= 65535 && START <= END )) || { echo "Invalid range bounds"; exit 1; }
  (( WORKERS >= 1 )) || { echo "workers must be >=1"; exit 1; }
}

scan_tcp() {
  local p="$1"
  local nonce="${p}-$(date +%s%N)-$RANDOM"
  local resp
  resp="$(printf 'PH_PING:%s\n' "$nonce" | timeout "${TIMEOUT}s" socat -T "$TIMEOUT" - "TCP4:${PEER}:${p},connect-timeout=${TIMEOUT}" 2>/dev/null | tr -d '\r' | head -n1 || true)"
  [[ "$resp" == "PH_OK:${nonce}" ]] && echo "$p" >>"$GOOD_TCP"
}

scan_udp() {
  local p="$1"
  local i nonce resp
  for ((i=1; i<=RETRIES_UDP; i++)); do
    nonce="${p}-${i}-$(date +%s%N)-$RANDOM"
    resp="$(printf 'PH_PING:%s\n' "$nonce" | timeout "${TIMEOUT}s" socat -T "$TIMEOUT" - "UDP4:${PEER}:${p}" 2>/dev/null | tr -d '\r' | head -n1 || true)"
    if [[ "$resp" == "PH_OK:${nonce}" ]]; then
      echo "$p" >>"$GOOD_UDP"
      return 0
    fi
  done
  return 1
}

run_parallel() {
  local mode="$1"
  local p
  for ((p=START; p<=END; p++)); do
    while (( $(jobs -rp | wc -l) >= WORKERS )); do
      wait -n || true
    done
    if [[ "$mode" == "tcp" ]]; then
      scan_tcp "$p" &
    else
      scan_udp "$p" &
    fi
  done
  wait
}

main() {
  parse_args "$@"
  validate
  need_cmd socat
  need_cmd timeout

  mkdir -p "$OUT_DIR"
  GOOD_TCP="$OUT_DIR/good_tcp.txt"
  GOOD_UDP="$OUT_DIR/good_udp.txt"
  >"$GOOD_TCP"
  >"$GOOD_UDP"

  echo "Scanning $PEER range=$RANGE proto=$PROTO workers=$WORKERS timeout=${TIMEOUT}s"

  if [[ "$PROTO" == "tcp" || "$PROTO" == "both" ]]; then
    run_parallel tcp
    sort -n -u "$GOOD_TCP" -o "$GOOD_TCP"
  fi
  if [[ "$PROTO" == "udp" || "$PROTO" == "both" ]]; then
    run_parallel udp
    sort -n -u "$GOOD_UDP" -o "$GOOD_UDP"
  fi

  echo "Done."
  [[ -s "$GOOD_TCP" ]] && echo "TCP good ports -> $GOOD_TCP" || echo "TCP good ports -> none"
  [[ -s "$GOOD_UDP" ]] && echo "UDP good ports -> $GOOD_UDP" || echo "UDP good ports -> none"
}

main "$@"
