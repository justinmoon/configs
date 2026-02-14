#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: init.sh <consult-dir> <num-agents> [timeout-secs]"
    echo ""
    echo "  consult-dir:   Path to create the consultation directory"
    echo "  num-agents:    Number of agents expected to participate"
    echo "  timeout-secs:  Max seconds to wait for all agents (default: 120)"
    echo ""
    echo "Exit codes:"
    echo "  0 - Initialized successfully (you are the initializer)"
    echo "  3 - Directory already exists (another agent initialized; you should join)"
    echo "  1 - Other error"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
NUM_AGENTS="$2"
TIMEOUT="${3:-120}"

if ! mkdir "$DIR" 2>/dev/null; then
    echo "Already initialized: $DIR"
    exit 3
fi

mkdir -p "$DIR"/findings

cat > "$DIR/meta.md" << EOF
- **expected_agents:** $NUM_AGENTS
- **timeout_seconds:** $TIMEOUT
- **poll_interval_seconds:** 5
- **created:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

cat > "$DIR/agents.md" << 'EOF'
# Registered Agents
EOF

echo "Consultation initialized at: $DIR"
echo "Expected agents: $NUM_AGENTS"
echo "Timeout: ${TIMEOUT}s"
