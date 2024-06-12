#!/usr/bin/env bash
#
# Universal bootstrap script for Justin's machines
# Works on fresh macOS and Linux installations
#
# Usage (download first, then run - required for interactive prompts):
#   curl -fsSL setup.justinmoon.com -o /tmp/setup.sh && bash /tmp/setup.sh

set -euo pipefail

CONFIGS_REPO="git@github.com:justinmoon/configs.git"
CONFIGS_DIR="$HOME/configs"

# VMware Fusion torrent (for NixOS VM development)
VMWARE_MAGNET="magnet:?xt=urn:btih:3BE00EEB155205A84816D01DBFB083C3E392F18C&dn=VMware%20Fusion%20Pro%2025H2%20v25.0.0.24995814%20(macOS)%20%5BAppDoze%5D&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.bittor.pw%3A1337%2Fannounce&tr=udp%3A%2F%2Fpublic.popcorn-tracker.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.dler.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969&tr=udp%3A%2F%2Fopen.demonii.com%3A1337%2Fannounce&tr=udp%3A%2F%2Fglotorrents.pw%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftorrent.gresille.org%3A80%2Fannounce&tr=udp%3A%2F%2Fp4p.arenabg.com%3A1337&tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337"
VMWARE_SHA256="a995ebd6fded41b3f2da87efff6b8674d6689f4c997772810ea1a5c2ebe28c0e"
VMWARE_TORRENT_DIR="VMware Fusion Pro 25H2 v25.0.0.24995814 (macOS)"
VMWARE_DMG_NAME="VMware-Fusion-25H2-24995814 [AppDoze].dmg"

# NixOS VM snapshots (pre-configured VMs for development)
NIXOS_VM_FUSION_URL="https://pub-f8a2fddfdfd0427696cb4dd0349ca953.r2.dev/nixos-vm-fusion.tar.gz"
NIXOS_VM_UTM_URL="https://pub-f8a2fddfdfd0427696cb4dd0349ca953.r2.dev/nixos-vm-utm.tar.gz"
NIXOS_VM_DEST="$HOME/Virtual Machines.localized"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}==>${NC} $1"
}

success() {
    echo -e "${GREEN}==>${NC} $1"
}

warn() {
    echo -e "${YELLOW}==>${NC} $1"
}

