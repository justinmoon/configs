#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<USAGE
Usage: post-review.sh <run-dir> <reviewer-role> <request-id> <verdict>

Verdicts: APPROVE | CHANGES_REQUESTED | BLOCKED | GIVE_UP
Creates reviews/<request-id>/<reviewer-role>.md and prints filepath.
USAGE
    exit 1
}

[[ $# -lt 4 ]] && usage

DIR="$1"
ROLE="$2"
REQUEST_ID="$3"
VERDICT="$4"

load_meta "$DIR"
validate_reviewer_role "$ROLE"

case "$VERDICT" in
    APPROVE|CHANGES_REQUESTED|BLOCKED|GIVE_UP) ;;
    *)
        echo "Error: invalid verdict '$VERDICT'"
        exit 2
        ;;
esac

if [[ ! -f "$DIR/roles/$ROLE.env" ]]; then
    echo "Error: role has not been claimed: $ROLE"
    exit 2
fi

REQUEST_FILE="$DIR/requests/${REQUEST_ID}.md"
if [[ ! -f "$REQUEST_FILE" ]]; then
    echo "Error: request not found: $REQUEST_ID"
    exit 2
fi

if [[ -f "$DIR/decisions/${REQUEST_ID}.md" ]]; then
    echo "Error: request already decided: $REQUEST_ID"
    exit 1
fi

mkdir -p "$DIR/reviews/$REQUEST_ID"
REVIEW_FILE="$DIR/reviews/$REQUEST_ID/$ROLE.md"

if [[ -f "$REVIEW_FILE" ]]; then
    echo "Review already exists: $REVIEW_FILE"
    exit 1
fi

cat > "$REVIEW_FILE" <<EOF_REVIEW
# Review: $REQUEST_ID

## Reviewer Role

$ROLE

## Verdict: $VERDICT

## Findings

- [severity] [file:path] [finding]

## Required Changes

- [required action]

## Notes

- [additional notes]

## Reviewed At

$(iso_now)
EOF_REVIEW

echo "$REVIEW_FILE"
