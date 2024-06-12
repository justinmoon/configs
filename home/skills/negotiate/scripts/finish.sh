#!/usr/bin/env bash
set -euo pipefail

# Mark negotiation as done. Called by the agent who writes final.md.

usage() {
    echo "Usage: finish.sh <negotiation-dir>"
    exit 1
}

[[ $# -lt 1 ]] && usage

DIR="$1"

# Verify all issues are agreed
OPEN=0
shopt -s nullglob
for issue in "$DIR/issues/"*.md; do
    BASENAME=$(basename "$issue")
    POS_FILE="$DIR/positions/$BASENAME"
    if [[ -f "$POS_FILE" ]]; then
        STATUS=$(grep "^## Status:" "$POS_FILE" | tail -1 | sed 's/^## Status: *//')
        if [[ "$STATUS" != AGREED* ]]; then
            OPEN=$((OPEN + 1))
            echo "NOT AGREED: $BASENAME ($STATUS)"
        fi
    else
        OPEN=$((OPEN + 1))
        echo "NO POSITIONS: $BASENAME"
    fi
done

if [[ "$OPEN" -gt 0 ]]; then
    echo "Error: $OPEN issues not yet agreed. Cannot finish."
    exit 1
fi

if [[ ! -f "$DIR/final.md" ]]; then
    echo "Error: $DIR/final.md not found. Write the final document first."
    exit 1
fi

echo "done" > "$DIR/turn.md"
echo "Negotiation complete. Final document: $DIR/final.md"
