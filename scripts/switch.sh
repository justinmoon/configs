#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
CURRENT_HOST=$(hostname)

# Switch all hosts
if [ "$HOST" = "all" ]; then
    echo "==> Switching all reachable hosts..."
    echo ""

    REMOTE_HOSTS="fusion orb utm hetzner"
    SUCCEEDED=""
    FAILED=""
    SKIPPED=""

    # Always do local first
    echo "==> Switching local ($CURRENT_HOST)..."
    if "$0" "$CURRENT_HOST"; then
        SUCCEEDED="$CURRENT_HOST"
    else
        FAILED="$CURRENT_HOST"
    fi
    echo ""

    # Then remote hosts
    for host in $REMOTE_HOSTS; do
        echo "==> Checking if $host is reachable..."
        if ssh -o ConnectTimeout=2 -o BatchMode=yes "$host" "true" 2>/dev/null; then
            echo "==> Switching $host..."
            if "$0" "$host"; then
                SUCCEEDED="$SUCCEEDED $host"
            else
                FAILED="$FAILED $host"
            fi
        else
            echo "==> Skipping $host (not reachable)"
            SKIPPED="$SKIPPED $host"
        fi
        echo ""
    done

    # Summary
    echo "========================================"
    echo "Summary:"
    [ -n "$SUCCEEDED" ] && echo "  Succeeded:$SUCCEEDED"
    [ -n "$FAILED" ] && echo "  Failed:$FAILED"
    [ -n "$SKIPPED" ] && echo "  Skipped:$SKIPPED"
    echo "========================================"
    exit 0
fi

# Auto-detect: if no arg, or arg matches current host, do local switch
if [ -z "$HOST" ] || [ "$HOST" = "$CURRENT_HOST" ]; then
    HOST="${HOST:-$CURRENT_HOST}"

    case "$HOST" in
        mac)
            echo "Switching macOS configuration locally..."
            sudo darwin-rebuild switch --flake .#mac -L --show-trace
            ;;
        fw|fusion|utm|orb)
            echo "Switching $HOST configuration locally..."
            sudo nixos-rebuild switch --flake .#"$HOST"
            ;;
        *)
            echo "Unknown host: $HOST"
            echo "Available hosts: mac, fw, fusion, utm, orb, hetzner"
            exit 1
            ;;
    esac
    exit 0
fi

# Remote deploy
echo "Deploying to remote host: $HOST"

# Host-specific SSH targets and options
case "$HOST" in
    fusion)
        SSH_TARGET="fusion"  # uses ~/.ssh/config
        REMOTE_PATH="/home/justin/configs"
        ;;
    utm)
        SSH_TARGET="utm"  # uses ~/.ssh/config
        REMOTE_PATH="/home/justin/configs"
        ;;
    orb)
        SSH_TARGET="orb"  # uses ~/.ssh/config
        REMOTE_PATH="/home/justin/configs"
        ;;
    hetzner)
        SSH_TARGET="hetzner"  # uses ~/.ssh/config
        REMOTE_PATH="/tmp/nixos-config"
        ;;
    fw)
        SSH_TARGET="fw"  # assuming this is in ssh config
        REMOTE_PATH="/home/justin/configs"
        ;;
    *)
        echo "Unknown remote host: $HOST"
        echo "Available hosts: fusion, utm, orb, hetzner, fw"
        exit 1
        ;;
esac

# Step 1: Copy configs
echo "==> Syncing configuration to $HOST..."
# Exclude git metadata whether this repo is a normal checkout (.git/ dir)
# or a git worktree (.git file pointing at a gitdir).
if [ "$HOST" = "hetzner" ]; then
    # /tmp/nixos-config is a throwaway deploy dir. It may contain a stale .git
    # file from a previous worktree-based deploy (which breaks flake eval).
    ssh "$SSH_TARGET" "sudo rm -rf $REMOTE_PATH/.git $REMOTE_PATH/.jj" 2>/dev/null || true
fi
rsync -av --delete \
    --exclude='.git/' \
    --exclude='.git' \
    --exclude='.jj/' \
    --exclude='.jj' \
    --exclude='.direnv/' \
    --exclude='.direnv' \
    --exclude='iso/' \
    --exclude='result/' \
    --exclude='result' \
    --exclude='**/target/' \
    --exclude='**/node_modules/' \
    --exclude='**/.astro/' \
    --exclude='home/opencode/notifier/.build/' \
    --exclude='home/opencode/notifier/OpenCodeNotifier.app/' \
    --rsync-path="sudo rsync" \
    ./ "$SSH_TARGET":"$REMOTE_PATH"

# Step 2: Ensure git tracks files (nix flakes need this)
echo "==> Ensuring git tracks new files..."
ssh "$SSH_TARGET" "cd $REMOTE_PATH && (git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init) && git add --all" 2>/dev/null || true

# Step 3: Run nixos-rebuild
echo "==> Running nixos-rebuild switch on $HOST..."
if [ "$HOST" = "hetzner" ]; then
    # Hetzner needs special options
    ssh "$SSH_TARGET" "cd $REMOTE_PATH && sudo nixos-rebuild switch --flake .#$HOST --option sandbox false --impure"
elif [ "$HOST" = "mac" ]; then
    ssh "$SSH_TARGET" "cd $REMOTE_PATH && sudo darwin-rebuild switch --flake .#$HOST -L --show-trace"
else
    ssh "$SSH_TARGET" "cd $REMOTE_PATH && sudo nixos-rebuild switch --flake .#$HOST"
fi

echo "==> Done! $HOST has been updated."
