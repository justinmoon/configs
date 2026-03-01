#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<USAGE
Usage: post-checkpoint.sh <run-dir> <step-id> [incremental|full]

Creates requests/<step-id>-round-<NN>.md and prints request id + filepath.
Exit codes: 0=ok, 4=round limit reached, 5=dirty git delta, 1/2=error
USAGE
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
STEP_ID="$2"
SCOPE="${3:-incremental}"

load_meta "$DIR"
validate_step_id "$STEP_ID"

case "$SCOPE" in
    incremental|full) ;;
    *)
        echo "Error: scope must be incremental or full, got: $SCOPE"
        exit 2
        ;;
esac

if [[ ! -f "$DIR/roles/implementer.env" ]]; then
    echo "Error: implementer role has not been claimed"
    exit 2
fi

ensure_checkpoint_git_clean() {
    local dir="$1"
    local git_root="${GIT_WORKTREE_ROOT:-}"
    local baseline_file="$dir/git-status-baseline.porcelain"
    local current_file
    local baseline_sorted
    local current_sorted
    local new_entries

    [[ -z "$git_root" ]] && return 0

    if [[ ! -d "$git_root" ]]; then
        echo "Error: recorded git worktree root is missing: $git_root"
        exit 2
    fi

    if [[ ! -f "$baseline_file" ]]; then
        echo "Error: git status baseline file missing: $baseline_file"
        exit 2
    fi

    current_file="$(mktemp)"
    baseline_sorted="$(mktemp)"
    current_sorted="$(mktemp)"
    new_entries="$(mktemp)"

    git -C "$git_root" status --porcelain=v1 --untracked-files=all > "$current_file"
    LC_ALL=C sort -u "$baseline_file" > "$baseline_sorted"
    LC_ALL=C sort -u "$current_file" > "$current_sorted"
    comm -13 "$baseline_sorted" "$current_sorted" > "$new_entries" || true

    if [[ -s "$new_entries" ]]; then
        echo "Error: new uncommitted git status entries detected since review run init."
        echo "Commit/stash current step changes before posting a checkpoint."
        echo "Pre-existing uncommitted entries from init baseline are ignored."
        echo ""
        echo "New entries:"
        sed 's/^/  /' "$new_entries"
        rm -f "$current_file" "$baseline_sorted" "$current_sorted" "$new_entries"
        exit 5
    fi

    rm -f "$current_file" "$baseline_sorted" "$current_sorted" "$new_entries"
}

ensure_checkpoint_git_clean "$DIR"

HEAD_COMMIT="(n/a)"
if [[ -n "${GIT_WORKTREE_ROOT:-}" ]]; then
    HEAD_COMMIT="$(git -C "$GIT_WORKTREE_ROOT" rev-parse HEAD 2>/dev/null || echo "(unknown)")"
fi

MAX=0
shopt -s nullglob
for f in "$DIR/requests/${STEP_ID}-round-"*.md; do
    base="$(basename "$f")"
    n="$(echo "$base" | sed -n 's/.*-round-\([0-9][0-9]*\)\.md$/\1/p')"
    [[ -z "$n" ]] && continue
    num=$((10#$n))
    if [[ "$num" -gt "$MAX" ]]; then
        MAX="$num"
    fi
done

NEXT=$((MAX + 1))
if [[ "$NEXT" -gt "$MAX_ROUNDS_PER_STEP" ]]; then
    echo "Round limit reached for $STEP_ID ($MAX_ROUNDS_PER_STEP rounds)."
    exit 4
fi

PADDED="$(pad2 "$NEXT")"
REQUEST_ID="${STEP_ID}-round-${PADDED}"
REQUEST_FILE="$DIR/requests/${REQUEST_ID}.md"

cat > "$REQUEST_FILE" <<EOF_REQ
# Review Request: $REQUEST_ID

## Todo File

$TODO_FILE

## Step

$STEP_ID

## Round

$NEXT

## Scope

$SCOPE

## Strictness

$STRICTNESS

## Review Guidance

${REVIEW_GUIDANCE:-"(none)"}

## Implementer Claim

[Describe what you believe is complete for this step and why.]

## Commit

$HEAD_COMMIT

## Acceptance Criteria Status

- [ ] Criterion 1
- [ ] Criterion 2

## Files Changed

- [path]: [short reason]

## Tests Run

- [command]
- [result]

## Risks / Follow-ups

- [risk]
EOF_REQ

epoch_now > "$DIR/heartbeats/implementer.epoch"

echo "request-id: $REQUEST_ID"
echo "request-file: $REQUEST_FILE"
