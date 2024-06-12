#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: register.sh <negotiation-dir> <agent-name>"
    echo ""
    echo "Register an agent for the negotiation."
    echo "Returns 0 on success, 1 if already registered, 2 on error."
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

if [[ ! -f "$DIR/agents.md" ]]; then
    echo "Error: No negotiation found at $DIR"
    exit 2
fi

# Check if already registered
if grep -q "^- $AGENT " "$DIR/agents.md" 2>/dev/null; then
    echo "Already registered: $AGENT"
    exit 1
fi

# Validate agent name (lowercase, hyphens, numbers)
if ! echo "$AGENT" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Agent name must be lowercase alphanumeric with hyphens, got: $AGENT"
    exit 2
fi

# Append registration
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "- $AGENT (registered: $TIMESTAMP)" >> "$DIR/agents.md"

# Count registered agents
REGISTERED=$(grep -c "^- " "$DIR/agents.md" 2>/dev/null || echo 0)

# Read expected agents from meta.md
EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')

echo "Registered: $AGENT ($REGISTERED/$EXPECTED agents)"

# If this is the first agent, record the registration start time
if [[ "$REGISTERED" -eq 1 ]]; then
    REG_WINDOW=$(grep "registration_window_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+')
    if command -v gdate &>/dev/null; then
        DEADLINE=$(gdate -u -d "+${REG_WINDOW} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${REG_WINDOW}S +%Y-%m-%dT%H:%M:%SZ)
    else
        DEADLINE=$(date -u -v+${REG_WINDOW}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${REG_WINDOW} seconds" +%Y-%m-%dT%H:%M:%SZ)
    fi
    echo "- **registration_deadline:** $DEADLINE" >> "$DIR/meta.md"
    echo "Registration window started. Deadline: $DEADLINE"
fi

# If all agents registered, signal ready
if [[ "$REGISTERED" -ge "$EXPECTED" ]]; then
    echo "All agents registered. Negotiation can begin."
fi
