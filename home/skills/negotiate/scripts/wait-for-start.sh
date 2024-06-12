#!/usr/bin/env bash
set -euo pipefail

# Wait until registration is complete and negotiation can begin.
# Returns the agent's turn order (1-indexed).

usage() {
    echo "Usage: wait-for-start.sh <negotiation-dir> <agent-name>"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"
POLL_INTERVAL=$(grep "poll_interval_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+' || echo 5)
EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')
REG_WINDOW=$(grep "registration_window_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+' || echo 30)

echo "Waiting for registration to complete ($EXPECTED agents expected, ${REG_WINDOW}s window)..."

while true; do
    REGISTERED=$(grep -c "^- [a-z]" "$DIR/agents.md" 2>/dev/null || echo 0)

    # Check if all agents registered
    if [[ "$REGISTERED" -ge "$EXPECTED" ]]; then
        echo "All $EXPECTED agents registered."
        break
    fi

    # Check if registration deadline has passed
    DEADLINE=$(grep "registration_deadline:" "$DIR/meta.md" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' || echo "")
    if [[ -n "$DEADLINE" ]]; then
        NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        if [[ "$NOW" > "$DEADLINE" ]] || [[ "$NOW" == "$DEADLINE" ]]; then
            echo "Registration deadline passed. Proceeding with $REGISTERED agents."
            break
        fi
    fi

    sleep "$POLL_INTERVAL"
done

# Determine turn order from registration order
AGENTS=()
while IFS= read -r line; do
    name=$(echo "$line" | sed 's/^- \([a-z][a-z0-9-]*\) .*/\1/')
    AGENTS+=("$name")
done < <(grep "^- [a-z]" "$DIR/agents.md")

# Set turn to first agent
FIRST="${AGENTS[0]}"
echo "$FIRST" > "$DIR/turn.md"

# Find this agent's position
for i in "${!AGENTS[@]}"; do
    if [[ "${AGENTS[$i]}" == "$AGENT" ]]; then
        ORDER=$((i + 1))
        echo "Turn order: $ORDER of ${#AGENTS[@]}"
        echo "Agents: ${AGENTS[*]}"
        echo "First turn: $FIRST"
        exit 0
    fi
done

echo "Error: $AGENT not found in registered agents"
exit 1
