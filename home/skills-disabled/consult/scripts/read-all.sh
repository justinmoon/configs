#!/usr/bin/env bash
set -euo pipefail

# Print all findings from other agents (excludes your own).

usage() {
    echo "Usage: read-all.sh <consult-dir> <agent-name>"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

for AGENT_DIR in "$DIR"/findings/*/; do
    OTHER=$(basename "$AGENT_DIR")
    [[ "$OTHER" == "$AGENT" ]] && continue
    [[ ! -d "$AGENT_DIR" ]] && continue

    FILES=$(find "$AGENT_DIR" -name "*.md" -maxdepth 1 2>/dev/null | sort)
    if [[ -z "$FILES" ]]; then
        continue
    fi

    echo "=========================================="
    echo "FINDINGS FROM: $OTHER"
    echo "=========================================="
    echo ""

    for f in $FILES; do
        echo "--- $(basename "$f") ---"
        cat "$f"
        echo ""
    done
done
