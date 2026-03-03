#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Usage: register-role.sh <run-dir> <role> <agent-name>"
    echo ""
    echo "Roles: implementer | reviewer-1 | reviewer-2"
    echo "Exit codes: 0=success, 1=taken/already assigned, 2=error"
    exit 1
}

[[ $# -lt 3 ]] && usage

DIR="$1"
ROLE="$2"
AGENT="$3"
REQUESTED_AGENT="$AGENT"

require_run_dir "$DIR"
validate_role "$ROLE"

if ! echo "$REQUESTED_AGENT" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: agent name must be lowercase alnum + hyphen, got: $REQUESTED_AGENT"
    exit 2
fi

for role_file in "$DIR/roles"/*.env; do
    [[ ! -f "$role_file" ]] && continue
    # shellcheck disable=SC1090
    source "$role_file"
    if [[ "${AGENT:-}" == "$REQUESTED_AGENT" ]]; then
        echo "Error: agent already assigned to role ${ROLE_NAME:-unknown}"
        exit 1
    fi
done

ROLE_FILE="$DIR/roles/$ROLE.env"
if [[ -f "$ROLE_FILE" ]]; then
    echo "Role already taken: $ROLE"
    exit 1
fi

(
    set -o noclobber
    {
        printf "ROLE_NAME=%q\n" "$ROLE"
        printf "AGENT=%q\n" "$REQUESTED_AGENT"
        printf "REGISTERED_AT=%q\n" "$(iso_now)"
    } > "$ROLE_FILE"
) 2>/dev/null || {
    echo "Role already taken: $ROLE"
    exit 1
}

echo "Registered role $ROLE -> $REQUESTED_AGENT"
