#!/usr/bin/env bash
set -euo pipefail

# Wait until registration is complete and negotiation can begin.
# Returns the agent's turn order (1-indexed).

usage() {
    echo "Usage: wait-for-start.sh <negotiation-dir> <agent-name>"
    echo ""
    echo "Exit codes:"
    echo "  0 - Ready to start negotiation"
    echo "  2 - Not enough independent participants (or duplicate participant identity)"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"
POLL_INTERVAL=$(grep "poll_interval_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+' || echo 5)
EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')
REG_WINDOW=$(grep "registration_window_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+' || echo 30)

echo "Waiting for registration to complete ($EXPECTED agents expected, ${REG_WINDOW}s window)..."

REGISTERED=0
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
            echo "Registration deadline passed."
            break
        fi
    fi

    sleep "$POLL_INTERVAL"
done

if [[ "$REGISTERED" -lt "$EXPECTED" ]]; then
    if [[ "${NEGOTIATE_ALLOW_PARTIAL_REGISTRATION:-0}" == "1" ]]; then
        echo "WARNING: Proceeding with $REGISTERED/$EXPECTED registered agents because NEGOTIATE_ALLOW_PARTIAL_REGISTRATION=1"
    else
        echo "Error: Only $REGISTERED/$EXPECTED agents registered."
        echo "Refusing to proceed with a partial negotiation."
        echo "Start additional agents or explicitly opt into fallback with NEGOTIATE_ALLOW_PARTIAL_REGISTRATION=1."
        exit 2
    fi
fi

# Determine turn order from registration order
AGENTS=()
PARTICIPANTS=()
while IFS= read -r line; do
    name=$(echo "$line" | sed 's/^- \([a-z][a-z0-9-]*\) .*/\1/')
    AGENTS+=("$name")
    participant=$(echo "$line" | sed -n 's/.*participant: \([^)]*\)).*/\1/p')
    if [[ -n "$participant" ]]; then
        PARTICIPANTS+=("$participant")
    else
        # Backward compatibility for older registrations that don't include participant metadata.
        PARTICIPANTS+=("legacy:$name")
    fi
done < <(grep "^- [a-z]" "$DIR/agents.md")

# Ensure each registration represents a distinct participant identity.
DUPLICATE_PARTICIPANT=$(printf '%s\n' "${PARTICIPANTS[@]}" | sort | uniq -d | head -1 || true)
if [[ -n "$DUPLICATE_PARTICIPANT" ]]; then
    echo "Error: Duplicate participant identity detected: $DUPLICATE_PARTICIPANT"
    echo "One session appears to have registered multiple agent names."
    echo "Aborting negotiation to preserve independent-adversary guarantees."
    exit 2
fi

# Set turn to first agent
FIRST="${AGENTS[0]}"
if [[ -z "${FIRST:-}" ]]; then
    echo "Error: No agents registered"
    exit 2
fi
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
