# =============================================================================
# Secret Management (agenix)
# =============================================================================
# Recipients for secret encryption (yubikey primary, yubikey backup, server key)
RECIPIENTS := "-r age1yubikey1q0zhu9e7zrj48zmnpx4fg07c0drt9f57e26uymgxa4h3fczwutzjjp5a6y5 -r age1yubikey1qtdv7spad78v4yhrtrts6tvv5wc80vw6mah6g64m9cr9l3ryxsf2jdx8gs9 -r age1mtf29wt0we3adcja7k0ylc9hmf2fns3c44qz9g663l0ydepxqdrq94jzzf"
IDENTITY := "yubikeys/keys.txt"

# List all secrets
secret-list:
    @ls -1 secrets/*.age 2>/dev/null | xargs -I{} basename {} .age | grep -v '^$' || echo "No secrets found"

# Init a new secret (creates empty encrypted file)
secret-init name:
    #!/usr/bin/env bash
    set -euo pipefail
    SECRET_FILE="secrets/{{name}}.age"

    if [[ -f "$SECRET_FILE" ]]; then
        echo "Secret already exists: $SECRET_FILE"
        exit 1
    fi

    printf '' | age -e {{RECIPIENTS}} -o "$SECRET_FILE"
    echo "Created $SECRET_FILE"
    echo "Now run: just secret-edit {{name}}"

# Edit a secret (opens $EDITOR, requires YubiKey tap)
secret-edit name:
    #!/usr/bin/env bash
    set -euo pipefail
    SECRET_FILE="secrets/{{name}}.age"

    if [[ ! -f "$SECRET_FILE" ]]; then
        echo "Secret not found: $SECRET_FILE"
        echo "Available secrets:"
        just secret-list
        exit 1
    fi

    TMP=$(mktemp)
    trap "rm -f $TMP" EXIT

    echo "Decrypting {{name}}... (tap YubiKey)"
    age -d -i "{{IDENTITY}}" "$SECRET_FILE" > "$TMP"

    ${EDITOR:-nano} "$TMP"

    echo "Re-encrypting {{name}}... (tap YubiKey)"
    age -e {{RECIPIENTS}} -o "$SECRET_FILE" < "$TMP"
    echo "Saved $SECRET_FILE"

# View a secret (requires YubiKey tap)
secret-view name:
    #!/usr/bin/env bash
    set -euo pipefail
    SECRET_FILE="secrets/{{name}}.age"

    if [[ ! -f "$SECRET_FILE" ]]; then
        echo "Secret not found: $SECRET_FILE"
        just secret-list
        exit 1
    fi

    echo "Decrypting {{name}}... (tap YubiKey)"
    age -d -i "{{IDENTITY}}" "$SECRET_FILE"

# =============================================================================
# SSH Key Bootstrap
# =============================================================================
# Install SSH key from 1Password (op://cli/ssh/key)

install-ssh-key:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -f ~/.ssh/id_ed25519 ]; then
        echo "SSH key already exists at ~/.ssh/id_ed25519"
        echo "Remove it first if you want to reinstall"
        exit 1
    fi

    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    echo "Fetching SSH key from 1Password..."
    op read "op://cli/ssh/key" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519

    # Extract public key from private key
    ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
    chmod 644 ~/.ssh/id_ed25519.pub

    echo "SSH key installed to ~/.ssh/id_ed25519"

# =============================================================================
# System Configuration
# =============================================================================

# Smart switch: auto-detect hostname or specify one
switch host="":
    ./scripts/switch.sh {{host}}

# Alias for switch
s host="":
    ./scripts/switch.sh {{host}}

update:
    nix flake update

hetzner-install ip:
    cd hosts/hetzner && ./install.sh {{ip}}

hetzner-ssh:
    ssh justin@100.73.239.5

# Deploy static site to justinmoon.com/s/[app]
deploy-static app build_dir="dist":
    deploy-static {{app}} {{build_dir}}

# List deployed static apps
list-static:
    ssh justin@100.73.239.5 "ls -la /var/www/static/s/ 2>/dev/null || echo 'No apps deployed yet'"

# Sync setup.sh to GitHub Gist
sync-setup-gist:
    gh gist edit 23634343a270ea418ddf3e94cd227e68 scripts/setup.sh

# Test setup.sh in a fresh macOS VM (requires tart)
test-setup:
    ./scripts/test-setup.sh

# Create fresh macOS VM for testing setup.sh
test-setup-create:
    ./scripts/test-setup.sh --create

# =============================================================================
# VMware Fusion VM Management
# =============================================================================
# Usage:
#   NIXADDR=<ip> just fusion-bootstrap0   # Fresh install from ISO
#   NIXADDR=<ip> just fusion-bootstrap    # After reboot, finish setup
#   just switch fusion                    # Update running VM

# ISO download settings
ISO_DIR := "iso"
ISO_CHANNEL := "nixos-25.11"
ISO_BASE_URL := "https://channels.nixos.org/" + ISO_CHANNEL
ISO_NAME := "latest-nixos-minimal-aarch64-linux.iso"
ISO_URL := ISO_BASE_URL + "/" + ISO_NAME
ISO_SHA256_URL := ISO_URL + ".sha256"

# VM connectivity (override with env vars)
NIXADDR := env("NIXADDR", "172.16.16.130")
NIXPORT := env("NIXPORT", "22")
NIXUSER := env("NIXUSER", "justin")

# SSH options for bootstrap (password auth, no host key checking)
SSH_OPTIONS := "-o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# Download NixOS ISO with hash verification
download-iso:
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p {{ISO_DIR}}
    cd {{ISO_DIR}}

    echo "==> Downloading NixOS ISO from official channel..."
    echo "    URL: {{ISO_URL}}"
    echo ""

    curl -L -o nixos.iso --progress-bar "{{ISO_URL}}"

    echo ""
    echo "==> Fetching SHA256 hash from NixOS channel..."
    EXPECTED_HASH=$(curl -sL "{{ISO_SHA256_URL}}" | awk '{print $1}')
    echo "    Expected: $EXPECTED_HASH"

    echo ""
    echo "==> Computing SHA256 of downloaded ISO..."
    ACTUAL_HASH=$(shasum -a 256 nixos.iso | awk '{print $1}')
    echo "    Actual:   $ACTUAL_HASH"

    echo ""
    if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
        echo "✓ SHA256 verification PASSED"
        echo ""
        echo "ISO saved to: {{ISO_DIR}}/nixos.iso"
    else
        echo "✗ SHA256 verification FAILED!"
        rm -f nixos.iso
        exit 1
    fi

# Show ISO verification info
iso-info:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Channel: {{ISO_CHANNEL}}"
    echo "ISO URL: {{ISO_URL}}"
    CHANNEL_HASH=$(curl -sL "{{ISO_SHA256_URL}}" | awk '{print $1}')
    echo "SHA256:  $CHANNEL_HASH"

# Fusion bootstrap phase 0 - partition and install base NixOS from ISO
# The VM should have NixOS ISO booted and root password set to "root"
fusion-bootstrap0:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Connecting to VM at {{NIXADDR}}..."
    echo "==> Will partition disk, fix DNS, and install NixOS"
    echo ""

    ssh {{SSH_OPTIONS}} -p{{NIXPORT}} root@{{NIXADDR}} 'bash -s' << 'ENDSSH'
    set -euo pipefail

    echo "==> Fixing DNS first (VMware NAT DNS is unreliable)..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf

    echo "==> Testing DNS..."
    ping -c 1 cache.nixos.org || { echo "DNS still broken!"; exit 1; }

    echo "==> Partitioning /dev/sda..."
    parted /dev/sda -- mklabel gpt
    parted /dev/sda -- mkpart primary 512MB -8GB
    parted /dev/sda -- mkpart primary linux-swap -8GB 100%
    parted /dev/sda -- mkpart ESP fat32 1MB 512MB
    parted /dev/sda -- set 3 esp on
    sleep 1

    echo "==> Formatting partitions..."
    mkfs.ext4 -L nixos /dev/sda1
    mkswap -L swap /dev/sda2
    mkfs.fat -F 32 -n boot /dev/sda3
    sleep 1

    echo "==> Mounting filesystems..."
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot

    echo "==> Generating NixOS config..."
    nixos-generate-config --root /mnt

    echo "==> Patching configuration.nix..."
    sed --in-place '/system\.stateVersion = .*/a \
      nix.package = pkgs.nixVersions.latest;\
      nix.extraOptions = "experimental-features = nix-command flakes";\
      networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];\
      services.openssh.enable = true;\
      services.openssh.settings.PasswordAuthentication = true;\
      services.openssh.settings.PermitRootLogin = "yes";\
      users.users.root.initialPassword = "root";\
    ' /mnt/etc/nixos/configuration.nix

    echo "==> Running nixos-install (this takes a few minutes)..."
    nixos-install --no-root-passwd

    echo ""
    echo "==> Installation complete! Rebooting..."
    echo "==> After reboot, run: NIXADDR={{NIXADDR}} just fusion-bootstrap"
    reboot
    ENDSSH

