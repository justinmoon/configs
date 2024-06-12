#!/usr/bin/env bash
set -euo pipefail

# Check if it's this agent's turn.
# Also handles turn timeout: if the current turn-holder hasn't acted
# within turn_timeout_seconds, skip them.
#
# Exits 0 if it's your turn, 1 if not, 2 if done.

usage() {
    echo "Usage: poll.sh <negotiation-dir> <agent-name>"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

TURN=$(cat "$DIR/turn.md" 2>/dev/null | tr -d '[:space:]')

if [[ "$TURN" == "done" ]]; then
    echo "done"
    exit 2
fi

if [[ "$TURN" == "$AGENT" ]]; then
    # Record that we've started our turn
    if [[ ! -f "$DIR/.turn-started" ]] || [[ "$(cat "$DIR/.turn-started" | head -1)" != "$AGENT" ]]; then
        echo "$AGENT" > "$DIR/.turn-started"
        if command -v gdate &>/dev/null; then
            gdate -u +%s >> "$DIR/.turn-started"
        else
            date -u +%s >> "$DIR/.turn-started"
        fi
    fi
    echo "your-turn"
    exit 0
fi

# Not our turn. Check for turn timeout (default 120s = 2 minutes).
TURN_TIMEOUT=$(grep "turn_timeout_seconds:" "$DIR/meta.md" 2>/dev/null | grep -oE '[0-9]+' || echo 120)

if [[ -f "$DIR/.turn-started" ]]; then
    TURN_AGENT=$(head -1 "$DIR/.turn-started")
    TURN_START=$(tail -1 "$DIR/.turn-started")
    if command -v gdate &>/dev/null; then
        NOW=$(gdate -u +%s)
    else
        NOW=$(date -u +%s)
    fi

    if [[ "$TURN_AGENT" == "$TURN" ]] && [[ $((NOW - TURN_START)) -gt "$TURN_TIMEOUT" ]]; then
        echo "Turn timeout: $TURN has been inactive for $((NOW - TURN_START))s (limit: ${TURN_TIMEOUT}s). Skipping."
        # Find next agent after the stalled one
        AGENTS=()
        while IFS= read -r line; do
            name=$(echo "$line" | sed 's/^- \([a-z][a-z0-9-]*\) .*/\1/')
            AGENTS+=("$name")
        done < <(grep "^- [a-z]" "$DIR/agents.md")

        for i in "${!AGENTS[@]}"; do
            if [[ "${AGENTS[$i]}" == "$TURN" ]]; then
                NEXT_IDX=$(( (i + 1) % ${#AGENTS[@]} ))
                NEXT="${AGENTS[$NEXT_IDX]}"
                echo "$NEXT" > "$DIR/turn.md"
                rm -f "$DIR/.turn-started"
                echo "Skipped $TURN, turn passed to $NEXT"
                # If the next agent is us, it's our turn now
                if [[ "$NEXT" == "$AGENT" ]]; then
                    echo "your-turn"
                    exit 0
                fi
                break
            fi
        done
    fi
fi

echo "waiting (current turn: $TURN)"
exit 1
