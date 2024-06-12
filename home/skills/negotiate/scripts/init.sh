#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: init.sh <negotiation-dir> <num-agents> [registration-window-secs]"
    echo ""
    echo "  negotiation-dir:         Path to create the negotiation directory"
    echo "  num-agents:              Number of agents expected to participate"
    echo "  registration-window-secs: Seconds to wait for all agents (default: 30)"
    echo ""
    echo "After init, populate:"
    echo "  <dir>/sources/     - Source documents agents should read"
    echo "  <dir>/issues/      - Initial issues (NN-topic.md)"
    echo ""
    echo "Or let the first agent create issues from the sources."
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
NUM_AGENTS="$2"
REG_WINDOW="${3:-30}"

if [[ -d "$DIR" ]]; then
    echo "Error: $DIR already exists"
    exit 1
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

# topic.md — placeholder for the user/orchestrator to fill in
cat > "$DIR/topic.md" << 'EOF'
# Negotiation Topic

<!-- Describe what is being negotiated. What question(s) need resolution? -->
<!-- Reference source documents in sources/ if applicable. -->
EOF

echo "Negotiation initialized at: $DIR"
echo "Expected agents: $NUM_AGENTS"
echo "Registration window: ${REG_WINDOW}s"
echo ""
echo "Next steps:"
echo "  1. Edit $DIR/topic.md with the negotiation topic"
echo "  2. Add source documents to $DIR/sources/"
echo "  3. Optionally add initial issues to $DIR/issues/"
echo "  4. Tell each agent to join: 'Join the negotiation at $DIR'"
