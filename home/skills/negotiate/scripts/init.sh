#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: init.sh <negotiation-dir> <num-agents> [registration-window-secs]"
    echo ""
    echo "  negotiation-dir:         Path to create the negotiation directory"
    echo "  num-agents:              Number of agents expected to participate"
    echo "  registration-window-secs: Seconds to wait for all agents (default: 120)"
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
REG_WINDOW="${3:-120}"

# Atomic directory creation — only one agent can succeed.
# mkdir (without -p) fails if the directory already exists.
if ! mkdir "$DIR" 2>/dev/null; then
    echo "Already initialized: $DIR (another agent got here first)"
    echo "You should join as a participant instead."
    exit 3
fi

mkdir -p "$DIR"/{sources,issues,positions}

# meta.md — negotiation configuration
cat > "$DIR/meta.md" << EOF
# Negotiation Metadata

- **expected_agents:** $NUM_AGENTS
- **registration_window_seconds:** $REG_WINDOW
- **max_rounds_per_agent:** 5
- **poll_interval_seconds:** 5
- **turn_timeout_seconds:** 600
- **created:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# agents.md — empty, agents register here
cat > "$DIR/agents.md" << 'EOF'
# Registered Agents

<!-- Agents append a line: "- agent-name (registered: timestamp)" -->
<!-- Do NOT edit other agents' lines -->
EOF

# turn.md — starts as "registration"
echo "registration" > "$DIR/turn.md"

# topic.md — placeholder for the initializer to fill in
cat > "$DIR/topic.md" << 'EOF'
# Negotiation Topic

<!-- Describe what is being negotiated. What question(s) need resolution? -->
<!-- Reference source documents in sources/ if applicable. -->
EOF

echo "Negotiation initialized at: $DIR"
echo "Expected agents: $NUM_AGENTS"
echo "Registration window: ${REG_WINDOW}s"
