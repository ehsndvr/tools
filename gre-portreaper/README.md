# GRE-PortReaper

A practical GRE tunnel port health scanner for Iran/Kharej deployments.

`GRE-PortReaper` is built to answer one specific question with real connectivity checks:

- Which destination ports over my GRE path actually work for TCP and UDP?

Unlike basic port checks, this tool performs active challenge/response validation end-to-end across the tunnel.

## Why This Exists

In some networks, a GRE tunnel may be up, but specific forwarded ports fail intermittently or are filtered by provider/ISP policy, firewall rules, or traffic shaping.

This toolkit helps you quickly identify:

- healthy TCP ports
- healthy UDP ports
- unstable ranges needing reroute or policy changes

## Repository Layout

```text
gre-portreaper/
+-- gre-portreaper-server.sh   # Run on Kharej server (responder + NAT redirect)
+-- gre-portreaper-client.sh   # Run on Iran server (parallel scanner)
+-- README.md
+-- .gitignore
```

## How It Works

1. On Kharej, server script installs temporary `iptables` NAT redirect rules for a target range (TCP+UDP).
2. All packets to that range on GRE destination IP are redirected to local responder ports.
3. Local responder answers signed probes:
   - request: `PH_PING:<nonce>`
   - response: `PH_OK:<same_nonce>`
4. On Iran, client sends probes per port and marks a port healthy only if nonce round-trip matches.

This makes it a real connectivity test, not just SYN open/closed guesswork.

## Requirements

### Kharej (server)
- Linux with root access
- `iptables`
- `python3`
- active GRE interface (e.g. `gre1`)

### Iran (client)
- Linux with root/sudo
- `socat`
- `timeout` (coreutils)
- route to Kharej GRE IP

## Quick Start

### 1) Run responder on Kharej

```bash
sudo bash gre-portreaper-server.sh start \
  --gre-if gre1 \
  --gre-ip 10.80.70.2 \
  --range 1-65535
```

Check status:

```bash
sudo bash gre-portreaper-server.sh status
```

### 2) Run scan from Iran

```bash
sudo bash gre-portreaper-client.sh \
  --peer 10.80.70.2 \
  --range 1-65535 \
  --proto both \
  --workers 250 \
  --timeout 1 \
  --retries-udp 2 \
  --out /root/gre-scan
```

### 3) Read results

- TCP: `/root/gre-scan/good_tcp.txt`
- UDP: `/root/gre-scan/good_udp.txt`

Each file contains one healthy port per line.

### 4) Stop responder on Kharej

```bash
sudo bash gre-portreaper-server.sh stop
```

## CLI Reference

### Server (`gre-portreaper-server.sh`)

```bash
start --gre-if <ifname> --gre-ip <ip> --range <start-end> [--state-dir <dir>] [--tcp-backend-port N] [--udp-backend-port N]
stop  [--state-dir <dir>]
status [--state-dir <dir>]
```

Defaults:
- `state-dir`: `/var/run/gre-portreaper`
- TCP backend responder: `19001`
- UDP backend responder: `19002`

### Client (`gre-portreaper-client.sh`)

```bash
--peer <ip> --range <start-end> [--proto tcp|udp|both] [--timeout N] [--workers N] [--retries-udp N] [--out <dir>]
```

Defaults:
- `proto`: `both`
- `timeout`: `1` sec
- `workers`: `200`
- `retries-udp`: `2`
- `out`: `./scan-result`

## Practical Scan Examples

Full TCP+UDP scan:

```bash
sudo bash gre-portreaper-client.sh --peer 10.80.70.2 --range 1-65535 --proto both --workers 200 --out ./result-all
```

Panel-only range:

```bash
sudo bash gre-portreaper-client.sh --peer 10.80.70.2 --range 2000-2100 --proto both --workers 80 --out ./result-panel
```

UDP-only verification:

```bash
sudo bash gre-portreaper-client.sh --peer 10.80.70.2 --range 10000-20000 --proto udp --retries-udp 3 --out ./result-udp
```

## Tuning Guidelines

- Start with `workers=80..200` for stability.
- Use `workers=250+` only on strong CPU/network paths.
- For lossy UDP networks, increase:
  - `--timeout` to `2`
  - `--retries-udp` to `3` or `4`

## Safety Notes

- Server script modifies `iptables -t nat PREROUTING` for selected range.
- Always run `stop` after scanning to clean rules.
- Avoid overlapping with production NAT rules without planning.

## Troubleshooting

No healthy ports found:
- confirm GRE is up on both ends (`ip a`, `ip tunnel show`)
- verify route to peer GRE IP
- check host firewall and provider security rules
- reduce workers and retry

TCP works but UDP empty:
- increase UDP retries/timeouts
- verify provider/ISP UDP filtering

`Missing command` error:
- install required package (`socat`, `python3`, `iptables`, `coreutils`)

## License

Use internally or modify for your own infrastructure workflows.