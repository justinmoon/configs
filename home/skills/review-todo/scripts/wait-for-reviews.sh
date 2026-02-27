#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<USAGE
Usage: wait-for-reviews.sh <run-dir> <request-id>

Waits for reviews and writes decisions/<request-id>.md.
Exit codes:
  0  PROCEED / PROCEED_TIMEOUT
 10  REWORK
 11  ESCALATE
 12  GIVE_UP
USAGE
    exit 1
}

parse_verdict() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "MISSING"
        return
    fi
    local verdict
    verdict=$(grep -E '^## Verdict:' "$file" | head -1 | sed 's/^## Verdict:[[:space:]]*//')
    if [[ -z "$verdict" ]]; then
        echo "UNKNOWN"
    else
        echo "$verdict"
    fi
}

[[ $# -lt 2 ]] && usage

DIR="$1"
REQUEST_ID="$2"

load_meta "$DIR"

REQUEST_FILE="$DIR/requests/${REQUEST_ID}.md"
if [[ ! -f "$REQUEST_FILE" ]]; then
    echo "Error: request not found: $REQUEST_ID"
    exit 2
fi

REVIEW_1="$DIR/reviews/$REQUEST_ID/reviewer-1.md"
REVIEW_2="$DIR/reviews/$REQUEST_ID/reviewer-2.md"

# Default to 1 reviewer if not set in meta.env
REVIEWER_COUNT="${REVIEWER_COUNT:-1}"

start="$(epoch_now)"
deadline=$((start + IMPLEMENTER_TIMEOUT_SECONDS))
timed_out=0

while true; do
    epoch_now > "$DIR/heartbeats/implementer.epoch"

    if [[ "$REVIEWER_COUNT" -eq 1 ]] && [[ -f "$REVIEW_1" ]]; then
        break
    elif [[ "$REVIEWER_COUNT" -ge 2 ]] && [[ -f "$REVIEW_1" && -f "$REVIEW_2" ]]; then
        break
    fi

    now="$(epoch_now)"
    if [[ "$now" -ge "$deadline" ]]; then
        timed_out=1
        break
    fi

    sleep "$POLL_INTERVAL_SECONDS"
done

v1="$(parse_verdict "$REVIEW_1")"
v2="$(parse_verdict "$REVIEW_2")"

next_action=""
rationale=""
exit_code=12

if [[ "$v1" == "BLOCKED" || "$v2" == "BLOCKED" ]]; then
    next_action="ESCALATE"
    rationale="At least one reviewer marked BLOCKED."
    exit_code=11
elif [[ "$v1" == "CHANGES_REQUESTED" || "$v2" == "CHANGES_REQUESTED" ]]; then
    next_action="REWORK"
    rationale="At least one reviewer requested changes."
    exit_code=10
elif [[ "$REVIEWER_COUNT" -eq 1 ]] && [[ "$v1" == "APPROVE" ]]; then
    next_action="PROCEED"
    rationale="Reviewer approved."
    exit_code=0
elif [[ "$v1" == "APPROVE" && "$v2" == "APPROVE" ]]; then
    next_action="PROCEED"
    rationale="Both reviewers approved."
    exit_code=0
elif [[ "$timed_out" -eq 1 ]]; then
    if { [[ "$v1" == "APPROVE" ]] && [[ "$v2" == "MISSING" || "$v2" == "GIVE_UP" || "$v2" == "UNKNOWN" ]]; } || \
       { [[ "$v2" == "APPROVE" ]] && [[ "$v1" == "MISSING" || "$v1" == "GIVE_UP" || "$v1" == "UNKNOWN" ]]; }; then
        next_action="PROCEED_TIMEOUT"
        rationale="Timed out waiting for second review; one reviewer approved."
        exit_code=0
    else
        next_action="GIVE_UP"
        rationale="Timed out without sufficient approval signal."
        exit_code=12
    fi
else
    next_action="GIVE_UP"
    rationale="Unexpected review state; no deterministic next step."
    exit_code=12
fi

round_num="$(extract_round_num "$REQUEST_ID" || true)"
if [[ -n "$round_num" ]] && [[ "$round_num" -ge "$MAX_ROUNDS_PER_STEP" ]]; then
    if [[ "$next_action" != "PROCEED" && "$next_action" != "PROCEED_TIMEOUT" ]]; then
        next_action="ESCALATE"
        rationale="$rationale Round limit reached ($MAX_ROUNDS_PER_STEP)."
        exit_code=11
    fi
fi

DECISION_FILE="$DIR/decisions/$REQUEST_ID.md"
cat > "$DECISION_FILE" <<EOF_DECISION
# Decision: $REQUEST_ID

## Reviews

- reviewer-1: $v1
- reviewer-2: $v2

## Timed Out

$timed_out

## Next Action: $next_action

## Rationale

$rationale

## Decided At

$(iso_now)
EOF_DECISION

echo "decision-file: $DECISION_FILE"
echo "next-action: $next_action"

exit "$exit_code"