error() {
    echo -e "${RED}==>${NC} $1"
    exit 1
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            if [ -f /etc/NIXOS ]; then
                echo "nixos"
            else
                echo "linux"
            fi
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            ;;
    esac
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Xcode Command Line Tools (macOS)
install_xcode_cli() {
    if xcode-select -p &>/dev/null; then
        success "Xcode CLI tools already installed"
    else
        info "Installing Xcode Command Line Tools..."
        xcode-select --install

        # Wait for installation to complete
        echo "Please complete the Xcode CLI tools installation dialog, then press Enter..."
        read -r

        if ! xcode-select -p &>/dev/null; then
            error "Xcode CLI tools installation failed"
        fi
        success "Xcode CLI tools installed"
    fi

    # Reset developer directory to ensure xcrun works correctly
    info "Resetting Xcode developer directory..."
    sudo xcode-select --reset
}

# Install Nix via official installer
install_nix() {
    if command_exists nix; then
        success "Nix already installed"
        return
    fi

    # Clean up shell rc files before Nix install to avoid interactive prompts
    info "Cleaning up shell rc files before Nix install..."
    sudo rm -f /etc/bashrc /etc/zshrc /etc/bash.bashrc /etc/zsh/zshrc \
        /etc/bashrc.backup-before-nix /etc/zshrc.backup-before-nix \
        /etc/bash.bashrc.backup-before-nix /etc/zsh/zshrc.backup-before-nix

    info "Installing Nix via official installer..."
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes

    # Source nix for current session (check both possible locations)
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    elif [ -e '/etc/profile.d/nix.sh' ]; then
        . '/etc/profile.d/nix.sh'
    fi

    # Enable flakes for this session (official installer doesn't enable by default)
    export NIX_CONFIG="experimental-features = nix-command flakes"

    success "Nix installed"
}

# Install Homebrew (macOS)
install_homebrew() {
    if command_exists brew; then
        success "Homebrew already installed"
        return
    fi

    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add homebrew to path for current session
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    success "Homebrew installed"
}

# Install 1Password (needed for SSH key retrieval)
install_1password() {
    if [ -d "/Applications/1Password.app" ]; then
        success "1Password already installed"
        return
    fi

    info "Installing 1Password..."
    brew install --cask 1password

    echo ""
    warn "1Password installed. Please:"
    echo "  1. Open 1Password and sign in to your account"
    echo "  2. Go to Settings (⌘,) → Developer"
    echo "  3. Enable 'Integrate with 1Password CLI'"
    echo ""
    echo "Press Enter when done..."
    read -r

    success "1Password configured"
}

# Clone configs repository
clone_configs() {
    if [ -d "$CONFIGS_DIR" ]; then
        warn "Configs directory already exists at $CONFIGS_DIR"
        info "Pulling latest changes..."
        cd "$CONFIGS_DIR"
        git pull
        return
    fi

    # Add GitHub to known hosts to avoid interactive prompt
    info "Adding GitHub to known hosts..."
    mkdir -p "$HOME/.ssh"
    ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

    info "Cloning configs repository..."
    git clone "$CONFIGS_REPO" "$CONFIGS_DIR"
    success "Configs cloned to $CONFIGS_DIR"
}

# Run darwin-rebuild (macOS)
run_darwin_rebuild() {
    info "Running initial darwin-rebuild..."
    cd "$CONFIGS_DIR"

    # Clean up any leftover Determinate Nix files if present
    if [ -f "/etc/nix/nix.custom.conf" ]; then
        info "Removing /etc/nix/nix.custom.conf (leftover from Determinate Nix)..."
        sudo rm -f /etc/nix/nix.custom.conf
    fi
    if [ -d "/etc/determinate" ]; then
        info "Removing /etc/determinate (leftover from Determinate Nix)..."
        sudo rm -rf /etc/determinate
    fi

    # Clean up shell rc files that conflict with nix-darwin
    # (nix-darwin wants to manage these itself)
    info "Cleaning up shell rc files for nix-darwin..."
    sudo rm -f /etc/bashrc /etc/zshrc /etc/bash.bashrc /etc/zsh/zshrc \
        /etc/bashrc.backup-before-nix /etc/zshrc.backup-before-nix \
        /etc/bash.bashrc.backup-before-nix /etc/zsh/zshrc.backup-before-nix \
        /etc/profile.d/nix.sh

    # First build requires sudo for system activation
    # Use --extra-experimental-features since official installer doesn't enable flakes by default
    sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#mac

    success "darwin-rebuild completed"
}

# Setup SSH key from 1Password
setup_ssh_key() {
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        success "SSH key already exists"
        return
    fi

    info "Setting up SSH key from 1Password..."

    # Install 1Password CLI if not present (nix packages not available yet)
    if ! command_exists op; then
        info "Installing 1Password CLI..."
        brew install 1password-cli
    fi

    # Check if signed in
    if ! op account list &>/dev/null; then
        echo ""
        warn "1Password CLI not connected to desktop app."
        echo ""
        echo "Please ensure:"
        echo "  1. 1Password app is open and signed in"
        echo "  2. Settings (⌘,) → Developer → 'Integrate with 1Password CLI' is enabled"
        echo ""
        echo "Press Enter when done..."
        read -r
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Fetch SSH key from 1Password
    info "Fetching SSH key from 1Password (cli/ssh/key)..."
    op read "op://cli/ssh/key" > "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"

    # Derive public key from private key
    ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
    chmod 644 "$HOME/.ssh/id_ed25519.pub"

    success "SSH key installed"
}

# Install VMware Fusion via torrent
install_vmware_fusion() {
    if [ -d "/Applications/VMware Fusion.app" ]; then
        success "VMware Fusion already installed"
        return
    fi

    info "Installing VMware Fusion via torrent..."

    # Install aria2 if not present
    if ! command_exists aria2c; then
        info "Installing aria2..."
        brew install aria2
    fi

    DOWNLOAD_DIR="$HOME/Downloads"
    cd "$DOWNLOAD_DIR"

    info "Downloading VMware Fusion (this may take a while)..."
    aria2c --seed-time=0 "$VMWARE_MAGNET"

    # Find the downloaded DMG (torrent extracts to folder with DMG subfolder)
    DMG_PATH="$DOWNLOAD_DIR/$VMWARE_TORRENT_DIR/DMG/$VMWARE_DMG_NAME"

    if [ ! -f "$DMG_PATH" ]; then
        error "DMG not found at: $DMG_PATH"
    fi

    info "Verifying SHA256 hash..."
    ACTUAL_HASH=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

    if [ "$ACTUAL_HASH" != "$VMWARE_SHA256" ]; then
        error "SHA256 mismatch! Expected: $VMWARE_SHA256, Got: $ACTUAL_HASH"
    fi
    success "SHA256 verified"

    info "Mounting DMG..."
    hdiutil attach "$DMG_PATH" -nobrowse -quiet

    info "Installing VMware Fusion..."
    sudo cp -R "/Volumes/VMware Fusion/VMware Fusion.app" /Applications/

    info "Unmounting DMG..."
    hdiutil detach "/Volumes/VMware Fusion" -quiet

    success "VMware Fusion installed"
}

# Initialize UTM (already installed via nix darwin config)
init_utm() {
    if [ ! -d "/Applications/UTM.app" ]; then
        warn "UTM not found - it should have been installed by darwin-rebuild"
        warn "Try running: darwin-rebuild switch --flake ~/configs#mac"
        return 1
    fi

    # Launch UTM once to initialize its data directory, then quit
    info "Initializing UTM..."
    open -a UTM
    sleep 5
    osascript -e 'quit app "UTM"' 2>/dev/null || true
    success "UTM initialized"
}

# Download and extract NixOS VM snapshot
download_nixos_vm_fusion() {
    VM_DIR="$NIXOS_VM_DEST/NixOS.vmwarevm"

    if [ -d "$VM_DIR" ]; then
        success "NixOS VM (Fusion) already exists"
        return
    fi

    info "Downloading NixOS VM for VMware Fusion (~11GB, this may take a while)..."

    mkdir -p "$NIXOS_VM_DEST"
    cd "$NIXOS_VM_DEST"

    # Download and extract in one step
    curl -fSL "$NIXOS_VM_FUSION_URL" | tar -xzf -

    # Rename the extracted folder
    if [ -d "Clone of NixOS.vmwarevm" ]; then
        mv "Clone of NixOS.vmwarevm" "NixOS.vmwarevm"
    fi

    success "NixOS VM (Fusion) downloaded and extracted"

    echo ""
    warn "To use the VM:"
    echo "  1. Open VMware Fusion"
    echo "  2. File → Open and select: $VM_DIR"
    echo "  3. Start the VM"
    echo ""
}

download_nixos_vm_utm() {
    UTM_DIR="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
    VM_DIR="$UTM_DIR/NixOS.utm"

    if [ -d "$VM_DIR" ]; then
        success "NixOS VM (UTM) already exists"
        return
    fi

    info "Downloading NixOS VM for UTM (~11GB, this may take a while)..."

    mkdir -p "$UTM_DIR"
    cd "$UTM_DIR"

    # Download and extract in one step
    curl -fSL "$NIXOS_VM_UTM_URL" | tar -xzf -

    success "NixOS VM (UTM) downloaded and extracted"

    echo ""
    warn "To use the VM:"
    echo "  1. Open UTM"
    echo "  2. The NixOS VM should appear automatically"
    echo "  3. Start the VM and log in as justin (password: justin)"
    echo ""
}

# Print next steps
print_next_steps_macos() {
    echo ""
    echo "=========================================="
    success "macOS bootstrap complete!"
    echo "=========================================="
    echo ""
}

print_next_steps_nixos() {
    echo ""
    echo "=========================================="
    success "NixOS bootstrap complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Copy configs to this machine or clone via SSH"
    echo "   git clone $CONFIGS_REPO $CONFIGS_DIR"
    echo ""
    echo "2. Run nixos-rebuild:"
    echo "   cd $CONFIGS_DIR"
    echo "   sudo nixos-rebuild switch --flake .#<hostname>"
    echo ""
    echo "   Available hosts: fusion, utm, fw, hetzner"
    echo ""
}

print_next_steps_linux() {
    echo ""
    echo "=========================================="
    success "Linux bootstrap complete!"
    echo "=========================================="
    echo ""
    echo "Nix has been installed. Next steps:"
    echo ""
    echo "1. Start a new shell to load nix"
    echo ""
    echo "2. Clone configs:"
    echo "   git clone $CONFIGS_REPO $CONFIGS_DIR"
    echo ""
    echo "3. For NixOS, run:"
    echo "   cd $CONFIGS_DIR"
    echo "   sudo nixos-rebuild switch --flake .#<hostname>"
    echo ""
}

# Main setup flow
main() {
    echo ""
    echo "=========================================="
    info "Justin's Machine Bootstrap Script"
    echo "=========================================="
    echo ""

    OS=$(detect_os)
    info "Detected OS: $OS"
    echo ""

    case "$OS" in
        macos)
            install_xcode_cli
            install_nix
            install_homebrew
            install_1password
            setup_ssh_key
            clone_configs
            run_darwin_rebuild

            # Ask user which VM platform(s) they want
            echo ""
            info "NixOS VM Setup"
            echo "  Which VM platform(s) do you want to set up?"
            echo "  1) UTM (free, recommended for Apple Silicon)"
            echo "  2) VMware Fusion (requires license)"
            echo "  3) Both"
            echo "  4) Skip"
            echo ""
            read -p "Enter choice [1-4]: " vm_choice

            case "$vm_choice" in
                1)
                    init_utm
                    download_nixos_vm_utm
                    ;;
                2)
                    install_vmware_fusion
                    download_nixos_vm_fusion
                    ;;
                3)
                    init_utm
                    download_nixos_vm_utm
                    install_vmware_fusion
                    download_nixos_vm_fusion
                    ;;
                4)
                    info "Skipping VM setup"
                    ;;
                *)
                    warn "Invalid choice, skipping VM setup"
                    ;;
            esac

            print_next_steps_macos
            ;;
        nixos)
            # NixOS already has nix, just need to clone configs
            info "NixOS detected - nix is already available"
            clone_configs
            print_next_steps_nixos
            ;;
        linux)
            # Other Linux distros - install nix, clone configs
            install_nix
            clone_configs
            print_next_steps_linux
            ;;
    esac
}

main "$@"
