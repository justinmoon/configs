#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Usage: status.sh <run-dir>"
    exit 1
}

parse_verdict() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "MISSING"
        return
    fi
    grep -E '^## Verdict:' "$file" | head -1 | sed 's/^## Verdict:[[:space:]]*//' || echo "UNKNOWN"
}

parse_next_action() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "PENDING"
        return
    fi
    grep -E '^## Next Action:' "$file" | head -1 | sed 's/^## Next Action:[[:space:]]*//' || echo "UNKNOWN"
}

[[ $# -lt 1 ]] && usage

DIR="$1"
load_meta "$DIR"

echo "=== Review Todo Status ==="
echo "Run directory: $DIR"
echo "Todo file: $TODO_FILE"
echo "Strictness: $STRICTNESS"
if [[ -n "${REVIEW_GUIDANCE:-}" ]]; then
    echo "Guidance: $REVIEW_GUIDANCE"
fi

echo ""
echo "Roles:"
for role in implementer reviewer-1 reviewer-2; do
    role_file="$DIR/roles/$role.env"
    if [[ -f "$role_file" ]]; then
        # shellcheck disable=SC1090
        source "$role_file"
        echo "- $role: ${AGENT}"
    else
        echo "- $role: (unclaimed)"
    fi
done

last_progress="0"
if [[ -f "$DIR/heartbeats/implementer.epoch" ]]; then
    last_progress="$(cat "$DIR/heartbeats/implementer.epoch" | head -1)"
fi

if echo "$last_progress" | grep -qE '^[0-9]+$'; then
    now="$(epoch_now)"
    age=$((now - last_progress))
    echo ""
    echo "Implementer heartbeat age: ${age}s"
fi

echo ""
echo "Requests:"

shopt -s nullglob
REQUEST_COUNT="$(find "$DIR/requests" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')"

if [[ "$REQUEST_COUNT" -eq 0 ]]; then
    echo "(none)"
    exit 0
fi

while IFS= read -r req; do
    id="$(basename "$req" .md)"
    v1="$(parse_verdict "$DIR/reviews/$id/reviewer-1.md")"
    v2="$(parse_verdict "$DIR/reviews/$id/reviewer-2.md")"
    action="$(parse_next_action "$DIR/decisions/$id.md")"
    echo "- $id"
    echo "  reviewer-1: $v1"
    echo "  reviewer-2: $v2"
    echo "  decision: $action"
done < <(find "$DIR/requests" -maxdepth 1 -name "*.md" -type f | sort)
