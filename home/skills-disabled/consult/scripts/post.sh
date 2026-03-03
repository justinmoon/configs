#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: post.sh <consult-dir> <agent-name> <short-topic>"
    echo ""
    echo "Creates an auto-numbered finding file and prints its path."
    echo "The agent should then write content to the printed path."
    exit 1
}

[[ $# -lt 3 ]] && usage

DIR="$1"
AGENT="$2"
TOPIC="$3"

AGENT_DIR="$DIR/findings/$AGENT"

if [[ ! -d "$AGENT_DIR" ]]; then
    echo "Error: Agent $AGENT not registered (no findings directory)"
    exit 1
fi

SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

EXISTING=$(find "$AGENT_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
NUM=$(printf "%02d" $((EXISTING + 1)))

FILEPATH="$AGENT_DIR/${NUM}-${SLUG}.md"
touch "$FILEPATH"

echo "$FILEPATH"
