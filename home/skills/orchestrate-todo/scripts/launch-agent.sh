#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<USAGE
Usage: launch-agent.sh <harness> <prompt> <logfile> [cwd]

Launches an agent in the background using the specified harness.
Prints the PID on stdout.

Harnesses: codex, claude, pi, droid
USAGE
    exit 1
}

[[ $# -lt 3 ]] && usage

HARNESS="$1"
PROMPT="$2"
LOGFILE="$3"
CWD="${4:-$(pwd)}"

case "$HARNESS" in
    codex)
        cd "$CWD" && codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT" > "$LOGFILE" 2>&1 &
        ;;
    claude)
        cd "$CWD" && claude --dangerously-skip-permissions -p "$PROMPT" > "$LOGFILE" 2>&1 &
        ;;
    pi)
        cd "$CWD" && pi -p "$PROMPT" > "$LOGFILE" 2>&1 &
        ;;
    droid)
        cd "$CWD" && droid exec --skip-permissions-unsafe "$PROMPT" > "$LOGFILE" 2>&1 &
        ;;
    *)
        echo "Unknown harness: $HARNESS" >&2
        exit 1
        ;;
esac

echo $!
