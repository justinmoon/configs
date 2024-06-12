#!/usr/bin/env bash
#
# Cleanup broken nix installation after Migration Assistant
# Run this, reboot, then run setup.sh again
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    error "Please run with sudo: sudo ./scripts/cleanup-nix.sh"
fi

echo ""
echo "=========================================="
info "Cleaning up broken nix installation"
echo "=========================================="
echo ""

# Stop nix daemon
info "Stopping nix daemon..."
launchctl bootout system/org.nixos.nix-daemon 2>/dev/null || true
launchctl bootout system/org.nix-community.home.syncthing 2>/dev/null || true
launchctl bootout system/org.nix-community.home.syncthing-init 2>/dev/null || true

# Remove LaunchDaemons
info "Removing LaunchDaemons..."
rm -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist
rm -f /Library/LaunchDaemons/org.nix-community.home.*.plist

# Remove LaunchAgents (user-level)
info "Removing LaunchAgents..."
rm -f /Library/LaunchAgents/org.nix-community.home.*.plist 2>/dev/null || true

# Try to unmount and delete the nix APFS volume
info "Removing /nix APFS volume..."
if diskutil info /nix &>/dev/null; then
    diskutil unmount force /nix 2>/dev/null || true
    # Find and delete the Nix Store volume
    VOLUME_ID=$(diskutil list | grep "Nix Store" | awk '{print $NF}')
    if [ -n "$VOLUME_ID" ]; then
        diskutil apfs deleteVolume "$VOLUME_ID" || warn "Could not delete volume, will try rm"
    fi
fi

# Fallback: remove /nix directory if it still exists
if [ -d /nix ] || [ -L /nix ]; then
    info "Removing /nix directory..."
    rm -rf /nix 2>/dev/null || true
fi

# Remove nix configuration
info "Removing /etc/nix..."
rm -rf /etc/nix

# Remove nix-darwin /etc/static symlink
info "Removing /etc/static..."
rm -f /etc/static

# Remove shell rc files that nix/nix-darwin manages
info "Removing nix-managed shell configs..."
rm -f /etc/bashrc /etc/zshrc /etc/bash.bashrc
rm -f /etc/bashrc.backup-before-nix /etc/zshrc.backup-before-nix
rm -f /etc/bash.bashrc.backup-before-nix
rm -rf /etc/zsh 2>/dev/null || true
rm -f /etc/profile.d/nix.sh 2>/dev/null || true

# Remove root user nix files
info "Removing root nix files..."
rm -rf /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels

# Remove current user nix files
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
info "Removing $REAL_USER nix files..."
rm -rf "$REAL_HOME/.nix-profile" "$REAL_HOME/.nix-defexpr" "$REAL_HOME/.nix-channels"
rm -rf "$REAL_HOME/.local/state/nix" "$REAL_HOME/.local/state/home-manager"
rm -rf "$REAL_HOME/.cache/nix"

# Fix synthetic.conf - keep run line, remove nix line
info "Fixing /etc/synthetic.conf..."
if [ -f /etc/synthetic.conf ]; then
    grep -v "^nix" /etc/synthetic.conf > /tmp/synthetic.conf.new || true
    if [ ! -s /tmp/synthetic.conf.new ]; then
        # If empty after removing nix, add just the run line
        echo "run	private/var/run" > /tmp/synthetic.conf.new
    fi
    mv /tmp/synthetic.conf.new /etc/synthetic.conf
fi

# Remove nix build users (optional, installer will recreate)
info "Removing nix build users..."
for i in $(seq 1 32); do
    dscl . -delete /Users/_nixbld$i 2>/dev/null || true
    dscl . -delete /Users/nixbld$i 2>/dev/null || true
done

# Remove nixbld group
info "Removing nixbld group..."
dscl . -delete /Groups/nixbld 2>/dev/null || true

echo ""
echo "=========================================="
info "Cleanup complete!"
echo "=========================================="
echo ""
warn "You MUST reboot now to clear the synthetic mount."
echo ""
echo "After reboot, run:"
echo "  cd ~/configs"
echo "  ./scripts/setup.sh"
echo ""
