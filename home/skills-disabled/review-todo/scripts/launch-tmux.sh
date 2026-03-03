#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<USAGE
Usage: launch-tmux.sh <run-dir> <todo-file> [strictness] [review-guidance]

Creates a 3-pane tmux window for:
- implementer
- reviewer-1
- reviewer-2

This script initializes the run directory and prints role commands in panes.
It does not auto-launch agents.
USAGE
    exit 1
}

[[ $# -lt 2 ]] && usage

RUN_DIR="$1"
TODO_FILE="$2"
STRICTNESS="${3:-balanced}"
GUIDANCE=""
if [[ $# -ge 4 ]]; then
    shift 3
    GUIDANCE="$*"
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is required"
    exit 1
fi

if [[ -z "${TMUX:-}" ]]; then
    echo "Error: run this from inside an existing tmux session"
    exit 1
fi

"$SCRIPT_DIR/init.sh" \
    --dir "$RUN_DIR" \
    --todo "$TODO_FILE" \
    --strictness "$STRICTNESS" \
    --guidance "$GUIDANCE"

RUN_DIR_Q="$(printf "%q" "$RUN_DIR")"

window_name="review-$(basename "$RUN_DIR" | tr -cd 'a-zA-Z0-9-' | tr '[:upper:]' '[:lower:]' | cut -c1-20)"
window_id="$(tmux new-window -P -F '#{window_id}' -n "$window_name")"

tmux split-window -h -t "$window_id"
tmux split-window -v -t "$window_id".1

tmux select-pane -t "$window_id".0 -T "implementer"
tmux select-pane -t "$window_id".1 -T "reviewer-1"
tmux select-pane -t "$window_id".2 -T "reviewer-2"
tmux select-layout -t "$window_id" tiled

tmux send-keys -t "$window_id".0 "clear" C-m
tmux send-keys -t "$window_id".0 "echo 'Implementer pane'" C-m
tmux send-keys -t "$window_id".0 "echo 'Register: $SCRIPT_DIR/register-role.sh $RUN_DIR_Q implementer <agent-name>'" C-m
tmux send-keys -t "$window_id".0 "echo 'Post checkpoint: $SCRIPT_DIR/post-checkpoint.sh $RUN_DIR_Q <step-id> [incremental|full]'" C-m
tmux send-keys -t "$window_id".0 "echo 'Wait reviews: $SCRIPT_DIR/wait-for-reviews.sh $RUN_DIR_Q <request-id>'" C-m
tmux send-keys -t "$window_id".0 "echo 'Heartbeat: $SCRIPT_DIR/heartbeat.sh $RUN_DIR_Q'" C-m

tmux send-keys -t "$window_id".1 "clear" C-m
tmux send-keys -t "$window_id".1 "echo 'Reviewer-1 pane'" C-m
tmux send-keys -t "$window_id".1 "echo 'Register: $SCRIPT_DIR/register-role.sh $RUN_DIR_Q reviewer-1 <agent-name>'" C-m
tmux send-keys -t "$window_id".1 "echo 'Watch: $SCRIPT_DIR/watch-next-request.sh $RUN_DIR_Q reviewer-1'" C-m
tmux send-keys -t "$window_id".1 "echo 'Post review: $SCRIPT_DIR/post-review.sh $RUN_DIR_Q reviewer-1 <request-id> <APPROVE|CHANGES_REQUESTED|BLOCKED|GIVE_UP>'" C-m

tmux send-keys -t "$window_id".2 "clear" C-m
tmux send-keys -t "$window_id".2 "echo 'Reviewer-2 pane'" C-m
tmux send-keys -t "$window_id".2 "echo 'Register: $SCRIPT_DIR/register-role.sh $RUN_DIR_Q reviewer-2 <agent-name>'" C-m
tmux send-keys -t "$window_id".2 "echo 'Watch: $SCRIPT_DIR/watch-next-request.sh $RUN_DIR_Q reviewer-2'" C-m
tmux send-keys -t "$window_id".2 "echo 'Post review: $SCRIPT_DIR/post-review.sh $RUN_DIR_Q reviewer-2 <request-id> <APPROVE|CHANGES_REQUESTED|BLOCKED|GIVE_UP>'" C-m

tmux select-pane -t "$window_id".0

echo "Created tmux window: $window_name"
echo "Run directory: $RUN_DIR"
echo "Status command: $SCRIPT_DIR/status.sh $RUN_DIR"
