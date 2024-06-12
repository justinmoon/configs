#!/usr/bin/env bash
# Install NixOS on Hetzner dedicated servers using nixos-anywhere
# This script wipes the server and performs a fresh NixOS installation
# Prerequisites: Server must be booted into rescue mode from Hetzner Robot panel

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if IP address is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No server IP address provided${NC}"
    echo "Usage: $0 <server-ip> [disk-device]"
    echo "Example: $0 192.168.1.100"
    echo "Example with disk: $0 192.168.1.100 /dev/nvme0n1"
    exit 1
fi

SERVER_IP=$1

echo -e "${GREEN}Deploying NixOS to Hetzner server at ${SERVER_IP}${NC}"
echo -e "${YELLOW}Server: AMD Ryzen 7 3700X with 2x 1TB NVMe${NC}"

# Skip local build on Mac - nixos-anywhere will build on the target
# Deploy with nixos-anywhere
echo -e "${YELLOW}Starting nixos-anywhere deployment...${NC}"
echo -e "${YELLOW}This will ERASE ALL DATA on both NVMe drives at ${SERVER_IP}${NC}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

# Run nixos-anywhere
# Disk devices are already specified in disk-config.nix
nix run github:nix-community/nixos-anywhere -- \
  --flake ..#hetzner \
  root@"$SERVER_IP"

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}You can now SSH to the server with: ssh justin@${SERVER_IP}${NC}"
echo -e "${GREEN}Bitcoin node will start syncing automatically. Check status with:${NC}"
echo -e "${GREEN}  ssh justin@${SERVER_IP} 'sudo -u bitcoin bitcoin-cli getblockchaininfo'${NC}"