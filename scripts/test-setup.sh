#!/usr/bin/env bash
#
# Test the setup.sh script in a fresh macOS VM using Tart
#
# Usage:
#   ./scripts/test-setup.sh [--create]  # --create to create VM from scratch
#
# Prerequisites:
#   - tart installed (brew install cirruslabs/cli/tart)
#   - ~50GB free disk space for macOS VM
#
# The script will:
#   1. Create or restore a clean macOS VM
#   2. Run the setup script
#   3. Report success/failure
#

set -euo pipefail

VM_NAME="setup-test"
SNAPSHOT_NAME="clean"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

# Check if VM exists
vm_exists() {
    tart list | grep -q "^$VM_NAME"
}

# Check if snapshot exists
snapshot_exists() {
    tart list --snapshots "$VM_NAME" 2>/dev/null | grep -q "$SNAPSHOT_NAME"
}

# Create a fresh macOS VM
create_vm() {
    info "Creating fresh macOS VM '$VM_NAME'..."
    info "This will download macOS and create a VM (~15-20 minutes)"
    
    # Pull the latest macOS Sequoia image from Cirrus Labs
    tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest "$VM_NAME"
    
    success "VM created"
    
    echo ""
    warn "Manual setup required:"
    echo "  1. Run: tart run $VM_NAME"
    echo "  2. Complete macOS setup assistant (create user 'justin' with password 'justin')"
    echo "  3. Enable SSH: System Settings → General → Sharing → Remote Login"
    echo "  4. Shut down the VM"
    echo "  5. Run: tart snapshot $VM_NAME $SNAPSHOT_NAME"
    echo ""
    echo "Then re-run this script to test setup.sh"
}

# Get VM IP address
get_vm_ip() {
    local ip
    for i in {1..30}; do
        ip=$(tart ip "$VM_NAME" 2>/dev/null || true)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
        sleep 2
    done
    return 1
}

# Wait for SSH to be available
wait_for_ssh() {
    local ip="$1"
    info "Waiting for SSH to be available..."
    for i in {1..60}; do
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "justin@$ip" "true" 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Run the test
run_test() {
    # Restore clean snapshot
    info "Restoring clean snapshot..."
    tart stop "$VM_NAME" 2>/dev/null || true
    sleep 2
    
    # Check if snapshot exists
    if ! snapshot_exists; then
        error "Snapshot '$SNAPSHOT_NAME' not found. Run with --create first and follow manual setup steps."
    fi
    
    # Restore snapshot
    tart revert "$VM_NAME" "$SNAPSHOT_NAME"
    
    # Start VM
    info "Starting VM..."
    tart run "$VM_NAME" --no-graphics &
    VM_PID=$!
    trap "kill $VM_PID 2>/dev/null || true" EXIT
    
    # Wait for boot and get IP
    info "Waiting for VM to boot..."
    sleep 10
    
    local ip
    if ! ip=$(get_vm_ip); then
        error "Could not get VM IP address"
    fi
    info "VM IP: $ip"
    
    # Wait for SSH
    if ! wait_for_ssh "$ip"; then
        error "SSH not available after 2 minutes"
    fi
    success "SSH is available"
    
    # Run setup script
    info "Running setup script..."
    echo ""
    
    # SSH in and run the setup script
    # Note: This will fail at interactive parts (Xcode dialog, 1Password login)
    # but we can at least test the non-interactive parts
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "justin@$ip" bash <<'EOF'
set -x
# Download and run setup script
curl -fsSL https://setup.justinmoon.com -o /tmp/setup.sh

# Show what we downloaded
head -50 /tmp/setup.sh

# Run with error output (will fail at interactive parts, that's expected)
bash /tmp/setup.sh 2>&1 || true
EOF
    
    echo ""
    success "Test completed (check output above for errors)"
    
    # Stop VM
    info "Stopping VM..."
    kill $VM_PID 2>/dev/null || true
}

# Main
main() {
    # Check tart is installed
    if ! command -v tart &>/dev/null; then
        error "tart not installed. Run: brew install cirruslabs/cli/tart"
    fi
    
    # Handle --create flag
    if [[ "${1:-}" == "--create" ]]; then
        if vm_exists; then
            warn "VM '$VM_NAME' already exists. Delete it first with: tart delete $VM_NAME"
            exit 1
        fi
        create_vm
        exit 0
    fi
    
    # Check VM exists
    if ! vm_exists; then
        warn "VM '$VM_NAME' not found."
        echo ""
        echo "To create it, run:"
        echo "  $0 --create"
        echo ""
        exit 1
    fi
    
    run_test
}

main "$@"
