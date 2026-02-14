#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: ready.sh <consult-dir> <agent-name>"
    echo ""
    echo "Marks this agent as done posting findings."
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

if [[ ! -d "$DIR/findings/$AGENT" ]]; then
    echo "Error: Agent $AGENT not registered"
    exit 1
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$TIMESTAMP" > "$DIR/findings/$AGENT/.ready"

EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')
READY_COUNT=$(find "$DIR/findings" -name ".ready" -maxdepth 2 | wc -l | tr -d ' ')

echo "Agent $AGENT marked ready ($READY_COUNT/$EXPECTED)"
