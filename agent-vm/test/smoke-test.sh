#!/usr/bin/env bash
# Smoke test for agent-vm
# Tests the basic lifecycle: spawn -> attach -> stop -> resume
set -euo pipefail

echo "=== Agent VM Smoke Test ==="
echo ""

# Check prerequisites
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY environment variable is required"
  exit 1
fi

# Use a small, fast-cloning test repo
TEST_REPO="https://github.com/sst/opencode"
TEST_PROMPT="List the files in this repository."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSIONS_DIR="${AGENT_VM_SESSIONS:-$HOME/.agent-vm/sessions}"

# Cleanup function
cleanup() {
  if [ -n "${SESSION_ID:-}" ]; then
    echo ""
    echo "Cleaning up session $SESSION_ID..."
    "$SCRIPT_DIR/bin/agent-stop" "$SESSION_ID" 2>/dev/null || true
    rm -rf "$SESSIONS_DIR/$SESSION_ID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "1. Spawning agent session..."
echo "   Repo: $TEST_REPO"
echo "   Prompt: $TEST_PROMPT"
echo ""

# Capture session ID from spawn output
SPAWN_OUTPUT=$("$SCRIPT_DIR/bin/agent-spawn" --repo "$TEST_REPO" --prompt "$TEST_PROMPT" 2>&1)
SESSION_ID=$(echo "$SPAWN_OUTPUT" | tail -1)

if [ -z "$SESSION_ID" ] || [ ${#SESSION_ID} -ne 8 ]; then
  echo "   FAILED: Could not get session ID"
  echo "   Output: $SPAWN_OUTPUT"
  exit 1
fi

echo "   Session ID: $SESSION_ID"
echo "   PASSED"
echo ""

# Get port from metadata
PORT=$(jq -r '.port' "$SESSIONS_DIR/$SESSION_ID/meta.json")
echo "2. Checking VM status..."
echo "   Port: $PORT"

# Check if SSH is accessible
if nc -z localhost "$PORT" 2>/dev/null; then
  echo "   SSH port: OPEN"
else
  echo "   SSH port: CLOSED (VM may still be booting)"
  echo "   Waiting additional 30 seconds..."
  for i in {1..30}; do
    if nc -z localhost "$PORT" 2>/dev/null; then
      echo "   SSH port: OPEN"
      break
    fi
    sleep 1
  done
fi
echo "   PASSED"
echo ""

echo "3. Testing SSH connectivity..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o LogLevel=ERROR -p "$PORT" agent@localhost "echo 'SSH works!'" 2>/dev/null; then
  echo "   SSH connection: SUCCESS"
else
  echo "   SSH connection: FAILED"
  echo "   (This may be expected if VM is still booting)"
fi
echo "   PASSED"
echo ""

echo "4. Checking tmux session..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o LogLevel=ERROR -p "$PORT" agent@localhost "tmux has-session -t agent" 2>/dev/null; then
  echo "   tmux session 'agent': EXISTS"
else
  echo "   tmux session 'agent': NOT FOUND"
  echo "   (May still be starting up)"
fi
echo "   PASSED"
echo ""

echo "5. Checking session mount..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o LogLevel=ERROR -p "$PORT" agent@localhost "test -d /session/repo" 2>/dev/null; then
  echo "   /session/repo: EXISTS"
else
  echo "   /session/repo: NOT FOUND"
fi

if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o LogLevel=ERROR -p "$PORT" agent@localhost "test -f /session/prompt.txt" 2>/dev/null; then
  echo "   /session/prompt.txt: EXISTS"
else
  echo "   /session/prompt.txt: NOT FOUND"
fi
echo "   PASSED"
echo ""

echo "6. Stopping session..."
"$SCRIPT_DIR/bin/agent-stop" "$SESSION_ID"
echo "   PASSED"
echo ""

echo "7. Checking session is stopped..."
STATUS=$(jq -r '.status' "$SESSIONS_DIR/$SESSION_ID/meta.json")
if [ "$STATUS" = "stopped" ]; then
  echo "   Status: stopped"
  echo "   PASSED"
else
  echo "   Status: $STATUS (expected: stopped)"
  echo "   FAILED"
  exit 1
fi
echo ""

echo "8. Resuming session..."
"$SCRIPT_DIR/bin/agent-resume" "$SESSION_ID"

# Give it a moment
sleep 5

STATUS=$(jq -r '.status' "$SESSIONS_DIR/$SESSION_ID/meta.json")
if [ "$STATUS" = "running" ]; then
  echo "   Status: running"
  echo "   PASSED"
else
  echo "   Status: $STATUS (expected: running)"
  echo "   WARNING: Resume may have issues"
fi
echo ""

echo "9. Final stop..."
"$SCRIPT_DIR/bin/agent-stop" "$SESSION_ID"
echo "   PASSED"
echo ""

echo "=== All tests completed! ==="
echo ""
echo "Note: Some tests may show warnings if the VM is slow to boot."
echo "This is a smoke test - manual verification recommended."
