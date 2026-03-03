#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: register.sh <negotiation-dir> <agent-name>"
    echo ""
    echo "Register an agent for the negotiation."
    echo "Returns 0 on success, 1 if already registered, 2 on error, 4 if participant already registered under another name."
    echo ""
    echo "Participant identity precedence:"
    echo "  1) CODEX_THREAD_ID / CLAUDE_SESSION_ID / CLAUDE_CODE_SESSION_ID (if set)"
    echo "  2) NEGOTIATE_PARTICIPANT_ID (if set)"
    echo "  3) Fallback fingerprint from host/user/tmux/process context"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

if [[ ! -f "$DIR/agents.md" ]]; then
    echo "Error: No negotiation found at $DIR"
    exit 2
fi

# Validate agent name (lowercase, hyphens, numbers)
if ! echo "$AGENT" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Agent name must be lowercase alphanumeric with hyphens, got: $AGENT"
    exit 2
fi

build_participant_id() {
    local raw=""
    if [[ -n "${CODEX_THREAD_ID:-}" ]]; then
        raw="codex:${CODEX_THREAD_ID}"
    elif [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        raw="claude:${CLAUDE_SESSION_ID}"
    elif [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
        raw="claude:${CLAUDE_CODE_SESSION_ID}"
    elif [[ -n "${NEGOTIATE_PARTICIPANT_ID:-}" ]]; then
        raw="manual:${NEGOTIATE_PARTICIPANT_ID}"
    else
        local host user pane ppid
        host=$(hostname 2>/dev/null || echo unknown-host)
        user="${USER:-unknown-user}"
        pane="${TMUX_PANE:-no-pane}"
        ppid="${PPID:-no-ppid}"
        raw="fallback:${host}:${user}:${pane}:${ppid}"
    fi

    # Keep IDs grep-safe and readable in markdown metadata.
    printf '%s' "$raw" | tr -c 'A-Za-z0-9._:-' '-' | sed 's/^-*//; s/-*$//'
}

PARTICIPANT_ID="$(build_participant_id)"
if [[ -z "$PARTICIPANT_ID" ]]; then
    echo "Error: Could not compute participant identity"
    exit 2
fi

acquire_lock() {
    local lockdir="$1"
    local attempts=200
    while (( attempts > 0 )); do
        if mkdir "$lockdir" 2>/dev/null; then
            return 0
        fi
        attempts=$((attempts - 1))
        sleep 0.05
    done
    return 1
}

LOCKDIR="$DIR/.register.lock"
if ! acquire_lock "$LOCKDIR"; then
    echo "Error: Timed out waiting for registration lock"
    exit 2
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

# Check if already registered by name
if grep -q "^- $AGENT " "$DIR/agents.md" 2>/dev/null; then
    echo "Already registered: $AGENT"
    exit 1
fi

# Enforce one name per real participant.
if grep -q "participant: $PARTICIPANT_ID" "$DIR/agents.md" 2>/dev/null; then
    EXISTING_NAME=$(grep "participant: $PARTICIPANT_ID" "$DIR/agents.md" | sed -n 's/^- \([a-z][a-z0-9-]*\) .*/\1/p' | head -1)
    echo "Error: Participant already registered as $EXISTING_NAME (participant: $PARTICIPANT_ID)"
    echo "A single session/process may not register multiple agent names."
    exit 4
fi

# Append registration
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "- $AGENT (registered: $TIMESTAMP, participant: $PARTICIPANT_ID)" >> "$DIR/agents.md"

# Count registered agents
REGISTERED=$(grep -c "^- " "$DIR/agents.md" 2>/dev/null || echo 0)

# Read expected agents from meta.md
EXPECTED=$(grep "expected_agents:" "$DIR/meta.md" | grep -oE '[0-9]+')

echo "Registered: $AGENT ($REGISTERED/$EXPECTED agents, participant: $PARTICIPANT_ID)"

# If this is the first agent, record the registration start time
if [[ "$REGISTERED" -eq 1 ]]; then
    REG_WINDOW=$(grep "registration_window_seconds:" "$DIR/meta.md" | grep -oE '[0-9]+')
    if command -v gdate &>/dev/null; then
        DEADLINE=$(gdate -u -d "+${REG_WINDOW} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${REG_WINDOW}S +%Y-%m-%dT%H:%M:%SZ)
    else
        DEADLINE=$(date -u -v+${REG_WINDOW}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${REG_WINDOW} seconds" +%Y-%m-%dT%H:%M:%SZ)
    fi
    if ! grep -q "registration_deadline:" "$DIR/meta.md"; then
        echo "- **registration_deadline:** $DEADLINE" >> "$DIR/meta.md"
    fi
    echo "Registration window started. Deadline: $DEADLINE"
fi

# If all agents registered, signal ready
if [[ "$REGISTERED" -ge "$EXPECTED" ]]; then
    echo "All agents registered. Negotiation can begin."
fi
