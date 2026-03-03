#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: register.sh <consult-dir> <agent-name>"
    echo ""
    echo "Exit codes: 0=success, 1=already registered, 2=error"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

if [[ ! -f "$DIR/agents.md" ]]; then
    echo "Error: No consultation found at $DIR"
    exit 2
fi

if grep -q "^- $AGENT " "$DIR/agents.md" 2>/dev/null; then
    echo "Already registered: $AGENT"
    exit 1
fi

if ! echo "$AGENT" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Agent name must be lowercase alphanumeric with hyphens, got: $AGENT"
    exit 2
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "- $AGENT (registered: $TIMESTAMP)" >> "$DIR/agents.md"

mkdir -p "$DIR/findings/$AGENT"

REGISTERED=$(grep -c "^- " "$DIR/agents.md" 2>/dev/null || echo 0)
EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')

echo "Registered: $AGENT ($REGISTERED/$EXPECTED agents)"

if [[ "$REGISTERED" -eq 1 ]]; then
    TIMEOUT=$(grep "timeout_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+')
    if command -v gdate &>/dev/null; then
        DEADLINE=$(gdate -u -d "+${TIMEOUT} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${TIMEOUT}S +%Y-%m-%dT%H:%M:%SZ)
    else
        DEADLINE=$(date -u -v+${TIMEOUT}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${TIMEOUT} seconds" +%Y-%m-%dT%H:%M:%SZ)
    fi
    echo "- **deadline:** $DEADLINE" >> "$DIR/meta.md"
fi
