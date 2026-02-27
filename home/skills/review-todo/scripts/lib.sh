#!/usr/bin/env bash

iso_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

epoch_now() {
    date -u +%s
}

pad2() {
    printf "%02d" "$1"
}

require_run_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Error: run directory not found: $dir"
        exit 2
    fi
    if [[ ! -f "$dir/meta.env" ]]; then
        echo "Error: meta.env not found in $dir"
        exit 2
    fi
}

load_meta() {
    local dir="$1"
    require_run_dir "$dir"
    # shellcheck disable=SC1090
    source "$dir/meta.env"
}

validate_role() {
    local role="$1"
    case "$role" in
        implementer|reviewer-1|reviewer-2) ;;
        *)
            echo "Error: invalid role: $role"
            exit 2
            ;;
    esac
}

validate_reviewer_role() {
    local role="$1"
    case "$role" in
        reviewer-1|reviewer-2) ;;
        *)
            echo "Error: reviewer role must be reviewer-1 or reviewer-2, got: $role"
            exit 2
            ;;
    esac
}

validate_step_id() {
    local step_id="$1"
    if ! echo "$step_id" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
        echo "Error: invalid step-id '$step_id' (expected lowercase alnum + hyphen)"
        exit 2
    fi
}

extract_round_num() {
    local request_id="$1"
    local round
    round=$(echo "$request_id" | sed -n 's/.*-round-\([0-9][0-9]*\)$/\1/p')
    if [[ -z "$round" ]]; then
        echo ""
        return 1
    fi
    echo "$((10#$round))"
}
