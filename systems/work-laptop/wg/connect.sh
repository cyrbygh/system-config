#!/bin/bash
set -e

REMOTE_PORT=54321

wstunnel_port=0

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Start WireGuard VPN with UDP or TCP transport.

ENV:
    REMOTE_HOST     Address of the remote host to connect to.
    PRIVATE_KEY     The private key to use.

OPTIONS:
    --help          Show this help message and exit
    --use-tcp       Use TCP WebSocket tunnel instead of direct UDP.

DESCRIPTION:
    This script establishes a WireGuard VPN connection using either:
    - Direct UDP connection to the remote host (default).
    - TCP WebSocket tunnel if UDP is blocked (--use-tcp).

    Press Ctrl+C to cleanly shut down all connections.

EXAMPLES:
    $(basename "$0")             # Direct UDP connection (default)
    $(basename "$0") --use-tcp   # TCP WebSocket tunnel

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      exit 0
      ;;
    --use-tcp)
      wstunnel_port="$((RANDOM % 10000 + 50000))"
      shift
      ;;
    *)
      echo "Error: Unknown option ${1}"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

cleanup() {
  # Redefine to only allow this to run once.
  cleanup() { :; }

  echo "Shutting down WireGuard..."
  if [[ -n "${wg_if}" ]]; then
    sudo wg-quick down "${wg_conf}" || true
  fi

  # Clean up temporary config file.
  rm -f "${wg_conf}"

  # Clean up tunnel processes if TCP mode was used.
  if [[ "${wstunnel_port}" != 0 ]]; then
    echo "Shutting down wstunnel..."
    pkill -f "wstunnel.*wss://${REMOTE_HOST}" || true
  fi

  echo "Done."
}

trap cleanup SIGINT SIGTERM EXIT

if [[ "${wstunnel_port}" != 0 ]]; then
  echo "Using TCP connection."

  if ! command -v wstunnel &> /dev/null; then
      echo "Error: wstunnel is not installed. Please install wstunnel to use TCP transport."
      echo "See: https://github.com/erebe/wstunnel for installation instructions."
      exit 1
  fi

  wstunnel client --local-to-remote udp://${wstunnel_port}:${REMOTE_HOST}:${REMOTE_PORT} --http-upgrade-path-prefix "vpn" "wss://${REMOTE_HOST}" &

  # Give tunnel time to establish.
  sleep 2

  wg_endpoint="127.0.0.1:${wstunnel_port}"
else
  echo "Using UDP connection (direct)."
  wg_endpoint="${REMOTE_HOST}:${REMOTE_PORT}"
fi

echo ""
echo "Bringing up WireGuard interface."
echo ""

if ! command -v wg-quick &> /dev/null; then
    echo "Error: wg-quick is not installed. Please install WireGuard."
    exit 1
fi

wg_conf="$(mktemp).conf"

cat > "${wg_conf}" << EOF
[Interface]
# Public key is c8rwA12t1V3V20sZsLjyXs1Em91E84Tos3D51lfKXhs=.
PrivateKey = ${PRIVATE_KEY}
Address = 10.77.67.100/32

[Peer]
PublicKey = NFg8Pkes/lBBoUkM5qUXHW1bCcZl87XUrxCDlExVQE8=
Endpoint = ${wg_endpoint}
AllowedIPs = 10.215.10.0/24, 10.215.20.0/24, 10.215.30.0/24, 10.215.40.0/24, 10.215.50.0/24
EOF

wg_output=$(sudo wg-quick up "${wg_conf}" 2>&1)
wg_if=$(echo "${wg_output}" | grep "Interface for" | awk '{print $NF}')

echo "${wg_output}"

echo ""
echo "Tunnel active on ${wg_if}. Press Ctrl+C to shut down."
while true; do sleep 60; done