# Fusion bootstrap phase 1 - after reboot from bootstrap0
# Copies config, switches, copies secrets, and reboots
fusion-bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Phase 1: Fixing DNS (VMware issue)..."
    ssh {{SSH_OPTIONS}} -p{{NIXPORT}} root@{{NIXADDR}} "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

    echo "==> Phase 1: Creating /home/justin/configs directory..."
    ssh {{SSH_OPTIONS}} -p{{NIXPORT}} root@{{NIXADDR}} "mkdir -p /home/justin/configs"

    echo "==> Phase 1: Copying config to VM..."
    rsync -av -e 'ssh {{SSH_OPTIONS}} -p{{NIXPORT}}' \
        --exclude='.git/' \
        --exclude='.jj/' \
        --exclude='iso/' \
        --rsync-path="sudo rsync" \
        ./ root@{{NIXADDR}}:/home/justin/configs

    echo ""
    echo "==> Phase 1: Applying NixOS configuration (this takes a while)..."
    ssh {{SSH_OPTIONS}} -p{{NIXPORT}} root@{{NIXADDR}} " \
        sudo nixos-rebuild switch --flake /home/justin/configs#fusion \
    "

    echo ""
    echo "==> Phase 1: Rebooting into final system..."
    ssh {{SSH_OPTIONS}} -p{{NIXPORT}} root@{{NIXADDR}} "sudo reboot" || true

    echo ""
    echo "=========================================="
    echo "Bootstrap complete!"
    echo ""
    echo "After reboot, log in as: justin"
    echo "Password: justin"
    echo ""
    echo "To switch to i3, run in VM:"
    echo "  sudo /run/current-system/specialisation/i3/bin/switch-to-configuration switch"
    echo "Then log out and back in, selecting i3 at login screen."
    echo "=========================================="

