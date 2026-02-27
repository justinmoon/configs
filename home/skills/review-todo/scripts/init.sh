#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<USAGE
Usage:
  init.sh --dir <run-dir> --todo <todo-file> [options]

Options:
  --strictness <light|balanced|strict|paranoid>     Default: balanced
  --guidance <text>                                 Default: empty
  --implementer-timeout-secs <seconds>              Default: 1200
  --reviewer-idle-timeout-secs <seconds>            Default: 3600
  --max-rounds-per-step <count>                     Default: 7
  --poll-interval-secs <seconds>                    Default: 5

Exit codes:
  0  initialized
  3  already initialized
  1  usage/other error
USAGE
    exit 1
}

DIR=""
TODO_FILE=""
STRICTNESS="balanced"
GUIDANCE=""
IMPLEMENTER_TIMEOUT_SECONDS=1200
REVIEWER_IDLE_TIMEOUT_SECONDS=3600
MAX_ROUNDS_PER_STEP=7
POLL_INTERVAL_SECONDS=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            DIR="$2"
            shift 2
            ;;
        --todo)
            TODO_FILE="$2"
            shift 2
            ;;
        --strictness)
            STRICTNESS="$2"
            shift 2
            ;;
        --guidance)
            GUIDANCE="$2"
            shift 2
            ;;
        --implementer-timeout-secs)
            IMPLEMENTER_TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --reviewer-idle-timeout-secs)
            REVIEWER_IDLE_TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --max-rounds-per-step)
            MAX_ROUNDS_PER_STEP="$2"
            shift 2
            ;;
        --poll-interval-secs)
            POLL_INTERVAL_SECONDS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

[[ -z "$DIR" || -z "$TODO_FILE" ]] && usage

case "$STRICTNESS" in
    light|balanced|strict|paranoid) ;;
    *)
        echo "Error: invalid strictness '$STRICTNESS'"
        exit 1
        ;;
esac

if [[ ! -f "$TODO_FILE" ]]; then
    echo "Error: todo file not found: $TODO_FILE"
    exit 1
fi

TODO_ABS="$(cd "$(dirname "$TODO_FILE")" && pwd)/$(basename "$TODO_FILE")"

if ! mkdir "$DIR" 2>/dev/null; then
    echo "Already initialized: $DIR"
    exit 3
fi

mkdir -p "$DIR"/{roles,heartbeats,requests,reviews,decisions}

printf "TODO_FILE=%q\n" "$TODO_ABS" > "$DIR/meta.env"
printf "STRICTNESS=%q\n" "$STRICTNESS" >> "$DIR/meta.env"
printf "REVIEW_GUIDANCE=%q\n" "$GUIDANCE" >> "$DIR/meta.env"
printf "IMPLEMENTER_TIMEOUT_SECONDS=%q\n" "$IMPLEMENTER_TIMEOUT_SECONDS" >> "$DIR/meta.env"
printf "REVIEWER_IDLE_TIMEOUT_SECONDS=%q\n" "$REVIEWER_IDLE_TIMEOUT_SECONDS" >> "$DIR/meta.env"
printf "MAX_ROUNDS_PER_STEP=%q\n" "$MAX_ROUNDS_PER_STEP" >> "$DIR/meta.env"
printf "POLL_INTERVAL_SECONDS=%q\n" "$POLL_INTERVAL_SECONDS" >> "$DIR/meta.env"
printf "CREATED_AT=%q\n" "$(iso_now)" >> "$DIR/meta.env"

cat > "$DIR/meta.md" <<EOF_META
# Review Todo Metadata

- **todo_file:** $TODO_ABS
- **strictness:** $STRICTNESS
- **review_guidance:** ${GUIDANCE:-"(none)"}
- **implementer_timeout_seconds:** $IMPLEMENTER_TIMEOUT_SECONDS
- **reviewer_idle_timeout_seconds:** $REVIEWER_IDLE_TIMEOUT_SECONDS
- **max_rounds_per_step:** $MAX_ROUNDS_PER_STEP
- **poll_interval_seconds:** $POLL_INTERVAL_SECONDS
- **created:** $(iso_now)
EOF_META

echo "active" > "$DIR/state.md"

epoch_now > "$DIR/heartbeats/implementer.epoch"

cat > "$DIR/roles/README.md" <<'EOF_ROLES'
Claim exactly one role with register-role.sh:
- implementer
- reviewer-1
- reviewer-2
EOF_ROLES

echo "Initialized review run at: $DIR"
echo "Todo file: $TODO_ABS"
echo "Strictness: $STRICTNESS"
