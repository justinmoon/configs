#!/usr/bin/env bash
set -euo pipefail

# Hand off turn to the next agent in rotation.

usage() {
    echo "Usage: hand-off.sh <negotiation-dir> <agent-name>"
    echo ""
    echo "Passes the turn to the next agent after <agent-name>."
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

# Read agent list in registration order
AGENTS=()
while IFS= read -r line; do
    name=$(echo "$line" | sed 's/^- \([a-z][a-z0-9-]*\) .*/\1/')
    AGENTS+=("$name")
done < <(grep "^- [a-z]" "$DIR/agents.md")

NUM=${#AGENTS[@]}
if [[ "$NUM" -eq 0 ]]; then
    echo "Error: No agents registered"
    exit 1
fi

# Find current agent and compute next
for i in "${!AGENTS[@]}"; do
    if [[ "${AGENTS[$i]}" == "$AGENT" ]]; then
        NEXT_IDX=$(( (i + 1) % NUM ))
        NEXT="${AGENTS[$NEXT_IDX]}"
        echo "$NEXT" > "$DIR/turn.md"
        rm -f "$DIR/.turn-started"
        echo "Turn handed to: $NEXT"
        exit 0
    fi
done

echo "Error: $AGENT not found in agent list"
exit 1
