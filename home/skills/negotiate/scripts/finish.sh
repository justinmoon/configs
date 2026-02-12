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

if [[ ! -f "$DIR/coverage-audit.md" ]]; then
    echo "Error: $DIR/coverage-audit.md not found."
    echo "You must write a coverage audit before finishing."
    echo "List unique elements from each source proposal and whether they appear in final.md."
    exit 1
fi

# Verify challenge-before-agree: each AGREED issue must have a challenge entry
# from the agent who marked it agreed (not just the proposer).
CHALLENGE_MISSING=0
for issue in "$DIR/issues/"*.md; do
    BASENAME=$(basename "$issue")
    POS_FILE="$DIR/positions/$BASENAME"
    if [[ -f "$POS_FILE" ]]; then
        STATUS=$(grep "^## Status:" "$POS_FILE" | tail -1 | sed 's/^## Status: *//')
        if [[ "$STATUS" == AGREED* ]]; then
            # Check that at least one challenge entry exists
            if ! grep -q "'s challenge" "$POS_FILE" 2>/dev/null; then
                CHALLENGE_MISSING=$((CHALLENGE_MISSING + 1))
                echo "MISSING CHALLENGE: $BASENAME — no agent wrote a challenge round before agreeing"
            fi
        fi
    fi
done

if [[ "$CHALLENGE_MISSING" -gt 0 ]]; then
    echo "Error: $CHALLENGE_MISSING issues were agreed without a challenge round."
    echo "Each issue requires at least one devil's advocate challenge before agreement."
    exit 1
fi

echo "done" > "$DIR/turn.md"
echo "Negotiation complete. Final document: $DIR/final.md"
