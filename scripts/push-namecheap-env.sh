#!/usr/bin/env bash

# Render Namecheap DNS credentials from 1Password and push them to the Hetzner
# server so Caddy can solve DNS-01 challenges for *.justinmoon.com.

set -euo pipefail

REMOTE=${REMOTE:-"justin@135.181.179.143"}
API_USER=stockninja
CLIENT_IP=135.181.179.143
REMOTE_PATH="/etc/secrets/namecheap-dns.env"
TMP_LOCAL=$(mktemp)
TMP_REMOTE="/tmp/namecheap-dns.env.$RANDOM"

cleanup() {
  [[ -f "$TMP_LOCAL" ]] && rm -f "$TMP_LOCAL"
}
trap cleanup EXIT

if ! command -v op >/dev/null 2>&1; then
  echo "1Password CLI (op) not installed" >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1 || ! command -v scp >/dev/null 2>&1; then
  echo "ssh and scp are required" >&2
  exit 1
fi

log() {
  printf '[sync] %s\n' "$*"
}

log "rendering secrets with 1Password"

cat <<EOF >"$TMP_LOCAL"
NAMECHEAP_API_USER=$API_USER
NAMECHEAP_API_KEY=$(op read op://cli/namecheap/api_key)
NAMECHEAP_CLIENT_IP=$CLIENT_IP
EOF

log "copying temp file to $REMOTE:$TMP_REMOTE"
scp "$TMP_LOCAL" "$REMOTE:$TMP_REMOTE" >/dev/null

log "installing secrets at $REMOTE_PATH"
ssh "$REMOTE" <<EOF
  set -euo pipefail
  sudo install -D -o root -g caddy -m 640 "$TMP_REMOTE" "$REMOTE_PATH"
  sudo rm -f "$TMP_REMOTE"
EOF

log "done. restart Caddy after nixos-rebuild"
