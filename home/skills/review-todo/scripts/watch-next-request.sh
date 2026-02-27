#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<USAGE
Usage: watch-next-request.sh <run-dir> <reviewer-role>

Blocks until a pending request is found for this reviewer.
Exit codes:
  0 -> request found
  2 -> run is done
  3 -> reviewer idle timeout reached (no implementer progress)
USAGE
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
ROLE="$2"

load_meta "$DIR"
validate_reviewer_role "$ROLE"

if [[ ! -f "$DIR/roles/$ROLE.env" ]]; then
    echo "Error: role has not been claimed: $ROLE"
    exit 2
fi

while true; do
    STATE="$(cat "$DIR/state.md" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$STATE" == "done" ]]; then
        echo "run-done"
        exit 2
    fi

    while IFS= read -r request_file; do
        request_id="$(basename "$request_file" .md)"
        decision_file="$DIR/decisions/$request_id.md"
        review_file="$DIR/reviews/$request_id/$ROLE.md"

        if [[ -f "$decision_file" ]]; then
            continue
        fi

        if [[ ! -f "$review_file" ]]; then
            echo "request-id: $request_id"
            echo "request-file: $request_file"
            exit 0
        fi
    done < <(find "$DIR/requests" -maxdepth 1 -name "*.md" -type f | sort)

    last_progress=0
    if [[ -f "$DIR/heartbeats/implementer.epoch" ]]; then
        last_progress="$(cat "$DIR/heartbeats/implementer.epoch" | head -1)"
    fi

    if [[ -z "$last_progress" ]] || ! echo "$last_progress" | grep -qE '^[0-9]+$'; then
        last_progress=0
    fi

    now="$(epoch_now)"
    idle_for=$((now - last_progress))
    if [[ "$idle_for" -ge "$REVIEWER_IDLE_TIMEOUT_SECONDS" ]]; then
        echo "reviewer-idle-timeout (${idle_for}s without implementer progress)"
        exit 3
    fi

    sleep "$POLL_INTERVAL_SECONDS"
done
