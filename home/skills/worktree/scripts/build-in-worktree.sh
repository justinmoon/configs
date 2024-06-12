#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: build-in-worktree.sh <prompt> [agent]"
    echo "  prompt: Feature description/implementation instructions (be thorough!)"
    echo "  agent:  'codex' (default), 'claude', 'opencode', 'droid', or 'pi'"
    exit 1
fi

PROMPT="$1"
AGENT="${2:-codex}"

# Validate agent
case "$AGENT" in
    codex|claude|opencode|droid|pi) ;;
    *)
        echo "Error: agent must be 'codex', 'claude', 'opencode', 'droid', or 'pi', got: $AGENT"
        exit 1
        ;;
esac

# Derive branch name: first ~20 chars, kebab-case, from first few words
# Strip common filler words, take meaningful parts
BRANCH=$(echo "$PROMPT" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/please //g; s/implement //g; s/add //g; s/create //g; s/build //g; s/the //g; s/a //g; s/an //g' | \
    sed 's/[^a-z0-9 ]//g' | \
    awk '{for(i=1;i<=NF && length(out)<18;i++) out=out (out?"-":"") $i} END{print out}' | \
    sed 's/--*/-/g; s/^-//; s/-$//' | \
    cut -c1-20)

# Fallback if empty
if [ -z "$BRANCH" ]; then
    BRANCH="feature-$(date +%s | tail -c 6)"
fi

# Ensure we're in a git repo root
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

# Create worktree
WORKTREE_PATH="$ROOT/worktrees/$BRANCH"
mkdir -p "$ROOT/worktrees"

if [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree already exists at $WORKTREE_PATH"
    echo "Either delete it or use a different branch name"
    exit 1
fi

git worktree add -b "$BRANCH" "$WORKTREE_PATH"

# Get absolute path
ABS_PATH=$(realpath "$WORKTREE_PATH")

# Create tmux window and run agent
if [ -n "${TMUX:-}" ]; then
    tmux new-window -n "$BRANCH" -c "$ABS_PATH"
    sleep 0.3

    # Allow direnv first
    tmux send-keys -t "$BRANCH" "direnv allow" Enter
    sleep 0.5

    # Launch the agent
    case "$AGENT" in
        claude)
            tmux send-keys -t "$BRANCH" "claude --dangerously-skip-permissions \"$PROMPT\"" Enter
            ;;
        codex)
            tmux send-keys -t "$BRANCH" "codex --yolo \"$PROMPT\"" Enter
            ;;
        opencode)
            tmux send-keys -t "$BRANCH" "opencode --yolo \"$PROMPT\"" Enter
            ;;
        droid)
            tmux send-keys -t "$BRANCH" "droid \"$PROMPT\"" Enter
            ;;
        pi)
            tmux send-keys -t "$BRANCH" "pi \"$PROMPT\"" Enter
            ;;
    esac

    echo "Launched $AGENT in worktree: $ABS_PATH"
    echo "Branch: $BRANCH"
    echo "tmux window: $BRANCH"
else
    echo "Not in tmux. Created worktree at: $ABS_PATH"
    echo "Branch: $BRANCH"
    echo ""
    echo "To continue manually:"
    echo "  cd $ABS_PATH"
    echo "  direnv allow"
    case "$AGENT" in
        claude)
            echo "  claude --dangerously-skip-permissions \"$PROMPT\""
            ;;
        codex)
            echo "  codex --yolo \"$PROMPT\""
            ;;
        opencode)
            echo "  opencode --yolo \"$PROMPT\""
            ;;
        droid)
            echo "  droid \"$PROMPT\""
            ;;
        pi)
            echo "  pi \"$PROMPT\""
            ;;
    esac
fi
