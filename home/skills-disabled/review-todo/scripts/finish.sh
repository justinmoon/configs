#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Usage: finish.sh <run-dir>"
    exit 1
}

[[ $# -lt 1 ]] && usage

DIR="$1"
load_meta "$DIR"

echo "done" > "$DIR/state.md"
echo "run-marked-done: $DIR"