# =============================================================================
# UTM VM Management (NixOS VM using Apple Virtualization Framework)
# =============================================================================
# Usage:
#   just utm-bootstrap0 <ip>   # Fresh install from ISO
#   just utm-bootstrap <ip>    # After reboot, finish setup
#   just switch utm            # Update running VM

UTM_VM_NAME := "NixOS"

# Create UTM VM with NixOS ISO attached
utm-create:
    #!/usr/bin/env bash
    set -euo pipefail

    ISO_PATH="$(pwd)/iso/nixos.iso"
    VM_NAME="{{UTM_VM_NAME}}"

    if [ ! -f "$ISO_PATH" ]; then
        echo "Error: NixOS ISO not found at $ISO_PATH"
        echo "Run 'just download-iso' first"
        exit 1
    fi

    echo "==> Creating UTM VM '$VM_NAME' via AppleScript..."
    osascript scripts/utm-create.applescript "$ISO_PATH" "$VM_NAME"

    echo ""
    echo "==> VM '$VM_NAME' created!"
    echo ""
    echo "IMPORTANT: Before starting, open UTM and configure:"
    echo "  1. Display: Add a display (Retina resolution recommended)"
    echo "  2. Network: Ensure 'Shared Network' is enabled"
    echo "  3. Boot: Verify UEFI boot is enabled"
    echo ""
    echo "Then run: just utm-start"

# Start UTM VM
utm-start:
    @echo "==> Starting UTM VM '{{UTM_VM_NAME}}'..."
    @utmctl start "{{UTM_VM_NAME}}"

# Stop UTM VM
utm-stop:
    @echo "==> Stopping UTM VM '{{UTM_VM_NAME}}'..."
    @utmctl stop "{{UTM_VM_NAME}}"

# Get UTM VM IP address
utm-ip:
    @utmctl ip-address "{{UTM_VM_NAME}}" 2>/dev/null || echo "VM not running or guest agent not available"

