#!/usr/bin/env bash
set -euo pipefail

# Poll until all agents have posted findings and marked ready, or timeout.
# Exit 0 = all ready, exit 1 = still waiting, exit 2 = timeout (read what's there)

usage() {
    echo "Usage: poll.sh <consult-dir> <agent-name>"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')
READY_COUNT=$(find "$DIR/findings" -name ".ready" -maxdepth 2 | wc -l | tr -d ' ')

if [[ "$READY_COUNT" -ge "$EXPECTED" ]]; then
    echo "all-ready ($READY_COUNT/$EXPECTED agents)"
    exit 0
fi

# Check deadline
DEADLINE=$(grep "deadline:" "$DIR/meta.md" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' || echo "")
if [[ -n "$DEADLINE" ]]; then
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [[ "$NOW" > "$DEADLINE" ]] || [[ "$NOW" == "$DEADLINE" ]]; then
        echo "timeout ($READY_COUNT/$EXPECTED agents ready, deadline passed)"
        exit 2
    fi
fi

echo "waiting ($READY_COUNT/$EXPECTED agents ready)"
exit 1