# UTM bootstrap phase 0 - partition and install base NixOS
# Run this after booting from ISO and setting root password to "root"
utm-bootstrap0 ip:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Connecting to UTM VM at {{ip}}..."
    echo "==> Will partition disk, and install NixOS"
    echo ""

    ssh {{SSH_OPTIONS}} -p22 root@{{ip}} 'bash -s' << 'ENDSSH'
    set -euo pipefail

    echo "==> Partitioning /dev/vda (UTM uses virtio disks)..."
    parted /dev/vda -- mklabel gpt
    parted /dev/vda -- mkpart primary 512MB -8GB
    parted /dev/vda -- mkpart primary linux-swap -8GB 100%
    parted /dev/vda -- mkpart ESP fat32 1MB 512MB
    parted /dev/vda -- set 3 esp on
    sleep 1

    echo "==> Formatting partitions..."
    mkfs.ext4 -L nixos /dev/vda1
    mkswap -L swap /dev/vda2
    mkfs.fat -F 32 -n boot /dev/vda3
    sleep 1

    echo "==> Mounting filesystems..."
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot

    echo "==> Generating NixOS config..."
    nixos-generate-config --root /mnt

    echo "==> Patching configuration.nix..."
    sed --in-place '/system\.stateVersion = .*/a \
      nix.package = pkgs.nixVersions.latest;\
      nix.extraOptions = "experimental-features = nix-command flakes";\
      services.openssh.enable = true;\
      services.openssh.settings.PasswordAuthentication = true;\
      services.openssh.settings.PermitRootLogin = "yes";\
      users.users.root.initialPassword = "root";\
    ' /mnt/etc/nixos/configuration.nix

    echo "==> Running nixos-install (this takes a few minutes)..."
    nixos-install --no-root-passwd

    echo ""
    echo "==> Installation complete!"
    echo "==> Shut down the VM, remove the ISO from drives, then start again"
    echo "==> After reboot, run: just utm-bootstrap <ip>"
    ENDSSH

# UTM bootstrap phase 1 - after reboot from bootstrap0
utm-bootstrap ip:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Phase 1: Creating /home/justin/configs directory..."
    ssh {{SSH_OPTIONS}} -p22 root@{{ip}} "mkdir -p /home/justin/configs"

    echo "==> Phase 1: Copying config to VM..."
    rsync -av -e 'ssh {{SSH_OPTIONS}} -p22' \
        --exclude='.git/' \
        --exclude='.jj/' \
        --exclude='iso/' \
        --rsync-path="sudo rsync" \
        ./ root@{{ip}}:/home/justin/configs

    echo ""
    echo "==> Phase 1: Applying NixOS configuration (this takes a while)..."
    ssh {{SSH_OPTIONS}} -p22 root@{{ip}} " \
        sudo nixos-rebuild switch --flake /home/justin/configs#utm \
    "

    echo ""
    echo "==> Phase 1: Rebooting into final system..."
    ssh {{SSH_OPTIONS}} -p22 root@{{ip}} "reboot" || true

    echo ""
    echo "=========================================="
    echo "Bootstrap complete!"
    echo ""
    echo "After reboot, log in as: justin"
    echo "Password: justin"
    echo ""
    echo "i3 should be available at the login screen."
    echo "=========================================="

# SSH into UTM VM
utm-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    IP=$(utmctl ip-address "{{UTM_VM_NAME}}" | head -1)
    if [ -z "$IP" ]; then
        echo "Error: Could not get VM IP. Is the VM running?"
        exit 1
    fi
    ssh justin@$IP

# =============================================================================
# Agent VM Management (Ephemeral coding agent VMs)
# =============================================================================
# Usage:
#   just agent-spawn https://github.com/user/repo "Fix the tests"
#   just agent-list
#   just agent-attach <id>
#   just agent-stop <id>
#   just agent-resume <id>

# Spawn a new agent VM session
agent-spawn repo prompt="":
    nix run ./agent-vm#agent-spawn -- --repo "{{repo}}" --prompt "{{prompt}}"

# List all agent sessions
agent-list:
    nix run ./agent-vm#agent-list

# Attach to a running agent session
agent-attach id:
    nix run ./agent-vm#agent-attach -- "{{id}}"

# Stop an agent session
agent-stop id:
    nix run ./agent-vm#agent-stop -- "{{id}}"

# Resume a stopped agent session
agent-resume id:
    nix run ./agent-vm#agent-resume -- "{{id}}"
